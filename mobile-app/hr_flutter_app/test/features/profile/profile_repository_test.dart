import 'package:bude_hr/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses employee profile detail fields', () {
    final profile = EmployeeProfile.fromJson({
      'name': 'EMP-001',
      'employee_name': 'Alice Employee',
      'company': 'Bude',
      'department': 'Operations',
      'designation': 'Associate',
      'date_of_joining': '2026-01-01',
      'reports_to': 'EMP-MGR',
      'cell_number': '+971500000000',
      'personal_email': 'alice@example.com',
      'company_email': 'alice@bude.example',
      'emergency_phone_number': '+971511111111',
      'person_to_be_contacted': 'Emergency Contact',
      'relation': 'Spouse',
    });

    expect(profile.employee, 'EMP-001');
    expect(profile.dateOfJoining, '2026-01-01');
    expect(profile.companyEmail, 'alice@bude.example');
    expect(profile.emergencyRelation, 'Spouse');
  });

  test('parses employee document and makes relative file URLs absolute', () {
    final document = EmployeeDocument.fromJson(
      {
        'name': 'FILE-001',
        'file_name': 'contract.pdf',
        'file_url': '/private/files/contract.pdf',
        'is_private': 1,
      },
      baseUrl: 'https://erp.example.com/',
    );

    expect(document.name, 'FILE-001');
    expect(document.fileName, 'contract.pdf');
    expect(document.fileUrl, 'https://erp.example.com/private/files/contract.pdf');
    expect(document.isPrivate, isTrue);
  });
}
