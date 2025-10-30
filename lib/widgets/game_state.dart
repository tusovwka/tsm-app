import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../game/player.dart";
import "../game/states.dart";
import "../utils/api/tusovwka_api.dart";
import "../utils/db/repo.dart";
import "../utils/errors.dart";
import "../utils/game_controller.dart";
import "../utils/load_save_file.dart";
import "../utils/navigation.dart";
import "../utils/ui.dart";
import "../utils/versioned/game_log.dart";
import "confirmation_dialog.dart";
import "counter.dart";
import "player_timer.dart";
import "restart_dialog.dart";

final _fileNameDateFormat = DateFormat("yyyy-MM-dd_HH-mm-ss");

class GameStateInfo extends StatelessWidget {
  const GameStateInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          controller.isGameInitialized ? controller.state.prettyName : "Игра не начата",
          style: const TextStyle(fontSize: 32),
          textAlign: TextAlign.center,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: BottomGameStateWidget(),
        ),
      ],
    );
  }
}

class BottomGameStateWidget extends StatelessWidget {
  const BottomGameStateWidget({super.key});

  Future<void> _onStartGamePressed(BuildContext context, GameController controller) async {
    final randomizeSeats = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmationDialog(
        title: Text("Провести случайную рассадку?"),
        content: Text("Перед началом игры можно провести случайную рассадку"),
        rememberKey: "randomizeSeats",
      ),
    );
    if (randomizeSeats == null) {
      return;
    }
    if (randomizeSeats) {
      if (!context.mounted) {
        throw ContextNotMountedError();
      }
      await openSeatRandomizerPage(context);
    }
    if (!context.mounted) {
      throw ContextNotMountedError();
    }
    await openRoleChooserPage(context);
  }

  Future<void> _onPublishGamePressed(BuildContext context, GameController controller) async {
    final vgl = VersionedGameLog(
      GameLogWithPlayers(
        log: controller.gameLog,
        players: controller.originalPlayers,
        gameType: controller.gameType,
        gameImportance: controller.gameImportance,
        judgeRatings: controller.judgeRatings,
        bestTurnCi: controller.bestTurnCi,
        winningTeam: controller.winningTeam,
        gameStartTime: controller.gameStartTime,
        gameFinishTime: controller.gameFinishTime,
        timeouts: controller.timeouts.isNotEmpty ? controller.timeouts : null,
      ),
    );
    
    try {
      final apiClient = TusovwkaApiClient();
      
      // Cookie с session_id отправляются автоматически через BrowserClient
      await apiClient.addGame(vgl.toJson());
      
      if (!context.mounted) {
        return;
      }
      showSnackBar(context, const SnackBar(content: Text("Игра успешно опубликована!")));
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      showSnackBar(
        context,
        SnackBar(content: Text("Ошибка при публикации игры: $e")),
      );
    }
  }

  Future<void> _onDownloadGamePressed(BuildContext context, GameController controller) async {
    final vgl = VersionedGameLog(
      GameLogWithPlayers(
        log: controller.gameLog,
        players: controller.originalPlayers,
        gameType: controller.gameType,
        gameImportance: controller.gameImportance,
        judgeRatings: controller.judgeRatings,
        bestTurnCi: controller.bestTurnCi,
        winningTeam: controller.winningTeam,
        gameStartTime: controller.gameStartTime,
        gameFinishTime: controller.gameFinishTime,
        timeouts: controller.timeouts.isNotEmpty ? controller.timeouts : null,
      ),
    );
    final fileName = "mafia_game_log_${_fileNameDateFormat.format(DateTime.now())}";
    final wasSaved = await saveJsonFile(vgl.toJson(), filename: fileName);
    if (!context.mounted || !wasSaved) {
      return;
    }
    showSnackBar(context, const SnackBar(content: Text("Игра скачана")));
  }

  Future<void> _onJudgeRatingPressed(BuildContext context, GameController controller) async {
    final ratings = await openJudgeRatingPage(context, initialRatings: controller.judgeRatings);
    if (ratings != null) {
      controller.judgeRatings = ratings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    if (!controller.isGameInitialized) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _onStartGamePressed(context, controller),
            child: const Text("Начать игру", style: TextStyle(fontSize: 20)),
          ),
        ],
      );
    }

    final gameState = controller.state;
    if (gameState is GameStatePrepare) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => openRoleChooserPage(context),
            child: const Text("Редактирование игроков", style: TextStyle(fontSize: 20)),
          ),
        ],
      );
    }

    if (gameState
        case GameStateWithPlayers(
          stage: GameStage.preVoting || GameStage.preExcuse || GameStage.preFinalVoting,
          playerNumbers: final selectedPlayers
        )) {
      return Text(
        "${gameState.stage == GameStage.preExcuse ? "Игроки" : "Выставлены"}:"
        " ${selectedPlayers.join(", ")}",
        style: const TextStyle(fontSize: 20),
      );
    }

    if (gameState is GameStateVoting) {
      assert(gameState.votes.keys.length > 1, "One or less vote candidates (bug?)");
      final aliveCount = controller.players.aliveCount;
      final currentPlayerVotes = gameState.currentPlayerVotes ?? 0;
      final isLastCandidate = gameState.votes.keys.last == gameState.currentPlayerNumber;
      final int minVotes;
      final int maxVotes;
      
      if (isLastCandidate) {
        // Для последнего кандидата голоса фиксированы (остаток)
        minVotes = currentPlayerVotes;
        maxVotes = currentPlayerVotes;
      } else {
        minVotes = 0;
        maxVotes = aliveCount - (controller.totalVotes - currentPlayerVotes);
      }
      
      // Проверяем режим голосования
      final isNamedVoting = gameState.isNamedVoting ?? false;
      
      return Counter(
        key: ValueKey('${gameState.currentPlayerNumber}_${currentPlayerVotes}_$isNamedVoting'),
        min: minVotes,
        max: maxVotes,
        // Отключаем Counter если: именное голосование ИЛИ последний кандидат
        onValueChanged: (isNamedVoting || isLastCandidate) ? null : controller.vote,
        initialValue: currentPlayerVotes,
      );
    }

    if (gameState is GameStateKnockoutVoting) {
      final hasDetailedVotes = gameState.detailedVotes != null;
      return Counter(
        key: ValueKey("dropTableVoting_${gameState.votes}_$hasDetailedVotes"),
        min: 0,
        max: controller.players.aliveCount,
        // Отключаем Counter если активен именной режим
        onValueChanged: hasDetailedVotes ? null : controller.vote,
        initialValue: gameState.votes,
      );
    }

    if (gameState case GameStateFinish(winner: final winner)) {
      final resultText = switch (winner) {
        RoleTeam.citizen => "Победа команды мирных жителей",
        RoleTeam.mafia => "Победа команды мафии",
        null => "Ничья",
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(resultText, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _onJudgeRatingPressed(context, controller),
                icon: const Icon(Icons.star),
                label: const Text("Оценка судей"),
              ),
              TextButton.icon(
                onPressed: () => _onPublishGamePressed(context, controller),
                icon: const Icon(Icons.cloud_upload),
                label: const Text("Опубликовать"),
              ),
              TextButton.icon(
                onPressed: () => _onDownloadGamePressed(context, controller),
                icon: const Icon(Icons.download),
                label: const Text("Скачать"),
              ),
            ],
          ),
          TextButton(
            onPressed: () async {
              final restartGame = await showDialog<bool>(
                context: context,
                builder: (context) => const RestartGameDialog(),
              );
              if (restartGame ?? false) {
                controller.stopGame();
                if (!context.mounted) {
                  throw ContextNotMountedError();
                }
                showSnackBar(context, const SnackBar(content: Text("Игра перезапущена")));
              }
            },
            child: const Text("Начать заново", style: TextStyle(fontSize: 20)),
          ),
        ],
      );
    }

    return const PlayerTimer();
  }
}
