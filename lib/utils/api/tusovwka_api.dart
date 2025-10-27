import "dart:convert";
import "package:http/http.dart" as http;
import "package:meta/meta.dart";

import "../log.dart";

class TusovwkaApiException implements Exception {
  final String message;
  final int? statusCode;

  TusovwkaApiException(this.message, [this.statusCode]);

  @override
  String toString() => "TusovwkaApiException: $message${statusCode != null ? " (HTTP $statusCode)" : ""}";
}

class TusovwkaPlayer {
  final int memberId;
  final String nickname;

  const TusovwkaPlayer({
    required this.memberId,
    required this.nickname,
  });

  factory TusovwkaPlayer.fromJson(Map<String, dynamic> json) {
    return TusovwkaPlayer(
      memberId: json["member_id"] as int,
      nickname: json["nickname"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "member_id": memberId,
      "nickname": nickname,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TusovwkaPlayer &&
          runtimeType == other.runtimeType &&
          memberId == other.memberId &&
          nickname == other.nickname;

  @override
  int get hashCode => Object.hash(memberId, nickname);
}

class TusovwkaApiClient {
  static final _log = Logger("TusovwkaApiClient");
  static const String _baseUrl = "https://api.tusovwka.ru/mafia";
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;

  TusovwkaApiClient({http.Client? client}) : _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  /// Получает список игроков с сервера
  Future<List<TusovwkaPlayer>> getPlayers() async {
    try {
      _log.info("Fetching players from API...");
      
      final response = await _client
          .get(
            Uri.parse("$_baseUrl/players"),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        final players = jsonList
            .map((json) => TusovwkaPlayer.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _log.info("Successfully fetched ${players.length} players from API");
        return players;
      } else {
        throw TusovwkaApiException(
          "Failed to fetch players: ${response.reasonPhrase}",
          response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      _log.error("Network error while fetching players: $e");
      throw TusovwkaApiException("Network error: ${e.message}");
    } on FormatException catch (e) {
      _log.error("JSON parsing error: $e");
      throw TusovwkaApiException("Invalid JSON response: ${e.message}");
    } catch (e) {
      _log.error("Unexpected error while fetching players: $e");
      throw TusovwkaApiException("Unexpected error: $e");
    }
  }

  /// Проверяет доступность API
  Future<bool> isApiAvailable() async {
    try {
      final response = await _client
          .head(Uri.parse("$_baseUrl/players"))
          .timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      _log.warning("API availability check failed: $e");
      return false;
    }
  }

  /// Публикует игру на сервер
  Future<void> addGame(Map<String, dynamic> gameData, {String? cookie}) async {
    try {
      _log.info("Publishing game to API...");
      
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
      };
      
      if (cookie != null && cookie.isNotEmpty) {
        headers["Cookie"] = cookie;
      }
      
      final response = await _client
          .post(
            Uri.parse("$_baseUrl/addGame"),
            headers: headers,
            body: json.encode(gameData),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        _log.info("Successfully published game to API");
      } else {
        throw TusovwkaApiException(
          "Failed to publish game: ${response.reasonPhrase}",
          response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      _log.error("Network error while publishing game: $e");
      throw TusovwkaApiException("Network error: ${e.message}");
    } catch (e) {
      _log.error("Unexpected error while publishing game: $e");
      throw TusovwkaApiException("Unexpected error: $e");
    }
  }
}
