import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../game/log.dart";
import "../game/states.dart";
import "../utils/bug_report/stub.dart";
import "../utils/errors.dart";
import "../utils/extensions.dart";
import "../utils/game_controller.dart";
import "../utils/load_save_file.dart";
import "../utils/log.dart";
import "../utils/navigation.dart";
import "../utils/ui.dart";
import "../utils/versioned/game_log.dart";

final _fileNameDateFormat = DateFormat("yyyy-MM-dd_HH-mm-ss");

extension _DescribeLogItem on BaseGameLogItem {
  List<String> get description {
    final result = <String>[];
    switch (this) {
      case StateChangeGameLogItem(:final newState):
        result.add('Этап игры изменён на "${newState.prettyName}"');
        switch (newState) {
          case GameStatePrepare() ||
                GameStateNightRest() ||
                GameStateWithPlayer() ||
                GameStateWithPlayers() ||
                GameStateNightKill() ||
                GameStateNightCheck() ||
                GameStateWithIterablePlayers() ||
                GameStateFinish():
            // skip
            break;
          case GameStateSpeaking(currentPlayerNumber: final pn, accusations: final accusations):
            if (accusations[pn] != null) {
              result.add("Игрок #$pn выставил на голосование игрока #${accusations[pn]}");
            }
          case GameStateVoting(
            currentPlayerNumber: final pn, 
            currentPlayerVotes: final votes,
            detailedVotes: final detailedVotes
          ):
            if (detailedVotes != null && detailedVotes[pn] != null && detailedVotes[pn]!.isNotEmpty) {
              final voters = detailedVotes[pn]!.toList()..sort();
              result.add("Игрок #$pn получил ${votes ?? 0} голосов: {${voters.join(', ')}}");
            } else {
              result.add("За игрока #$pn отдано голосов: ${votes ?? 0}");
            }
          case GameStateKnockoutVoting(votes: final votes):
            result.add("За подъём всех игроков отдано голосов: $votes");
          case GameStateBestTurn(currentPlayerNumber: final pn, playerNumbers: final pns):
            if (pns.isNotEmpty) {
              result.add(
                'Игрок #$pn сделал "Лучший ход": игрок(и) ${pns.map((n) => "#$n").join(", ")}',
              );
            }
        }
      case PlayerCheckedGameLogItem(
          playerNumber: final playerNumber,
          checkedByRole: final checkedByRole,
        ):
        result.add("${checkedByRole.prettyName} проверил игрока #$playerNumber");
      case PlayerWarnsChangedGameLogItem(:final playerNumber, :final oldWarns, :final currentWarns):
        if (currentWarns > oldWarns) {
          result.add("Игроку #$playerNumber выдан фол: $oldWarns -> $currentWarns");
        } else {
          result.add("У игрока #$playerNumber снят фол: $oldWarns -> $currentWarns");
        }
      case PlayerKickedGameLogItem(
          playerNumber: final playerNumber,
          isOtherTeamWin: final isOtherTeamWin,
        ):
        final kickMessage = "Игрок #$playerNumber исключён из игры";
        if (isOtherTeamWin) {
          result.add("$kickMessage и объявлена ППК");
        } else {
          result.add(kickMessage);
        }
      case PlayerYellowCardsChangedGameLogItem(
          playerNumber: final playerNumber,
          :final oldYellowCards,
          :final currentYellowCards,
        ):
        if (currentYellowCards > oldYellowCards) {
          result.add("Игроку #$playerNumber выдан шанс по жёлтым карточкам: $oldYellowCards -> $currentYellowCards");
        } else {
          result.add("У игрока #$playerNumber снята жёлтая карточка: $oldYellowCards -> $currentYellowCards");
        }
      case PlayerVotedGameLogItem(
          voterNumber: final voterNumber,
          candidateNumber: final candidateNumber,
          isVoteAdded: final isVoteAdded,
        ):
        if (isVoteAdded) {
          result.add("Игрок #$voterNumber проголосовал за игрока #$candidateNumber");
        } else {
          result.add("Игрок #$voterNumber убрал голос с игрока #$candidateNumber");
        }
    }
    return result;
  }
}

class GameLogScreen extends StatelessWidget {
  static final _log = Logger("GameLogScreen");
  final List<BaseGameLogItem>? log;

  const GameLogScreen({
    super.key,
    this.log,
  });

  VersionedGameLog _loadLogFromJson(dynamic data) {
    final VersionedGameLog vgl;
    if (data is Map<String, dynamic> && data.containsKey("packageInfo")) {
      vgl = VersionedGameLog(BugReportInfo.fromJson(data).game.log);
    } else if (data is List<dynamic> || data is Map<String, dynamic>) {
      vgl = VersionedGameLog.fromJson(data);
    } else {
      throw ArgumentError("Unknown data: ${data.runtimeType}");
    }
    return vgl;
  }

  void _onLoadLogFromJsonError(BuildContext context, Object error, StackTrace stackTrace) {
    if (error is UnsupportedVersion) {
      var content = "Версия этого журнала игры не поддерживается.";
      if (error is RemovedVersion) {
        content += " Попробуйте использовать приложение версии <=v${error.lastSupportedAppVersion}";
      }
      showSimpleDialog(
        context: context,
        title: const Text("Ошибка"),
        content: Text(content),
      );
      return;
    } else {
      showSnackBar(context, const SnackBar(content: Text("Ошибка загрузки журнала")));
      _log.error(
        "Error loading game log: e=$error\n$stackTrace",
      );
    }
  }

  Future<void> _onLoadPressed(BuildContext context) async {
    final logFromFile = await loadJsonFile(
      fromJson: _loadLogFromJson,
      onError: (e, st) => _onLoadLogFromJsonError(context, e, st),
    );
    if (logFromFile == null) {
      return; // error already handled
    }
    if (!context.mounted) {
      throw ContextNotMountedError();
    }
    if (logFromFile.version.isDeprecated) {
      await showSimpleDialog(
        context: context,
        title: const Text("Предупреждение"),
        content: const Text(
          "Загрузка журналов игр старого формата устарела и скоро будет невозможна",
        ),
        rememberKey: "noDeprecations${logFromFile.version.name}",
      );
      if (!context.mounted) {
        throw ContextNotMountedError();
      }
    }
    await openGameLogPage(context, logFromFile.value.log.toUnmodifiableList());
  }

  Future<void> _onSavePressed(BuildContext context) async {
    final controller = context.read<GameController>();
    final vgl = VersionedGameLog(
      GameLogWithPlayers(
        log: controller.gameLog,
        players: controller.originalPlayers,
        gameType: controller.gameType,
        gameImportance: controller.gameImportance,
        judgeRatings: controller.judgeRatings,
        winningTeam: controller.winningTeam,
        gameStartTime: controller.gameStartTime,
        gameFinishTime: controller.gameFinishTime,
      ),
    );
    final fileName = "mafia_game_log_${_fileNameDateFormat.format(DateTime.now())}";
    final wasSaved = await saveJsonFile(vgl.toJson(), filename: fileName);
    if (!context.mounted || !wasSaved) {
      return;
    }
    showSnackBar(context, const SnackBar(content: Text("Журнал сохранён")));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GameController>();
    final title = this.log != null ? "Загруженный журнал игры" : "Журнал игры";
    final log = this.log ?? controller.gameLog;
    final logDescriptions = <String>[];
    
    // Group events by state changes
    StateChangeGameLogItem? currentStateChange;
    final eventsForCurrentState = <BaseGameLogItem>[];
    
    for (final item in log) {
      if (item is StateChangeGameLogItem) {
        // First, add events that happened before this state change
        for (final event in eventsForCurrentState) {
          logDescriptions.addAll(event.description);
        }
        eventsForCurrentState.clear();
        
        // Then add the state change description if it's significant
        if (currentStateChange == null || 
            item.newState.hasStateChanged(currentStateChange.newState)) {
          logDescriptions.addAll(item.description);
        }
        currentStateChange = item;
      } else {
        // Collect events for the current state
        eventsForCurrentState.add(item);
      }
    }
    
    // Add any remaining events that happened after the last state change
    for (final event in eventsForCurrentState) {
      logDescriptions.addAll(event.description);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: "Открыть журнал",
            onPressed: () => _onLoadPressed(context),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: "Сохранить журнал",
            onPressed: () => _onSavePressed(context),
          ),
        ],
      ),
      body: log.isNotEmpty
          ? ListView(
              children: <ListTile>[
                for (final desc in logDescriptions)
                  ListTile(
                    title: Text(desc),
                    dense: true,
                  ),
              ],
            )
          : Center(
              child: Text(
                "Ещё ничего не произошло",
                style: TextStyle(color: Theme.of(context).disabledColor),
              ),
            ),
    );
  }
}
