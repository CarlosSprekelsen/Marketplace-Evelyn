import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:marketplace_app/core/storage/token_storage.dart';
import 'package:marketplace_app/features/auth/state/auth_notifier.dart';
import 'package:marketplace_app/main.dart';

void main() {
  testWidgets('App starts and redirects unauthenticated users to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const MarketplaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Iniciar Sesion'), findsOneWidget);
  });
}

class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage() : super(const FlutterSecureStorage());

  final Map<String, String> _data = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _data['access_token'] = accessToken;
    _data['refresh_token'] = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _data['access_token'];

  @override
  Future<String?> getRefreshToken() async => _data['refresh_token'];

  @override
  Future<void> clearTokens() async {
    _data.clear();
  }
}
