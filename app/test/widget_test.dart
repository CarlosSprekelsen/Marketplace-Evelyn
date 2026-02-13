import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:marketplace_app/main.dart';

void main() {
  testWidgets('App loads with login placeholder', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MarketplaceApp(),
      ),
    );

    // Verify that the login placeholder screen is displayed.
    expect(find.text('Marketplace de Limpieza'), findsOneWidget);
    expect(find.text('Login Screen Placeholder'), findsOneWidget);
    expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
  });
}
