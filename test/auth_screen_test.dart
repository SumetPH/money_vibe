import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/providers/auth_provider.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:money_vibe/screens/auth/auth_screen.dart';
import 'package:money_vibe/services/database_manager.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() async {
    await AuthProvider().signOut();
  });

  testWidgets('auth screen lets logged out users open Supabase settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: AuthProvider()),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(),
          ),
          ChangeNotifierProvider<DatabaseManager>.value(
            value: DatabaseManager(),
          ),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    final settingsButton = find.text('ตั้งค่า Supabase');
    await tester.ensureVisible(settingsButton);

    expect(settingsButton, findsOneWidget);

    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    expect(find.text('จัดการข้อมูล'), findsOneWidget);
    expect(find.text('ล้างข้อมูลทั้งหมด'), findsNothing);
  });
}
