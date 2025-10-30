import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "../lib/utils/api/tusovwka_api.dart";

@GenerateMocks([http.Client])
void main() {
  group("TusovwkaApiClient", () {
    late TusovwkaApiClient apiClient;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      apiClient = TusovwkaApiClient(client: mockClient);
    });

    tearDown(() {
      apiClient.dispose();
    });

    test("should parse API response correctly with pagination", () async {
      // Arrange
      final page1 = '''
      {"players": [
        {"member_id": 1, "nickname": "Player1"},
        {"member_id": 2, "nickname": "Player2"}
      ], "max_page": 2}
      ''';
      final page2 = '''
      {"players": [
        {"member_id": 3, "nickname": "Player3"}
      ], "max_page": 2}
      ''';
      
      when(mockClient.get(any, headers: anyNamed("headers")))
          .thenAnswer((invocation) async {
        final uri = invocation.positionalArguments.first as Uri;
        final page = int.parse(uri.queryParameters['page'] ?? '1');
        if (page == 1) {
          return http.Response(page1, 200);
        }
        return http.Response(page2, 200);
      });

      // Act
      final players = await apiClient.getPlayers();

      // Assert
      expect(players.length, equals(3));
      expect(players[0].memberId, equals(1));
      expect(players[0].nickname, equals("Player1"));
      expect(players[1].memberId, equals(2));
      expect(players[1].nickname, equals("Player2"));
      expect(players[2].memberId, equals(3));
      expect(players[2].nickname, equals("Player3"));
    });

    test("should handle API errors on first page", () async {
      // Arrange
      when(mockClient.get(any, headers: anyNamed("headers")))
          .thenAnswer((_) async => http.Response("Not Found", 404));

      // Act & Assert
      expect(
        () => apiClient.getPlayers(),
        throwsA(isA<TusovwkaApiException>()),
      );
    });

    test("should handle network errors", () async {
      // Arrange
      when(mockClient.get(any, headers: anyNamed("headers")))
          .thenThrow(http.ClientException("Network error"));

      // Act & Assert
      expect(
        () => apiClient.getPlayers(),
        throwsA(isA<TusovwkaApiException>()),
      );
    });

    test("should check API availability", () async {
      // Arrange
      when(mockClient.head(any))
          .thenAnswer((_) async => http.Response("", 200));

      // Act
      final isAvailable = await apiClient.isApiAvailable();

      // Assert
      expect(isAvailable, isTrue);
    });
  });
}
