import '../../models/work_models.dart';

List<TaskListRecord> sortTaskListsForBoard(Iterable<TaskListRecord> lists) {
  final sorted = lists.toList(growable: false);
  sorted.sort(compareTaskListsForBoard);
  return sorted;
}

int compareTaskListsForBoard(TaskListRecord a, TaskListRecord b) {
  final aCompleted = a.status == 'completed';
  final bCompleted = b.status == 'completed';
  if (aCompleted != bCompleted) return aCompleted ? 1 : -1;

  final aDueDate = a.dueDate;
  final bDueDate = b.dueDate;
  if (aDueDate != null && bDueDate != null) {
    final dueDateComparison = aDueDate.compareTo(bDueDate);
    if (dueDateComparison != 0) return dueDateComparison;
  } else if (aDueDate != null) {
    return -1;
  } else if (bDueDate != null) {
    return 1;
  }

  final sortOrderComparison = a.sortOrder.compareTo(b.sortOrder);
  if (sortOrderComparison != 0) return sortOrderComparison;
  return a.id.compareTo(b.id);
}
