import "package:flutter/cupertino.dart";

import "../../game/log.dart";
import "../../game/player.dart";
import "../errors.dart";
import "../extensions.dart";
import "../json/from_json.dart";
import "../json/to_json.dart";
import "base.dart";

enum GameType {
  training,
  tournament,
  ;

  factory GameType.byName(String name) => GameType.values.byName(name);
}

enum _LegacyGameLogVersion {
  v0(0, "0.3.0-rc.2"),
  ;

  final int value;
  final String lastSupportedAppVersion;

  const _LegacyGameLogVersion(this.value, this.lastSupportedAppVersion);

  factory _LegacyGameLogVersion.byValue(int value) => values.singleWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError(
          "Unknown value, must be one of: ${values.map((e) => e.value).join(", ")}",
        ),
      );
}

enum GameLogVersion implements Comparable<GameLogVersion> {
  v0(0, isDeprecated: true),
  v2(2),
  ;

  static const latest = v2;

  final int value;
  final bool isDeprecated;

  const GameLogVersion(this.value, {this.isDeprecated = false});

  factory GameLogVersion.byValue(int value) => values.singleWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError(
          "Unknown value, must be one of: ${values.map((e) => e.value).join(", ")}",
        ),
      );

  @override
  int compareTo(GameLogVersion other) => value.compareTo(other.value);

  bool operator <(GameLogVersion other) => compareTo(other) < 0;

  bool operator <=(GameLogVersion other) => compareTo(other) <= 0;

  bool operator >(GameLogVersion other) => compareTo(other) > 0;

  bool operator >=(GameLogVersion other) => compareTo(other) >= 0;
}

@immutable
class GameLogWithPlayers {
  const GameLogWithPlayers({
    required this.log,
    required this.players,
    this.gameType,
    this.gameImportance,
    this.judgeRatings,
    this.bestTurnCi,
    this.winningTeam,
    this.gameStartTime,
    this.gameFinishTime,
    this.timeouts,
  });

  static List<Player> _extractLegacyPlayers(dynamic json, GameLogVersion version) =>
      (json as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => playerFromJson(e, version: version))
          .toUnmodifiableList();

  factory GameLogWithPlayers.fromJson(dynamic json, {required GameLogVersion version}) {
    if (json is Map<String, dynamic>) {
      // Новый формат с объектом game
      final gameData = json["game"] as Map<String, dynamic>?;
      
      return GameLogWithPlayers(
        log: (json["log"] as List<dynamic>)
            .parseJsonList((e) => gameLogFromJson(e, version: version)),
        players: (json["players"] as List<dynamic>)
            .parseJsonList((e) => playerFromJson(e, version: version)),
        gameType: gameData?["type"] != null ? GameType.byName(gameData!["type"] as String) : null,
        gameImportance: gameData?["importance"] as double?,
        winningTeam: gameData?["winners"] != null ? RoleTeam.byName(gameData!["winners"] as String) : null,
        gameStartTime: gameData?["start"] != null ? DateTime.parse(gameData!["start"] as String) : null,
        gameFinishTime: gameData?["finish"] != null ? DateTime.parse(gameData!["finish"] as String) : null,
        timeouts: gameData?["timeouts"] != null 
            ? (gameData!["timeouts"] as List<dynamic>)
                .map((t) => (
                  start: DateTime.parse(t["start"] as String),
                  end: DateTime.parse(t["end"] as String),
                ))
                .toList()
            : null,
        judgeRatings: _extractJudgeRatings(json["players"]),
        bestTurnCi: _extractBestTurnCi(json["players"]),
      );
    }
    if (json is List<dynamic> && version < GameLogVersion.v2) {
      return GameLogWithPlayers(
        log: json.parseJsonList((e) => gameLogFromJson(e, version: version)),
        players: _extractLegacyPlayers(json[0]["newState"]["players"], version),
      );
    }
    throw ArgumentError.value(
      json,
      "json",
      "Cannot parse ${json.runtimeType} as GameLogWithPlayers",
    );
  }

  static Map<int, double>? _extractJudgeRatings(dynamic playersJson) {
    if (playersJson == null) return null;
    
    final ratings = <int, double>{};
    for (final playerJson in playersJson as List<dynamic>) {
      final playerMap = playerJson as Map<String, dynamic>;
      if (playerMap.containsKey("judgeRating")) {
        final number = playerMap["number"] as int;
        final rating = (playerMap["judgeRating"] as num).toDouble();
        ratings[number] = rating;
      }
    }
    
    return ratings.isEmpty ? null : ratings;
  }

  static Map<int, double>? _extractBestTurnCi(dynamic playersJson) {
    if (playersJson == null) return null;
    
    final ciValues = <int, double>{};
    for (final playerJson in playersJson as List<dynamic>) {
      final playerMap = playerJson as Map<String, dynamic>;
      if (playerMap.containsKey("bestTurnCi")) {
        final number = playerMap["number"] as int;
        final ci = (playerMap["bestTurnCi"] as num).toDouble();
        ciValues[number] = ci;
      }
    }
    
    return ciValues.isEmpty ? null : ciValues;
  }

  final Iterable<BaseGameLogItem> log;
  final Iterable<Player> players;
  final GameType? gameType;
  final double? gameImportance;
  final Map<int, double>? judgeRatings;
  final Map<int, double>? bestTurnCi;
  final RoleTeam? winningTeam;
  final DateTime? gameStartTime;
  final DateTime? gameFinishTime;
  final List<({DateTime start, DateTime end})>? timeouts;

  Map<String, dynamic> toJson() {
    // Собираем информацию об удалениях из лога
    final kickedPlayers = <int>{};
    final ppkPlayers = <int>{};  // ППК - победа другой команды
    
    for (final logItem in log) {
      if (logItem is PlayerKickedGameLogItem) {
        kickedPlayers.add(logItem.playerNumber);
        if (logItem.isOtherTeamWin) {
          ppkPlayers.add(logItem.playerNumber);
        }
      }
    }
    
    final result = <String, dynamic>{
      "log": log.map((e) => e.toJson()).toList(),
      "players": players.map((player) {
        var rating = judgeRatings?[player.number];
        
        // Устанавливаем дефолтные оценки, если не заданы
        if (rating == null || rating == 0) {
          if (ppkPlayers.contains(player.number)) {
            rating = -2.5;  // ППК - победа другой команды
          } else if (kickedPlayers.contains(player.number)) {
            rating = 1.5;   // Удален, но не ППК
          } else {
            rating = 2.5;   // Обычная оценка
          }
        }
        
        final ci = bestTurnCi?[player.number];
        
        return player.toJson(judgeRating: rating, bestTurnCi: ci);
      }).toList(),
    };
    
    // Добавляем объект game если есть хотя бы одно поле
    if (gameType != null || gameImportance != null || winningTeam != null || 
        gameStartTime != null || gameFinishTime != null || (timeouts != null && timeouts!.isNotEmpty)) {
      result["game"] = {
        if (gameType != null) "type": gameType!.name,
        if (gameImportance != null) "importance": gameImportance,
        if (winningTeam != null) "winners": winningTeam!.name,
        if (gameStartTime != null) "start": gameStartTime!.toIso8601String(),
        if (gameFinishTime != null) "finish": gameFinishTime!.toIso8601String(),
        if (timeouts != null && timeouts!.isNotEmpty) 
          "timeouts": timeouts!.map((t) => {
            "start": t.start.toIso8601String(),
            "end": t.end.toIso8601String(),
          }).toList(),
      };
    }
    
    return result;
  }
}

class VersionedGameLog extends Versioned<GameLogVersion, GameLogWithPlayers> {
  const VersionedGameLog(
    super.value, {
    super.version = GameLogVersion.latest,
  });

  @override
  String get valueKey => "log";

  @override
  dynamic versionToJson(GameLogVersion value) => value.value;

  @override
  dynamic valueToJson(GameLogWithPlayers value) => value.toJson();

  static GameLogVersion _versionFromJson(dynamic value) {
    final versionInt = value as int;
    final GameLogVersion version;
    try {
      version = GameLogVersion.byValue(versionInt);
    } on ArgumentError {
      try {
        final legacyVersion = _LegacyGameLogVersion.byValue(versionInt);
        throw RemovedVersion(
          version: versionInt,
          lastSupportedAppVersion: legacyVersion.lastSupportedAppVersion,
        );
      } on ArgumentError {
        throw UnsupportedVersion(version: versionInt);
      }
    }
    return version;
  }

  factory VersionedGameLog.fromJson(dynamic json) {
    if (json is List<dynamic>) {
      /*const v0 = _LegacyGameLogVersion.v0;
      throw RemovedVersion(
        version: v0.value,
        lastSupportedAppVersion: v0.lastSupportedAppVersion,
      );*/
      return VersionedGameLog(
        GameLogWithPlayers.fromJson(json, version: GameLogVersion.v0),
        version: GameLogVersion.v0,
      );
    }
    if (json is Map<String, dynamic>) {
      return Versioned.fromJsonImpl(
        json,
        valueKey: "log",
        versionFromJson: _versionFromJson,
        valueFromJson: (json, version) => switch (version) {
          GameLogVersion.v0 => throw AssertionError("already handled"),
          GameLogVersion.v2 => GameLogWithPlayers.fromJson(json, version: version),
        },
        create: VersionedGameLog.new,
      );
    }
    throw ArgumentError.value(
      json,
      "json",
      "Cannot parse ${json.runtimeType} as VersionedGameLog",
    );
  }
}
