import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/screens/task_board/task_list_sorting.dart';

TaskListRecord _taskList({
  required String id,
  required String status,
  DateTime? dueDate,
  int sortOrder = 0,
}) {
  return TaskListRecord(
    id: id,
    taskId: 'task-1',
    name: id,
    status: status,
    dueDate: dueDate,
    sortOrder: sortOrder,
  );
}

void main() {
  test(
    'unfinished task lists sort by oldest deadline before completed lists',
    () {
      final lists = [
        _taskList(
          id: 'completed-old',
          status: 'completed',
          dueDate: DateTime(2026, 7, 1),
        ),
        _taskList(
          id: 'upcoming-near',
          status: 'in_progress',
          dueDate: DateTime(2026, 8, 5),
        ),
        _taskList(
          id: 'overdue-longest',
          status: 'pending',
          dueDate: DateTime(2026, 7, 20),
        ),
        _taskList(
          id: 'upcoming-later',
          status: 'in_progress',
          dueDate: DateTime(2026, 8, 10),
        ),
        _taskList(id: 'no-deadline', status: 'pending'),
      ];

      expect(sortTaskListsForBoard(lists).map((list) => list.id), [
        'overdue-longest',
        'upcoming-near',
        'upcoming-later',
        'no-deadline',
        'completed-old',
      ]);
    },
  );

  test('task lists with the same deadline retain their manual sort order', () {
    final dueDate = DateTime(2026, 8, 5);
    final lists = [
      _taskList(
        id: 'second',
        status: 'pending',
        dueDate: dueDate,
        sortOrder: 2,
      ),
      _taskList(id: 'first', status: 'pending', dueDate: dueDate, sortOrder: 1),
    ];

    expect(sortTaskListsForBoard(lists).map((list) => list.id), [
      'first',
      'second',
    ]);
  });
}
