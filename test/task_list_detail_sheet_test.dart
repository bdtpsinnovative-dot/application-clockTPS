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
          initialListId: 'list-1',
          onRefreshNeeded: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขข้อมูลงาน'), findsOneWidget);
    expect(find.byKey(const Key('task-list-activity-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('task-list-activity-button')));
    await tester.pumpAndSettle();

    expect(find.text('ประวัติกิจกรรมของบอร์ด'), findsOneWidget);
    expect(find.text('ผู้ทดสอบ ระบบ'), findsOneWidget);
    expect(
      find.text('เปลี่ยนสถานะจาก กำลังทำ เป็น รอดำเนินการ'),
      findsOneWidget,
    );
    expect(service.requestedEventListId, 'list-1');
    expect(tester.takeException(), isNull);
  });
}

class _TaskListService extends AuthFlowService {
  _TaskListService() : super(dio: Dio());

  String? requestedEventListId;

  @override
  Future<List<TaskListRecord>> getTrelloBoard(String taskId) async {
    return [
      TaskListRecord(
        id: 'list-1',
        taskId: 'task-1',
        name: 'รายการทดสอบ',
        sortOrder: 0,
        status: 'waiting',
        cards: <TaskCardRecord>[],
      ),
    ];
  }

  @override
  Future<List<UserSummary>> getTaskMembers(String taskId) async => const [];

  @override
  Future<List<TaskEventRecord>> getTaskEvents(
    String taskId, {
    String? listId,
  }) async {
    requestedEventListId = listId;
    return [
      TaskEventRecord(
        id: 'event-1',
        taskId: taskId,
        listId: listId,
        userId: 'user-1',
        eventType: 'system',
        action: 'board_status_changed',
        content: 'เปลี่ยนสถานะจาก กำลังทำ เป็น รอดำเนินการ',
        createdAt: DateTime(2026, 7, 31, 14, 5),
        userFirstName: 'ผู้ทดสอบ',
        userLastName: 'ระบบ',
      ),
    ];
  }
}
