import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/services/fcm_service.dart';

void main() {
  test('FCM target maps task and task-list navigation metadata', () {
    final target = FcmNotificationTarget.fromData(const {
      'task_id': 'task-1',
      'list_id': 'list-1',
      'type': 'task_list_status',
    });

    expect(target.taskId, 'task-1');
    expect(target.listId, 'list-1');
    expect(target.type, 'task_list_status');
  });

  test('FCM target also accepts camel-case metadata', () {
    final target = FcmNotificationTarget.fromData(const {
      'taskId': 'task-2',
      'listId': 'list-2',
      'notificationType': 'task_assignment',
    });

    expect(target.taskId, 'task-2');
    expect(target.listId, 'list-2');
    expect(target.type, 'task_assignment');
  });
}
