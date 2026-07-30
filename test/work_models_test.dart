import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/work_models.dart';

void main() {
  test('TaskRecord keeps the board creator name returned by the API', () {
    final task = TaskRecord.fromJson({
      'id': 'task-1',
      'assigned_to': 'assignee-id',
      'assigned_to_name': 'Khanin',
      'assigned_by': 'creator-id',
      'assigned_by_name': 'Current User',
      'title': 'Board',
      'description': '',
      'due_date': '2026-07-31T00:00:00Z',
      'status': 'pending',
      'created_at': '2026-07-24T00:00:00Z',
    });

    expect(task.assignedBy, 'creator-id');
    expect(task.assignedByName, 'Current User');
  });

  test('TaskListRecord maps deliverable fields and keeps legacy cards', () {
    final deliverable = TaskListRecord.fromJson({
      'id': 'list-1',
      'task_id': 'project-1',
      'name': 'ส่งแบบหน้าโปรไฟล์',
      'description': 'แนบลิงก์ Figma',
      'sort_order': 0,
      'priority': 'high',
      'status': 'in_review',
      'admin_comment': 'แก้ spacing อีกเล็กน้อย',
      'assignee_ids': ['user-1'],
      'attachments': [
        {'name': 'Figma', 'url': 'https://example.com', 'type': 'link'},
      ],
      'cards': [
        {
          'id': 'legacy-card',
          'list_id': 'list-1',
          'title': 'ข้อมูลเดิม',
          'description': '',
          'status': 'pending',
          'sort_order': 0,
        },
      ],
    });

    expect(deliverable.status, 'in_review');
    expect(deliverable.priority, 'high');
    expect(deliverable.assigneeIds, ['user-1']);
    expect(deliverable.attachments.single.type, 'link');
    expect(deliverable.cards.single.title, 'ข้อมูลเดิม');
  });

  test('TaskEventRecord maps a deliverable comment and its author', () {
    final comment = TaskEventRecord.fromJson({
      'id': 'event-1',
      'task_id': 'project-1',
      'list_id': 'list-1',
      'user_id': 'user-1',
      'event_type': 'comment',
      'action': 'comment_added',
      'content': 'ส่งแบบรอบแรกแล้วครับ',
      'created_at': '2026-07-30T04:00:00Z',
      'user_first_name': 'สมชาย',
      'user_last_name': 'ใจดี',
      'user_avatar_url': 'https://example.com/avatar.jpg',
    });

    expect(comment.listId, 'list-1');
    expect(comment.eventType, 'comment');
    expect(comment.content, 'ส่งแบบรอบแรกแล้วครับ');
    expect(comment.userFullName, 'สมชาย ใจดี');
    expect(comment.userAvatarUrl, 'https://example.com/avatar.jpg');
  });

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
      final json = {'date': '2026-07-07T00:00:00Z'};

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
