import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/read_cache.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/profile/data/profile_repository.dart';
import 'package:bude_hr/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = EmployeeProfile(
  employee: 'EMP-001',
  employeeName: 'Alice Employee',
  company: 'Bude',
  department: 'Operations',
  designation: 'Associate',
  dateOfJoining: '2024-01-15',
  reportsTo: 'EMP-000',
  cellNumber: '+971500000000',
  personalEmail: 'alice@personal.example',
  companyEmail: 'alice@bude.example',
  emergencyPhoneNumber: '+971500000001',
  emergencyContact: 'Bob Contact',
  emergencyRelation: 'Spouse',
);

Future<void> _pump(WidgetTester tester, ProfileRepository repository) async {
  // Tall viewport so every lazily-built ListView section renders.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureSessionStoreProvider.overrideWithValue(_FakeSessionStore()),
        profileRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders job, contact, and emergency sections', (tester) async {
    await _pump(tester, _FakeProfileRepository());

    expect(find.text('Job'), findsOneWidget);
    expect(find.text('Alice Employee'), findsOneWidget);
    // 'Contact' is both a section title and an emergency row label.
    expect(find.text('Contact'), findsWidgets);
    expect(find.text('alice@bude.example'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Bob Contact'), findsOneWidget);
  });

  testWidgets('lists employee documents with privacy labels', (tester) async {
    await _pump(tester, _FakeProfileRepository());

    expect(find.text('contract.pdf'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
  });

  testWidgets('shows empty document state', (tester) async {
    await _pump(tester, _FakeProfileRepository(documentRows: const []));

    expect(find.text('No employee documents found.'), findsOneWidget);
  });

  testWidgets('shows missing profile state', (tester) async {
    await _pump(tester, _FakeProfileRepository(profile: null));

    expect(find.text('No employee profile found.'), findsOneWidget);
  });
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository({
    this.profile = _profile,
    this.documentRows = const [
      EmployeeDocument(
        name: 'FILE-001',
        fileName: 'contract.pdf',
        fileUrl: 'https://erp.example.com/private/files/contract.pdf',
        isPrivate: true,
      ),
    ],
  }) : super(HrApiClient(_FakeSessionStore()), _FakeSessionStore());

  final EmployeeProfile? profile;
  final List<EmployeeDocument> documentRows;

  @override
  Future<Cached<EmployeeProfile?>> get() async =>
      Cached(profile, DateTime.now());

  @override
  Future<List<EmployeeDocument>> documents() async => documentRows;
}
