import 'package:flutter/material.dart';

import '../../models/work_models.dart';
import '../../services/auth_flow_service.dart';
import '../task_board_page.dart';

/// Entry point for the task list of a project.
///
/// The task list is represented by one board. Lists and cards are managed by
/// [TaskBoardPage], so opening a project no longer shows a separate list page
/// before entering the board.
class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({
    super.key,
    required this.project,
    required this.service,
    required this.onChanged,
    this.brandName,
    this.categoryName,
  });

  final TaskRecord project;
  final AuthFlowService service;
  final VoidCallback onChanged;

  // Kept for route compatibility with callers that already provide these
  // labels. The board uses the project data as its single source of truth.
  final String? brandName;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    return TaskBoardPage(
      task: project,
      service: service,
      onRefreshNeeded: onChanged,
    );
  }
}
