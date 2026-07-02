import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/authentication/data/auth_repository.dart';
import 'package:bude_hr/features/authentication/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthController session lifecycle', () {
    const session = HrSession(
      baseUrl: 'https://erp.example.com',
      user: 'employee@example.com',
      fullName: 'Test Employee',
      apiKey: 'key',
      apiSecret: 'secret',
      roles: ['Employee'],
    );

    test('restore loads an existing session and stops restoring', () async {
      final store = _RecordingSessionStore(initialSession: session);
      final controller = AuthController(_NoopAuthRepository(store), store);

      await controller.restore();

      expect(controller.state.isRestoring, isFalse);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.session?.user, session.user);
    });

    test('signOut clears the session and secure storage', () async {
      final store = _RecordingSessionStore(initialSession: session);
      final controller = AuthController(_NoopAuthRepository(store), store);
      await controller.restore();
      expect(controller.state.isAuthenticated, isTrue);

      await controller.signOut();

      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.isRestoring, isFalse);
      expect(store.cleared, isTrue);
    });
  });

  group('AuthController.normalizeBaseUrl', () {
    test('adds https and removes trailing slash', () {
      expect(
        AuthController.normalizeBaseUrl(' erp.example.com/ '),
        'https://erp.example.com',
      );
    });

    test('keeps explicit http scheme', () {
      expect(
        AuthController.normalizeBaseUrl('http://localhost:8000/'),
        'http://localhost:8000',
      );
    });

    test('rejects empty and malformed values', () {
      expect(AuthController.normalizeBaseUrl(''), isNull);
      expect(AuthController.normalizeBaseUrl('not a url'), isNull);
      expect(AuthController.normalizeBaseUrl('ftp://erp.example.com'), isNull);
    });
  });
}

class _NoopAuthRepository extends AuthRepository {
  _NoopAuthRepository(SecureSessionStore store) : super(HrApiClient(store), store);
}

class _RecordingSessionStore extends SecureSessionStore {
  _RecordingSessionStore({this.initialSession});

  final HrSession? initialSession;
  bool cleared = false;

  @override
  Future<HrSession?> read() async => initialSession;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {
    cleared = true;
  }
}
