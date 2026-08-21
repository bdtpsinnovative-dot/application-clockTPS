import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/screens/project_detail/project_deliverable_card.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('deliverable card opens detail without exposing legacy cards', (
    tester,
  ) async {
    await initializeDateFormatting('th');
    var openedDetail = false;
    final deliverable = TaskListRecord(
      id: 'deliverable-1',
      taskId: 'project-1',
      name: 'ออกแบบหน้าโปรไฟล์',
      description: 'ปรับหน้าโปรไฟล์ให้ใช้งานง่าย',
      sortOrder: 0,
      status: 'in_review',
      priority: 'high',
      dueDate: DateTime(2026, 8, 1),
      assigneeIds: const ['user-1'],
      attachments: const [
        TaskListAttachment(
          name: 'prototype.fig',
          url: 'https://example.com/prototype.fig',
          type: 'link',
        ),
      ],
      cards: [
        TaskCardRecord(
          id: 'legacy-card',
          listId: 'deliverable-1',
          title: 'การ์ดเก่าที่ต้องซ่อน',
          description: '',
          status: 'pending',
          sortOrder: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectDeliverableCard(
            deliverable: deliverable,
            assignees: const [
              UserSummary(
                id: 'user-1',
                firstName: 'สมชาย',
                lastName: 'ใจดี',
                position: 'Designer',
              ),
            ],
            assigneeCount: 1,
            onTap: () => openedDetail = true,
          ),
        ),
      ),
    );

    expect(find.text('ออกแบบหน้าโปรไฟล์'), findsOneWidget);
    expect(find.text('รอตรวจ'), findsOneWidget);
    expect(find.text('1 รายการ'), findsOneWidget);
    expect(find.text('1 คน'), findsOneWidget);
    expect(find.text('ส'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.text('การ์ดเก่าที่ต้องซ่อน'), findsNothing);

    await tester.tap(find.text('ออกแบบหน้าโปรไฟล์'));
    await tester.pump();

    expect(openedDetail, isTrue);
  });
}
