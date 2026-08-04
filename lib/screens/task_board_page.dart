import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/priority_selector.dart';
import 'package:hr_management/widgets/priority_badge.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../widgets/card_assignee_picker.dart';
import '../widgets/user_avatar.dart';
import '../widgets/work_due_date_picker.dart';
import 'task_board/task_list_sorting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

part 'task_board/card_detail_sheet.dart';
part 'task_board/task_list_detail_sheet.dart';
part 'task_board/task_list_activity_sheet.dart';
part 'task_board/board_support_widgets.dart';
part 'task_board/task_board_operations.dart';
part 'task_board/task_board_filters.dart';
part 'task_board/task_board_rendering.dart';

Future<void> showProjectTaskDetailSheet({
  required BuildContext context,
  required String projectId,
  required String groupName,
  required TaskCardRecord task,
  required AuthFlowService service,
  required bool canEdit,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _CardDetailSheet(
      taskId: projectId,
      listName: groupName,
      card: task,
      service: service,
      canEdit: canEdit,
      onChanged: onChanged,
    ),
  );
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '';
  final thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  return '${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year + 543}';
}

class _BoardDockButton extends StatelessWidget {
  const _BoardDockButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: active ? workBlue : workMuted),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: workBlue,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDateRange(DateTime? startDate, DateTime? dueDate) {
  if (startDate != null && dueDate != null) {
    return '${_formatDate(startDate)} → ${_formatDate(dueDate)}';
  }
  if (startDate != null) return 'เริ่ม ${_formatDate(startDate)}';
  if (dueDate != null) return 'ครบกำหนด ${_formatDate(dueDate)}';
  return '';
}

bool _hasInvalidDateRange(DateTime? startDate, DateTime? dueDate) {
  if (startDate == null || dueDate == null) return false;
  return dueDate.isBefore(startDate);
}

Color _deadlineColor(DateTime? dueDate, {required bool isCompleted}) {
  if (isCompleted) return const Color(0xFF15803D);
  if (dueDate == null) return workMuted;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final deadline = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final daysLeft = deadline.difference(today).inDays;
  if (daysLeft < 0) return const Color(0xFFB91C1C);
  if (daysLeft <= 2) return const Color(0xFFB45309);
  return workMuted;
}

double boardViewportFraction(bool compactMode) => compactMode ? 0.72 : 0.90;

class BoardKeyboardDismissRegion extends StatelessWidget {
  const BoardKeyboardDismissRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}

class BoardPageIndicator extends StatelessWidget {
  const BoardPageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
  });

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    return Semantics(
      label: 'หน้าที่ ${currentPage + 1} จาก $pageCount',
      child: Container(
        key: const ValueKey('board-page-indicator'),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(pageCount, (index) {
            final active = currentPage == index;
            return AnimatedContainer(
              key: ValueKey('board-page-dot-$index'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: active ? 14 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: active ? workBlue : workMuted.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class TaskBoardPage extends StatefulWidget {
  const TaskBoardPage({
    super.key,
    required this.task,
    required this.service,
    required this.onRefreshNeeded,
  });

  final TaskRecord task;
  final AuthFlowService service;
  final VoidCallback onRefreshNeeded;

  @override
  State<TaskBoardPage> createState() => _TaskBoardPageState();
}

class _TaskBoardPageState extends State<TaskBoardPage> {
  late PageController _pageController;
  late int _currentPage;
  List<TaskListRecord> _lists = [];
  List<UserSummary> _members = [];
  bool _loading = false;
  bool _isDraggingList = false;
  bool _scrolling = false;
  bool _isCompactMode = false;
  final ValueNotifier<double> _cardDragXNotifier = ValueNotifier<double>(0.0);
  final Set<String> _updatingListIds = <String>{};

  String _cardSearchQuery = '';
  List<String> _selectedListIds = [];
  String? _selectedCardStatus;
  final TextEditingController _cardSearchController = TextEditingController();

  // Status mapping colors & labels for Card badges
  final Map<String, String> _statusLabels = {
    'pending': 'รอทำ',
    'in_progress': 'กำลังทำ',
    'completed': 'เสร็จสิ้น',
  };

  final Map<String, Color> _statusTextColors = {
    'pending': const Color(0xFF2563EB),
    'in_progress': const Color(0xFFEA580C),
    'completed': const Color(0xFF16A34A),
  };

  final Map<String, Color> _statusBgColors = {
    'pending': const Color(0xFFEFF6FF),
    'in_progress': const Color(0xFFFFF7ED),
    'completed': const Color(0xFFF0FDF4),
  };

  Widget _buildUserAvatar(UserSummary user, {double radius = 10}) {
    final avatarUrl = _resolveAvatarUrl(user.avatarUrl);
    final hasAvatar = avatarUrl.isNotEmpty;
    final isSvg =
        hasAvatar &&
        (avatarUrl.toLowerCase().contains('.svg') ||
            avatarUrl.toLowerCase().contains('/svg'));

    Widget avatarWidget;
    if (hasAvatar) {
      if (isSvg) {
        avatarWidget = SvgPicture.network(
          avatarUrl,
          fit: BoxFit.cover,
          placeholderBuilder: (BuildContext context) =>
              _buildFallbackText(user, radius),
        );
      } else {
        avatarWidget = Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackText(user, radius),
        );
      }
    } else {
      avatarWidget = _buildFallbackText(user, radius);
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDBEAFE),
      ),
      child: ClipOval(child: avatarWidget),
    );
  }

  String _resolveAvatarUrl(String? url) {
    if (url == null) return '';
    var trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('r2://')) {
      return trimmed.replaceFirst(
        'r2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    }
    if (trimmed.startsWith('okpr2://')) {
      return trimmed.replaceFirst(
        'okpr2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final apiBase = widget.service.baseUrl;
    if (trimmed.startsWith('/')) {
      return '$apiBase$trimmed';
    }
    return '$apiBase/$trimmed';
  }

  Widget _buildFallbackText(UserSummary user, double radius) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFDBEAFE),
      child: Text(
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.9,
          color: const Color(0xFF1E40AF),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: boardViewportFraction(_isCompactMode),
    );
    _loadBoard();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardDragXNotifier.dispose();
    _cardSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleLists = _lists
        .where(
          (list) =>
              _selectedListIds.isEmpty || _selectedListIds.contains(list.id),
        )
        .toList();
    return Scaffold(
      backgroundColor: workBackground,
      body: BoardKeyboardDismissRegion(
        child: Stack(
          children: [
            Column(
              children: [
                // Gradient Header
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [workBlue, workSky],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back_ios_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (widget.task.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          widget.task.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _loadBoard,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _loading && _lists.isEmpty
                      ? TaskBoardSkeleton(
                          viewportFraction: boardViewportFraction(
                            _isCompactMode,
                          ),
                        )
                      : _buildSingleTaskBoard(visibleLists),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card Detail Bottom Sheet ──────────────────────────────────────
