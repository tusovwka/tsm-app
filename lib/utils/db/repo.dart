import "package:flutter/foundation.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:uuid/data.dart";
import "package:uuid/v7.dart";

import "../extensions.dart";
import "../log.dart";
import "../api/tusovwka_api.dart";
import "models.dart";

typedef WithID<T> = (String id, T item);

class ConflictingPlayersError extends ArgumentError {
  final Iterable<String> conflictingNicknames;

  ConflictingPlayersError(this.conflictingNicknames)
      : super(
          "Some players already exist in the database: ${conflictingNicknames.join(", ")}",
        );
}

class PlayerRepo with ChangeNotifier {
  static final _log = Logger("PlayerRepo");
  static const _uuid7 = UuidV7();

  final _oldBox = Hive.box<Player>("players");
  final _box = Hive.box<Player>("players2");
  final _statsBox = Hive.box<PlayerStats>("playerStats");
  final TusovwkaApiClient _apiClient;

  PlayerRepo({TusovwkaApiClient? apiClient}) 
      : _apiClient = apiClient ?? TusovwkaApiClient() {
    if (_oldBox.isNotEmpty) {
      _log.warning("Old players box is not empty. Migrating data...");
      _migrate();
    }
  }

  Future<void> _migrate() async {
    final allPlayers = _oldBox
        .toMap()
        .values
        .map(
          (p) => PlayerWithStats(
            p, // keep memberId and all fields
            p.stats, // ignore: deprecated_member_use_from_same_package
          ),
        )
        .toUnmodifiableList();
    await addAllWithStats(allPlayers);
    await _oldBox.clear();
  }

  WithID<Player> _converter(MapEntry<dynamic, Player> e) => (e.key, e.value);

  void _checkConflictsByNickname(Iterable<Player> players, {Set<String> excludeIds = const {}}) {
    final nicknames = players.map((p) => p.nickname).toSet();
    final existingNicknames = _box
        .toMap()
        .entries
        .where((e) => !excludeIds.contains(e.key))
        .map((p) => p.value.nickname)
        .toSet();
    final conflictingNicknames = nicknames.intersection(existingNicknames);
    if (conflictingNicknames.isNotEmpty) {
      throw ConflictingPlayersError(conflictingNicknames);
    }
  }

  List<WithID<Player>> get data => _box.toMap().entries.map(_converter).toUnmodifiableList();

  List<WithID<PlayerWithStats>> get dataWithStats => [
        for (final entry in toMapWithStats().entries) (entry.key, entry.value),
      ];

  Map<String, PlayerWithStats> toMapWithStats() => {
        for (final key in _box.keys)
          key as String: PlayerWithStats(
            _box.get(key)!,
            _statsBox.get(key, defaultValue: const PlayerStats.defaults())!,
          ),
      };

  Future<void> add(Player player) => addAll([player]);

  Future<void> addAll(Iterable<Player> players) =>
      addAllWithStats(players.map((p) => PlayerWithStats(p, const PlayerStats.defaults())));

  Future<void> addAllWithStats(Iterable<PlayerWithStats> players) async {
    _checkConflictsByNickname(players.map((p) => p.player));
    final insertData = <String, Player>{};
    final statsInsertData = <String, PlayerStats>{};
    var t = DateTime.timestamp().millisecondsSinceEpoch - players.length;
    for (final player in players) {
      final id = _uuid7.generate(options: V7Options(t++, null));
      insertData[id] = player.player;
      statsInsertData[id] = player.stats;
      _log.info("Saving player: ${player.player.nickname} with memberId: ${player.player.memberId}");
    }
    await _box.putAll(insertData);
    await _statsBox.putAll(statsInsertData);
    notifyListeners();
  }

  Future<PlayerWithStats?> get(String id, {PlayerWithStats? defaultValue}) async {
    final player = _box.get(id);
    if (player == null) {
      return defaultValue;
    }
    final stats = _statsBox.get(id, defaultValue: const PlayerStats.defaults());
    return PlayerWithStats(player, stats!);
  }

  Future<bool> isNicknameOccupied(String nickname, {String? exceptID}) async =>
      _box.toMap().entries.any((p) => p.value.nickname == nickname && p.key != exceptID);

  Future<List<WithID<PlayerWithStats>?>> getManyByNicknames(List<String?> nicknames) async {
    final result = <int, WithID<PlayerWithStats>>{};
    for (final entry in _box.toMap().entries) {
      final index = nicknames.indexOf(entry.value.nickname);
      if (index != -1) {
        final key = entry.key as String;
        final stats = _statsBox.get(key, defaultValue: const PlayerStats.defaults());
        result[index] = (key, PlayerWithStats(entry.value, stats!));
      }
    }
    return [for (var i = 0; i < nicknames.length; i++) result[i]];
  }

  Future<void> edit(String id, Player newPlayer) => editAll({id: newPlayer});

  Future<void> editWithStats(String id, PlayerWithStats newPlayer) =>
      putAllWithStats({id: newPlayer});

  Future<void> editAll(Map<String, Player> editedPlayers) async {
    _checkConflictsByNickname(editedPlayers.values, excludeIds: editedPlayers.keys.toSet());
    for (final entry in editedPlayers.entries) {
      if (await get(entry.key) == null) {
        throw ArgumentError("Player with ID ${entry.key} not found");
      }
    }
    await _box.putAll(editedPlayers);
    notifyListeners();
  }

  Future<void> putAllWithStats(Map<String, PlayerWithStats> editedPlayers) async {
    _checkConflictsByNickname(
      editedPlayers.values.map((p) => p.player),
      excludeIds: editedPlayers.keys.toSet(),
    );
    final playerData = <String, Player>{};
    final statsData = <String, PlayerStats>{};
    for (final entry in editedPlayers.entries) {
      playerData[entry.key] = entry.value.player;
      statsData[entry.key] = entry.value.stats;
    }
    await _box.putAll(playerData);
    await _statsBox.putAll(statsData);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    await _statsBox.delete(id);
    notifyListeners();
  }

  Future<void> clear() async {
    await _box.clear();
    await _statsBox.clear();
    notifyListeners();
  }

  /// Синхронизирует локальных игроков с API
  /// Удаляет игроков без memberId, обновляет существующих и добавляет новых
  /// Возвращает количество обновленных игроков
  Future<int> syncWithApi() async {
    try {
      _log.info("Starting sync with API...");
      final apiPlayers = await _apiClient.getPlayers();
      
      int updatedCount = 0;
      final localPlayers = _box.toMap();
      final localStats = _statsBox.toMap();
      
      // Создаем список API никнеймов для быстрого поиска
      final apiNicknames = apiPlayers.map((p) => p.nickname).toSet();
      
      // Удаляем локальных игроков, которых нет в API или у которых нет memberId
      final playersToDelete = <String>[];
      for (final entry in localPlayers.entries) {
        final localPlayer = entry.value;
        final isInApi = apiNicknames.contains(localPlayer.nickname);
        final hasMemberId = localPlayer.memberId != null;
        
        if (!isInApi || !hasMemberId) {
          playersToDelete.add(entry.key as String);
          _log.info("Marking player for deletion: ${localPlayer.nickname} (inApi: $isInApi, hasMemberId: $hasMemberId)");
        }
      }
      
      // Удаляем помеченных игроков
      for (final playerId in playersToDelete) {
        await _box.delete(playerId);
        await _statsBox.delete(playerId);
        updatedCount++;
      }
      
      // Обновляем member_id для существующих игроков
      for (final entry in localPlayers.entries) {
        if (playersToDelete.contains(entry.key)) continue; // Пропускаем удаленных
        
        final localPlayer = entry.value;
        final apiPlayer = apiPlayers.firstWhere(
          (p) => p.nickname == localPlayer.nickname,
          orElse: () => throw StateError("Player ${localPlayer.nickname} not found in API"),
        );
        
        if (localPlayer.memberId != apiPlayer.memberId) {
          final updatedPlayer = localPlayer.copyWith(memberId: apiPlayer.memberId);
          await _box.put(entry.key, updatedPlayer);
          updatedCount++;
          _log.info("Updated member_id for player ${localPlayer.nickname}: ${apiPlayer.memberId}");
        }
      }
      
      // Добавляем новых игроков из API
      for (final apiPlayer in apiPlayers) {
        final exists = localPlayers.values.any((p) => p.nickname == apiPlayer.nickname);
        if (!exists) {
          final newPlayer = Player(
            nickname: apiPlayer.nickname,
            realName: "", // API не предоставляет реальное имя
            memberId: apiPlayer.memberId,
          );
          await add(newPlayer);
          updatedCount++;
          _log.info("Added new player from API: ${apiPlayer.nickname} (${apiPlayer.memberId})");
        }
      }
      
      if (updatedCount > 0) {
        notifyListeners();
      }
      
      _log.info("Sync completed. Updated $updatedCount players.");
      return updatedCount;
    } catch (e) {
      _log.error("Failed to sync with API: $e");
      rethrow;
    }
  }

  /// Загружает игроков только из API (заменяет локальных)
  /// Загружает только игроков с memberId
  Future<void> loadFromApi() async {
    try {
      _log.info("Loading players from API...");
      final apiPlayers = await _apiClient.getPlayers();
      
      await clear();
      
      // Фильтруем только игроков с memberId
      final playersWithMemberId = apiPlayers.where((p) => p.memberId != null).toList();
      
      final playersWithStats = playersWithMemberId.map((apiPlayer) => PlayerWithStats(
        Player(
          nickname: apiPlayer.nickname,
          realName: "", // API не предоставляет реальное имя
          memberId: apiPlayer.memberId,
        ),
        const PlayerStats.defaults(),
      ));
      
      await addAllWithStats(playersWithStats);
      _log.info("Loaded ${playersWithMemberId.length} players from API (filtered by memberId)");
    } catch (e) {
      _log.error("Failed to load players from API: $e");
      rethrow;
    }
  }

  /// Проверяет доступность API
  Future<bool> isApiAvailable() async {
    return await _apiClient.isApiAvailable();
  }

  void dispose() {
    _apiClient.dispose();
  }
}
