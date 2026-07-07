import 'package:flutter/material.dart';
import 'package:naoxinyuyu_app/core/state/global_app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:naoxinyuyu_app/main.dart';

void main() {
  testWidgets('App starts with authentication gate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GlobalAppState(),
        child: const MyApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AuthGate), findsOneWidget);
  });
}
