import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/screens/admin_tasks_page.dart';

TaskRecord _task({
  required String id,
  required String assignedBy,
  List<String> assigneeIds = const [],
}) {
  return TaskRecord(
    id: id,
    assignedTo: assigneeIds.isEmpty ? '' : assigneeIds.first,
    title: id,
    description: '',
    dueDate: DateTime(2026, 7, 24),
    status: 'pending',
    assignedBy: assignedBy,
    createdAt: DateTime(2026, 7, 24),
    assigneeIds: assigneeIds,
  );
}

void main() {
  test('assignment filters use database user id instead of auth id', () {
    const user = AppUser(
      id: 'database-user-id',
      authId: 'authentication-id',
      email: 'user@example.test',
      firstName: 'Test',
      lastName: 'User',
      department: '',
      position: '',
      role: 'employee',
      status: 'active',
      avatarUrl: null,
      hasFaceEmbedding: false,
    );

    expect(
      assignmentFilterUserId(user, 'authentication-id'),
      'database-user-id',
    );
  });

  test('assignment ownership filter separates created and joined boards', () {
    final created = _task(
      id: 'created',
      assignedBy: 'me',
      assigneeIds: const ['coworker'],
    );
    final joined = _task(
      id: 'joined',
      assignedBy: 'owner',
      assigneeIds: const ['me'],
    );

    expect(taskMatchesOwnershipFilter(created, 'me', 'created_by_me'), isTrue);
    expect(taskMatchesOwnershipFilter(joined, 'me', 'created_by_me'), isFalse);
    expect(taskMatchesOwnershipFilter(joined, 'me', 'joined'), isTrue);
    expect(taskMatchesOwnershipFilter(created, 'me', 'joined'), isFalse);
    expect(taskMatchesOwnershipFilter(created, 'me', null), isTrue);
    expect(taskMatchesOwnershipFilter(joined, 'me', null), isTrue);
  });

  test('assignment becomes overdue only after the due calendar day', () {
    final dueDate = DateTime(2026, 7, 24);

    expect(
      isAssignmentOverdue(
        dueDate,
        'in_progress',
        now: DateTime(2026, 7, 24, 23, 59),
      ),
      isFalse,
    );
    expect(
      isAssignmentOverdue(dueDate, 'in_progress', now: DateTime(2026, 7, 25)),
      isTrue,
    );
    expect(
      isAssignmentOverdue(dueDate, 'completed', now: DateTime(2026, 7, 25)),
      isFalse,
    );
  });
}
