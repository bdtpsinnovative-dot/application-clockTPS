import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/screens/task_board_page.dart';
import 'package:hr_management/services/auth_flow_service.dart';

void main() {
  testWidgets('task list editor opens without infinite width constraints', (
    tester,
  ) async {
    final service = _TaskListService();
    final now = DateTime(2026, 8, 4);
    final task = TaskRecord(
      id: 'task-1',
      assignedTo: 'user-1',
      title: 'บอร์ดทดสอบ',
      description: '',
      dueDate: now,
      status: 'in_progress',
      createdAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        home: TaskBoardPage(
          task: task,
          service: service,
          onRefreshNeeded: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('รายการทดสอบ'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขข้อมูลงาน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TaskListService extends AuthFlowService {
  _TaskListService() : super(dio: Dio());

  @override
  Future<List<TaskListRecord>> getTrelloBoard(String taskId) async {
    return [
      TaskListRecord(
        id: 'list-1',
        taskId: 'task-1',
        name: 'รายการทดสอบ',
        sortOrder: 0,
        cards: <TaskCardRecord>[],
      ),
    ];
  }

  @override
  Future<List<UserSummary>> getTaskMembers(String taskId) async => const [];
}
