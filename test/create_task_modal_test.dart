import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/screens/admin_tasks_page.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  test('brand responsibilities are retained for automatic assignees', () {
    final brand = BrandRecord.fromJson({
      'id': 'brand-1',
      'name': 'Brand',
      'responsibilities': [
        {'user_id': 'user-1', 'responsibility_type': 'bd'},
      ],
    });

    expect(brand.hasTypedResponsibilities, isTrue);
    expect(brand.responsibilities.single.userId, 'user-1');
    expect(brand.responsibilities.single.type, 'bd');
  });

  testWidgets('create task modal creates task lists without layout errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _CreateTaskService();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        home: AdminTasksPage(service: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('มอบหมายงานใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('บอร์ดงานเริ่มต้น'), findsOneWidget);
    expect(find.byKey(const Key('toggle-assignee-picker')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('create-task-title')),
      'งานทดสอบ',
    );
    await tester.tap(find.byKey(const Key('toggle-assignee-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assignee-user-1')));
    await tester.tap(find.byKey(const Key('add-initial-board')));
    await tester.pumpAndSettle();

    final board = find.byKey(const Key('initial-board-0'));
    await tester.enterText(
      find.descendant(of: board, matching: find.byType(TextField)).first,
      'บอร์ดแรก',
    );
    await tester.tap(find.byKey(const Key('submit-create-task')));
    await tester.pumpAndSettle();

    expect(service.createdTaskCount, 1);
    expect(service.createdLists, ['บอร์ดแรก']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main and task-list bells filter and mark notifications', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _CreateTaskService(withNotifications: true);

    await tester.pumpWidget(
      MaterialApp(home: AdminTasksPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('งานที่ฉันสร้าง'), findsNothing);
    expect(find.text('งานที่ถูกเพิ่มเข้า'), findsNothing);
    expect(find.text('รายละเอียดที่ไม่ควรแสดง'), findsNothing);
    expect(find.text('แบรนด์ทดสอบ'), findsNothing);
    expect(find.text('หมวดหมู่ทดสอบ'), findsNothing);
    expect(find.text('รายการรวม'), findsOneWidget);
    expect(find.text('งานที่เสร็จแล้ว'), findsOneWidget);
    expect(find.text('งานที่ติดดาว'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('create-task-button')),
        matching: find.text('งาน'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('task-view-completed')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('task-list-notifications-task-1')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('task-view-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('task-list-notifications-task-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('task-view-starred')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('task-list-notifications-task-1')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('task-view-all')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('task-search-field'))).height,
      lessThanOrEqualTo(38),
    );
    await tester.tap(find.byKey(const Key('task-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('มุมมองงาน'), findsOneWidget);
    expect(find.text('งานที่ฉันสร้าง'), findsOneWidget);
    expect(find.text('งานที่ถูกเพิ่มเข้า'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-task-filter')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task-trash-button')));
    await tester.pumpAndSettle();
    expect(find.text('ถังขยะงานหลัก (30 วัน)'), findsOneWidget);
    expect(find.text('งานที่ลบแล้ว'), findsOneWidget);
    await tester.tap(find.byKey(const Key('restore-task-trash-1')));
    await tester.pumpAndSettle();
    expect(service.restoredTaskIds, contains('trash-1'));
    expect(find.text('ไม่มีงานในถังขยะ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-task-trash')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main-task-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('การแจ้งเตือนงานหลัก'), findsOneWidget);
    expect(find.text('รายละเอียดงานหลัก'), findsOneWidget);
    expect(find.text('รายละเอียดงานย่อย'), findsNothing);
    expect(service.markedNotificationIds, contains('notification-main'));
    expect(service.markedNotificationIds, isNot(contains('notification-list')));

    await tester.tap(find.byKey(const Key('close-task-notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-list-notifications-task-1')));
    await tester.pumpAndSettle();
    expect(find.text('การแจ้งเตือนงานย่อย'), findsOneWidget);
    expect(find.text('รายละเอียดงานย่อย'), findsOneWidget);
    expect(find.text('รายละเอียดงานหลัก'), findsNothing);
    expect(service.markedNotificationIds, contains('notification-list'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit task reuses create form and saves every task field', (
    tester,
  ) async {
    await initializeDateFormatting('th');
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _CreateTaskService(withNotifications: true);

    await tester.pumpWidget(
      MaterialApp(home: AdminTasksPage(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task-more-task-1')));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขงานมอบหมาย'), findsOneWidget);
    expect(find.text('บอร์ดงานเริ่มต้น'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('edit-task-title')))
          .controller
          ?.text,
      'โครงการทดสอบ',
    );
    expect(find.text('แบรนด์ทดสอบ'), findsWidgets);
    expect(find.text('หมวดหมู่ทดสอบ'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('submit-edit-task')));
    await tester.pumpAndSettle();

    expect(service.updatedTaskId, 'task-1');
    expect(service.updatedBrandId, 'brand-1');
    expect(service.updatedCategoryId, 'category-1');
    expect(service.updatedPriority, 'medium');
    expect(service.updatedStatus, 'pending');
    expect(tester.takeException(), isNull);
  });
}

class _CreateTaskService extends AuthFlowService {
  _CreateTaskService({this.withNotifications = false}) : super(dio: Dio());

  final bool withNotifications;

  int createdTaskCount = 0;
  final List<String> createdLists = [];
  final List<String> markedNotificationIds = [];
  final List<String> restoredTaskIds = [];
  String? updatedTaskId;
  String? updatedBrandId;
  String? updatedCategoryId;
  String? updatedPriority;
  String? updatedStatus;

  @override
  AppUser? get currentUser => withNotifications
      ? const AppUser(
          id: 'user-1',
          authId: 'auth-1',
          email: 'admin@example.com',
          firstName: 'Admin',
          lastName: 'Test',
          nickname: 'Admin',
          department: '',
          position: '',
          role: 'admin',
          status: 'active',
          avatarUrl: null,
          hasFaceEmbedding: false,
        )
      : null;

  @override
  Future<List<TaskRecord>> getAdminTasks() async {
    if (!withNotifications) return const [];
    return [
      TaskRecord(
        id: 'task-1',
        assignedTo: 'user-1',
        title: 'โครงการทดสอบ',
        description: 'รายละเอียดที่ไม่ควรแสดง',
        dueDate: DateTime(2026, 8, 5),
        status: 'pending',
        createdAt: DateTime(2026, 8, 4),
        brandId: 'brand-1',
        categoryId: 'category-1',
      ),
    ];
  }

  @override
  Future<List<TaskRecord>> getMyTasks() => getAdminTasks();

  @override
  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    if (!withNotifications) return const [];
    return [
      {
        'id': 'notification-main',
        'title': 'งานหลักเปลี่ยนแปลง',
        'body': 'รายละเอียดงานหลัก',
        'created_at': '2026-08-04T08:00:00Z',
        'is_read': false,
        'metadata': {'task_id': 'task-1'},
      },
      {
        'id': 'notification-list',
        'title': 'งานย่อยเปลี่ยนแปลง',
        'body': 'รายละเอียดงานย่อย',
        'created_at': '2026-08-04T09:00:00Z',
        'is_read': false,
        'metadata': '{"task_id":"task-1","list_id":"list-1"}',
      },
    ];
  }

  @override
  Future<List<TaskRecord>> getTrashTasks() async {
    if (!withNotifications || restoredTaskIds.contains('trash-1')) {
      return const [];
    }
    return [
      TaskRecord(
        id: 'trash-1',
        assignedTo: 'user-1',
        title: 'งานที่ลบแล้ว',
        description: '',
        dueDate: DateTime(2026, 8, 5),
        status: 'pending',
        createdAt: DateTime(2026, 8, 1),
        deletedAt: DateTime(2026, 8, 3),
      ),
    ];
  }

  @override
  Future<void> restoreTask(String id) async {
    restoredTaskIds.add(id);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    markedNotificationIds.add(id);
  }

  @override
  Future<List<AppUser>> getAdminUsers() async => const [
    AppUser(
      id: 'user-1',
      authId: 'auth-1',
      email: 'user@example.com',
      firstName: 'Fern',
      lastName: 'Test',
      nickname: 'Fern',
      department: '',
      position: '',
      role: 'employee',
      status: 'active',
      avatarUrl: null,
      hasFaceEmbedding: false,
    ),
  ];

  @override
  Future<List<BrandRecord>> getBrands() async => withNotifications
      ? const [BrandRecord(id: 'brand-1', name: 'แบรนด์ทดสอบ')]
      : const [];

  @override
  Future<List<TaskCategoryRecord>> getTaskCategories() async =>
      withNotifications
      ? const [TaskCategoryRecord(id: 'category-1', name: 'หมวดหมู่ทดสอบ')]
      : const [];

  @override
  Future<TaskRecord> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required DateTime dueDate,
    String? brandId,
    String? categoryId,
    List<String>? subItems,
    List<String>? assigneeIds,
    List<String>? listNames,
    String? priority,
    String? status,
  }) async {
    createdTaskCount++;
    return TaskRecord(
      id: 'task-1',
      assignedTo: assignedTo,
      title: title,
      description: description,
      dueDate: dueDate,
      status: status ?? 'pending',
      createdAt: DateTime(2026, 8, 4),
    );
  }

  @override
  Future<TaskRecord> updateTask({
    required String id,
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime dueDate,
    String? brandId,
    String? categoryId,
    String? priority,
    String? status,
  }) async {
    updatedTaskId = id;
    updatedBrandId = brandId;
    updatedCategoryId = categoryId;
    updatedPriority = priority;
    updatedStatus = status;
    return TaskRecord(
      id: id,
      assignedTo: assigneeIds.first,
      title: title,
      description: description,
      dueDate: dueDate,
      status: status ?? 'pending',
      priority: priority ?? 'medium',
      brandId: brandId,
      categoryId: categoryId,
      createdAt: DateTime(2026, 8, 4),
    );
  }

  @override
  Future<TaskListRecord> createTaskList(
    String taskId, {
    required String name,
    String description = '',
    String priority = 'medium',
    String status = 'in_progress',
    DateTime? startDate,
    DateTime? dueDate,
    String adminComment = '',
    List<TaskListAttachment> attachments = const [],
    List<String> assigneeIds = const [],
  }) async {
    createdLists.add(name);
    return TaskListRecord(
      id: 'list-${createdLists.length}',
      taskId: taskId,
      name: name,
      description: description,
      priority: priority,
      status: status,
      dueDate: dueDate,
      sortOrder: createdLists.length - 1,
      cards: const [],
    );
  }
}
