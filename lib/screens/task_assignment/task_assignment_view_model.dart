import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
import '../../models/work_models.dart';
import '../../services/auth_flow_service.dart';
import 'task_assignment_domain.dart';

class TaskAssignmentViewModel extends ChangeNotifier {
  TaskAssignmentViewModel({required this.service});

  final AuthFlowService service;

  List<TaskRecord> tasks = const [];
  List<AppUser> users = const [];
  List<BrandRecord> brands = const [];
  List<TaskCategoryRecord> categories = const [];
  Map<String, BrandRecord> brandMap = const {};
  Map<String, TaskCategoryRecord> categoryMap = const {};
  bool isLoading = true;
  String? error;
  String searchQuery = '';
  String? selectedBrandId;
  String? selectedCategoryId;
  String? selectedOwnership;

  bool get hasSheetFilters =>
      selectedBrandId != null || selectedCategoryId != null;

  List<TaskRecord> get filteredTasks {
    final query = searchQuery.toLowerCase();
    final currentUserId = assignmentFilterUserId(
      service.currentUser,
      service.currentUserId,
    );

    return tasks
        .where((task) {
          if (query.isNotEmpty &&
              !task.title.toLowerCase().contains(query) &&
              !task.description.toLowerCase().contains(query)) {
            return false;
          }
          if (selectedBrandId != null && task.brandId != selectedBrandId) {
            return false;
          }
          if (selectedCategoryId != null &&
              task.categoryId != selectedCategoryId) {
            return false;
          }
          return taskMatchesOwnershipFilter(
            task,
            currentUserId,
            selectedOwnership,
          );
        })
        .toList(growable: false);
  }

  Future<void> loadData() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final isEmployee = service.currentUser?.role == 'employee';
      final loadedTasks = await (isEmployee
          ? service.getMyTasks()
          : service.getAdminTasks());
      final auxiliary = await Future.wait<Object>([
        (isEmployee ? Future.value(<AppUser>[]) : service.getAdminUsers())
            .catchError((_) => <AppUser>[]),
        service.getBrands().catchError((_) => <BrandRecord>[]),
        service.getTaskCategories().catchError((_) => <TaskCategoryRecord>[]),
      ]);

      final loadedUsers = (auxiliary[0] as List<AppUser>)
          .where((user) => user.status == 'active')
          .toList(growable: false);
      final loadedBrands = auxiliary[1] as List<BrandRecord>;
      final loadedCategories = auxiliary[2] as List<TaskCategoryRecord>;

      tasks = loadedTasks;
      users = loadedUsers;
      brands = loadedBrands;
      categories = loadedCategories;
      brandMap = {for (final brand in loadedBrands) brand.id: brand};
      categoryMap = {
        for (final category in loadedCategories) category.id: category,
      };
      isLoading = false;
    } catch (e) {
      error = e.toString();
      isLoading = false;
    }

    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value.trim();
    notifyListeners();
  }

  void setCategory(String? id) {
    selectedCategoryId = id;
    notifyListeners();
  }

  void setOwnership(String? value) {
    selectedOwnership = value;
    notifyListeners();
  }

  void applySheetFilters(String? brandId, String? categoryId) {
    selectedBrandId = brandId;
    selectedCategoryId = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    searchQuery = '';
    selectedBrandId = null;
    selectedCategoryId = null;
    selectedOwnership = null;
    notifyListeners();
  }
}
