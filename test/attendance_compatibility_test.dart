import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';

void main() {
  test('legacy user response keeps default work schedule', () {
    final user = AppUser.fromJson(const {
      'id': 'user-1',
      'auth_id': 'auth-1',
      'email': 'employee@example.com',
      'first_name': 'Test',
      'last_name': 'User',
      'department': 'BD',
      'position': 'Staff',
      'role': 'employee',
      'status': 'active',
    });

    expect(user.workStartTime, '09:00');
    expect(user.workEndTime, '18:00');
  });

  test('legacy attendance response remains parseable', () {
    final record = AttendanceRecord.fromJson(const {
      'date': '2026-08-20',
      'status': 'on_time',
      'user_id': 'user-1',
      'check_in_at': '2026-08-20T09:00:00+07:00',
    });

    expect(record.workStartTime, '09:00');
    expect(record.workEndTime, '18:00');
    expect(record.locationName, isEmpty);
    expect(record.isOffsite, isFalse);
    expect(record.lateMinutes, 0);
  });

  test(
    'expanded attendance response reads snapshots without changing legacy fields',
    () {
      final record = AttendanceRecord.fromJson(const {
        'id': 'attendance-1',
        'date': '2026-08-20',
        'status': 'late',
        'user_id': 'user-1',
        'check_in_at': '2026-08-20T08:07:00+07:00',
        'work_start_time': '08:00',
        'work_end_time': '17:00',
        'late_minutes': 7,
        'is_workday': true,
        'is_offsite': true,
        'location_name': 'ออกหน้างาน',
        'check_out_location_name': 'ไซต์ลูกค้า',
      });

      expect(record.status, 'late');
      expect(record.workStartTime, '08:00');
      expect(record.workEndTime, '17:00');
      expect(record.lateMinutes, 7);
      expect(record.isOffsite, isTrue);
      expect(record.locationName, 'ออกหน้างาน');
    },
  );
}
