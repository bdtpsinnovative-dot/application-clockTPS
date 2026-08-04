part of '../admin_tasks_page.dart';

class _EditTaskModal extends StatelessWidget {
  const _EditTaskModal({
    required this.task,
    required this.users,
    required this.brands,
    required this.categories,
    required this.onSave,
    this.currentUser,
  });

  final TaskRecord task;
  final List<AppUser> users;
  final List<BrandRecord> brands;
  final List<TaskCategoryRecord> categories;
  final AppUser? currentUser;
  final Future<void> Function({
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime dueDate,
    String? brandId,
    String? categoryId,
    required String priority,
    required String status,
  })
  onSave;

  @override
  Widget build(BuildContext context) {
    return _CreateTaskModal(
      users: users,
      brands: brands,
      categories: categories,
      currentUser: currentUser,
      initialTask: task,
      onSubmit:
          (
            title,
            description,
            assigneeIds,
            dueDate,
            brandId,
            categoryId,
            priority,
            status,
            _,
          ) => onSave(
            title: title,
            description: description,
            assigneeIds: assigneeIds,
            dueDate: dueDate,
            brandId: brandId,
            categoryId: categoryId,
            priority: priority,
            status: status,
          ),
    );
  }
}
