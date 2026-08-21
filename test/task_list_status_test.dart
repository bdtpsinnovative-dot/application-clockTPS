import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/task_list_status.dart';

void main() {
  test('keeps task-list statuses aligned with the web contract', () {
    const expectedLabels = {
      'waiting': 'รอรับ',
      'pending': 'รอทำ',
      'in_progress': 'กำลังทำ',
      'in_review': 'รอตรวจ',
      'revision': 'แก้ไข',
      'completed': 'เสร็จสิ้น',
    };

    expect(taskListStatusValues, expectedLabels.keys.toList());
    for (final entry in expectedLabels.entries) {
      expect(taskListStatusStyle(entry.key).label, entry.value);
    }
  });
}
