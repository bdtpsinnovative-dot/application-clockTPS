import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/work_models.dart';

void main() {
  group('AttendanceRecord Tests', () {
    test('should parse AttendanceRecord from JSON with complete fields', () {
      final json = {
        'date': '2026-07-07T00:00:00Z',
        'status': 'on_time',
        'check_in_at': '2026-07-07T09:00:00Z',
        'check_out_at': '2026-07-07T18:00:00Z',
      };

      final record = AttendanceRecord.fromJson(json);

      expect(record.date, equals(DateTime.parse('2026-07-07T00:00:00Z')));
      expect(record.status, equals('on_time'));
      expect(record.checkInAt, isNotNull);
      expect(record.checkOutAt, isNotNull);
    });

    test('should parse AttendanceRecord from JSON with minimal fields', () {
      final json = {
        'date': '2026-07-07T00:00:00Z',
      };

      final record = AttendanceRecord.fromJson(json);

      expect(record.date, equals(DateTime.parse('2026-07-07T00:00:00Z')));
      expect(record.status, equals('no_record'));
      expect(record.checkInAt, isNull);
      expect(record.checkOutAt, isNull);
    });
  });

  group('WorkRequestRecord Tests', () {
    test('should create leave WorkRequestRecord from JSON', () {
      final json = {
        'id': 'req-1',
        'leave_type': 'ลาป่วย',
        'date': '2026-07-10T00:00:00Z',
        'reason': 'เป็นไข้หวัดใหญ่',
        'status': 'pending',
        'duration': '1 วัน',
      };

      final record = WorkRequestRecord.leave(json);

      expect(record.id, equals('req-1'));
      expect(record.type, equals('ลาป่วย'));
      expect(record.date, equals(DateTime.parse('2026-07-10T00:00:00Z')));
      expect(record.reason, equals('เป็นไข้หวัดใหญ่'));
      expect(record.status, equals('pending'));
      expect(record.duration, equals('1 วัน'));
      expect(record.isOffsite, isFalse);
    });

    test('should create offsite WorkRequestRecord from JSON', () {
      final json = {
        'id': 'req-2',
        'date': '2026-07-11T00:00:00Z',
        'reason': 'พบลูกค้าที่บริษัท ABC',
        'status': 'approved',
      };

      final record = WorkRequestRecord.offsite(json);

      expect(record.id, equals('req-2'));
      expect(record.type, equals('ออกหน้างาน'));
      expect(record.date, equals(DateTime.parse('2026-07-11T00:00:00Z')));
      expect(record.reason, equals('พบลูกค้าที่บริษัท ABC'));
      expect(record.status, equals('approved'));
      expect(record.isOffsite, isTrue);
      expect(record.duration, isNull);
    });
  });

  group('HolidayRecord Tests', () {
    test('should parse HolidayRecord from JSON', () {
      final json = {
        'id': 'h-1',
        'date': '2026-12-05T00:00:00Z',
        'name': 'วันคล้ายวันพระบรมราชสมภพ',
        'num_days': 1,
      };

      final record = HolidayRecord.fromJson(json);

      expect(record.id, equals('h-1'));
      expect(record.date, equals(DateTime.parse('2026-12-05T00:00:00Z')));
      expect(record.name, equals('วันคล้ายวันพระบรมราชสมภพ'));
      expect(record.numDays, equals(1));
    });
  });

  group('LeaveBalanceRecord Tests', () {
    test('should parse LeaveBalanceRecord from JSON', () {
      final json = {
        'leave_type': 'ลาพักร้อน',
        'quota': 6.0,
        'used': 2.5,
        'remaining': 3.5,
      };

      final record = LeaveBalanceRecord.fromJson(json);

      expect(record.leaveType, equals('ลาพักร้อน'));
      expect(record.quota, equals(6.0));
      expect(record.used, equals(2.5));
      expect(record.remaining, equals(3.5));
    });
  });
}
