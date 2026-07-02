import 'package:bude_hr/features/settings/presentation/settings_screen.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings screen shows ERP and language sections', (tester) async {
    // Settings shows a pending-sync count, which reads the offline queue.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(_FakeSessionStore()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('ERPNext URL'), findsOneWidget);
    expect(find.text('Languages'), findsOneWidget);
  });
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async {
    return const HrSession(
      baseUrl: 'https://erp.example.com',
      user: 'employee@example.com',
      fullName: 'Employee Example',
      apiKey: 'key',
      apiSecret: 'secret',
      roles: ['Employee'],
    );
  }

  @override
  Future<void> clear() async {}
}
