/// Verifies one refresh followed by one retry using MockClient.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/token_store.dart';

class FakeTokenStore implements TokenStore {
  FakeTokenStore({
    this.savedAccessToken,
    this.savedRefreshToken,
  });

  String? savedAccessToken;
  String? savedRefreshToken;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String?> readAccessToken() async => savedAccessToken;

  @override
  Future<String?> readRefreshToken() async => savedRefreshToken;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    savedAccessToken = accessToken;
    savedRefreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    savedAccessToken = null;
    savedRefreshToken = null;
  }
}

void main() {
  test('refreshes once on 401 and retries the original request once', () async {
    var originalCalls = 0;
    var refreshCalls = 0;

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        return http.Response(
          jsonEncode({
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          }),
          200,
        );
      }

      originalCalls++;
      if (originalCalls == 1) return http.Response('{}', 401);

      expect(request.headers['authorization'], 'Bearer new-access');
      return http.Response(jsonEncode({'items': []}), 200);
    });

    final tokens = FakeTokenStore(
      savedAccessToken: 'old-access',
      savedRefreshToken: 'old-refresh',
    );

    final client = ApiClient(mock, tokens);

    await client.send('GET', 'tasks');

    expect(refreshCalls, 1);
    expect(originalCalls, 2);
    expect(tokens.savedAccessToken, 'new-access');
    expect(tokens.savedRefreshToken, 'new-refresh');
  });
}
