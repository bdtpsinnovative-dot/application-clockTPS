import 'package:flutter/foundation.dart';

import '../../models/work_models.dart';
import '../../services/auth_flow_service.dart';

/// State for the employee-facing Project → Deliverable flow.
///
/// A deliverable is persisted in the legacy `task_lists` table. Nested
/// task_cards/task_sub_items are intentionally not exposed here, but remain in
/// the API response for backwards compatibility.
class ProjectDetailViewModel extends ChangeNotifier {
  ProjectDetailViewModel({
    required AuthFlowService service,
    required this.project,
  }) : _service = service;

  final AuthFlowService _service;
  final TaskRecord project;

  List<TaskListRecord> _deliverables = const [];
  List<UserSummary> _members = const [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedStatus;
  final Set<String> _busyIds = <String>{};

  List<TaskListRecord> get deliverables => List.unmodifiable(_deliverables);
  List<UserSummary> get members => List.unmodifiable(_members);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedStatus => _selectedStatus;

  List<TaskListRecord> get visibleDeliverables {
    final query = _searchQuery.trim().toLowerCase();
    return _deliverables.where((item) {
      if (_selectedStatus != null && item.status != _selectedStatus) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
    }).toList();
  }

  int get totalCount => _deliverables.length;
  int get completedCount =>
      _deliverables.where((item) => item.status == 'completed').length;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  bool isBusy(String id) => _busyIds.contains(id);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final deliverablesFuture = _fetchDeliverables();
      final membersFuture = _service
          .getTaskMembers(project.id)
          .catchError((_) => const <UserSummary>[]);
      _deliverables = await deliverablesFuture;
      _members = await membersFuture;
    } catch (error) {
      _error = _messageFor(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    notifyListeners();
  }

  Future<void> createDeliverable({
    required String name,
    required String description,
    required String priority,
    required List<String> assigneeIds,
    DateTime? dueDate,
    List<TaskListAttachment> attachments = const [],
  }) {
    return _mutate('create-deliverable', () async {
      await _service.createTaskList(
        project.id,
        name: name,
        description: description,
        priority: priority,
        dueDate: dueDate,
        assigneeIds: assigneeIds,
        attachments: attachments,
      );
    });
  }

  Future<void> updateDeliverableStatus(String deliverableId, String newStatus) {
    return _mutate('update-status-$deliverableId', () async {
      await _service.updateTaskList(deliverableId, status: newStatus);
    });
  }

  Future<void> refreshAfterDetailChange() => load();

  Future<void> _mutate(String busyId, Future<void> Function() action) async {
    if (_busyIds.contains(busyId)) return;
    _busyIds.add(busyId);
    notifyListeners();
    try {
      await action();
      _deliverables = await _fetchDeliverables();
      _error = null;
    } catch (error) {
      _error = _messageFor(error);
      rethrow;
    } finally {
      _busyIds.remove(busyId);
      notifyListeners();
    }
  }

  Future<List<TaskListRecord>> _fetchDeliverables() async {
    final items = await _service.getTrelloBoard(project.id);
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  String _messageFor(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'โหลดข้อมูลโปรเจกต์ไม่สำเร็จ' : message;
  }
}
