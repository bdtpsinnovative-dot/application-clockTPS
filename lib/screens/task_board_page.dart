import 'package:flutter/material.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/priority_selector.dart';
import 'package:hr_management/widgets/priority_badge.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../widgets/card_assignee_picker.dart';
import '../widgets/card_comment_section.dart';
import '../widgets/work_due_date_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

part 'task_board/card_detail_sheet.dart';
part 'task_board/sub_item_detail_sheet.dart';
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
  bool _loading = false;
  bool _isDraggingList = false;
  bool _scrolling = false;
  bool _isCompactMode = false;
  final bool _useBottomBoardTools = true;
  final ValueNotifier<double> _cardDragXNotifier = ValueNotifier<double>(0.0);

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
    final isBoardCreator =
        widget.service.currentUser?.id == widget.task.assignedBy;
    final boardCreatorName = widget.task.assignedByName.isNotEmpty
        ? widget.task.assignedByName
        : 'เพื่อนร่วมงาน';
    final filteredLists = _lists.where((list) {
      if (_selectedListIds.isNotEmpty && !_selectedListIds.contains(list.id)) {
        return false;
      }
      return true;
    }).toList();

    final isListFilterActive = _selectedListIds.isNotEmpty;
    final pageCount = filteredLists.length + (isListFilterActive ? 0 : 1);

    final hasActiveFilters =
        _cardSearchQuery.isNotEmpty ||
        _selectedListIds.isNotEmpty ||
        _selectedCardStatus != null;
    final boardFilterCount =
        (_selectedListIds.isNotEmpty ? 1 : 0) +
        (_selectedCardStatus != null ? 1 : 0);
    final selectedListLabel = _selectedListIds.isEmpty
        ? null
        : _lists
              .where((list) => _selectedListIds.contains(list.id))
              .map((list) => list.name)
              .join(', ');
    final selectedStatusLabel = _selectedCardStatus == null
        ? null
        : _statusLabels[_selectedCardStatus!];
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
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isBoardCreator
                                                ? Icons.star_rounded
                                                : Icons.group_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isBoardCreator
                                                ? 'คุณเป็นเจ้าของบอร์ดนี้'
                                                : 'บอร์ดนี้เป็นของ $boardCreatorName (คุณถูกเพิ่มเข้ามา)',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
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

                // Compact search and filters
                if (!_useBottomBoardTools && _lists.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 42,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cardSearchController,
                                  onChanged: (value) {
                                    setState(() {
                                      _cardSearchQuery = value.trim();
                                    });
                                  },
                                  textInputAction: TextInputAction.search,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: workText,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'ค้นหาชื่อการ์ด...',
                                    hintStyle: const TextStyle(
                                      color: workMuted,
                                      fontSize: 12.5,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: workMuted,
                                      size: 18,
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 38,
                                    ),
                                    suffixIcon: _cardSearchQuery.isNotEmpty
                                        ? IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: workMuted,
                                              size: 17,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _cardSearchQuery = '';
                                                _cardSearchController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 9,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: workBlue,
                                        width: 1.25,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _showBoardFilterBottomSheet,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: boardFilterCount > 0
                                        ? const Color(0xFFEFF6FF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: boardFilterCount > 0
                                          ? const Color(0xFFBFDBFE)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        size: 17,
                                        color: boardFilterCount > 0
                                            ? workBlue
                                            : workMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        boardFilterCount > 0
                                            ? 'กรอง $boardFilterCount'
                                            : 'กรอง',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: boardFilterCount > 0
                                              ? workBlue
                                              : workText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasActiveFilters) ...[
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 26,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                if (selectedListLabel != null)
                                  _buildActiveBoardFilter(
                                    icon: Icons.view_column_outlined,
                                    label: selectedListLabel,
                                    onRemove: () {
                                      setState(() => _selectedListIds = []);
                                    },
                                  ),
                                if (selectedStatusLabel != null)
                                  _buildActiveBoardFilter(
                                    icon: Icons.flag_outlined,
                                    label: selectedStatusLabel,
                                    onRemove: () {
                                      setState(() {
                                        _selectedCardStatus = null;
                                      });
                                    },
                                  ),
                                if (_cardSearchQuery.isNotEmpty)
                                  _buildActiveBoardFilter(
                                    icon: Icons.search_rounded,
                                    label: '“$_cardSearchQuery”',
                                    onRemove: () {
                                      setState(() {
                                        _cardSearchQuery = '';
                                        _cardSearchController.clear();
                                      });
                                    },
                                  ),
                                TextButton(
                                  onPressed: _clearAllBoardFilters,
                                  style: TextButton.styleFrom(
                                    foregroundColor: workMuted,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'ล้างทั้งหมด',
                                    style: TextStyle(fontSize: 10.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Lists PageView — physics จะถูก toggle โดย _cardAreaActive
                // เมื่อนิ้วอยู่ใน Zone การ์ด: NeverScrollableScrollPhysics (PageView หยุด)
                // เมื่อนิ้วอยู่ใน Header: PageScrollPhysics (PageView เลื่อนปกติ)
                Expanded(
                  child: _loading && _lists.isEmpty
                      ? TaskBoardSkeleton(
                          viewportFraction: boardViewportFraction(
                            _isCompactMode,
                          ),
                        )
                      : filteredLists.isEmpty && isListFilterActive
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_list_off_rounded,
                                size: 48,
                                color: workMuted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'ไม่พบรายการที่ตรงตามตัวกรอง',
                                style: TextStyle(
                                  color: workMuted,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _clearAllBoardFilters,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: workBlue,
                                  side: const BorderSide(color: workBlue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'ล้างตัวกรองทั้งหมด',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            return PageView.builder(
                              controller: _pageController,
                              physics: const PageScrollPhysics(),
                              onPageChanged: (idx) {
                                setState(() {
                                  _currentPage = idx;
                                });
                              },
                              itemCount: pageCount,
                              itemBuilder: (context, idx) {
                                if (idx == filteredLists.length) {
                                  return _buildAddListPage();
                                }
                                final list = filteredLists[idx];
                                return _buildListPage(list, idx);
                              },
                            );
                          },
                        ),
                ),

                // Page indicators (Dots)
                if (!_useBottomBoardTools && pageCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: BoardPageIndicator(
                      currentPage: _currentPage,
                      pageCount: pageCount,
                    ),
                  ),
              ],
            ),

            if (_useBottomBoardTools && _lists.isNotEmpty && pageCount > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 68,
                child: IgnorePointer(
                  child: Center(
                    child: BoardPageIndicator(
                      currentPage: _currentPage,
                      pageCount: pageCount,
                    ),
                  ),
                ),
              ),

            if (_useBottomBoardTools && _lists.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBoardBottomDock(filterCount: boardFilterCount),
              ),

            // Edge strips สำหรับ Column drag (เลื่อนหน้าจอตอนลาก Column)
            if (_isDraggingList)
              Positioned(
                left: 0,
                top: 120,
                bottom: 80,
                width: 50,
                child: DragTarget<TaskListRecord>(
                  onWillAcceptWithDetails: (details) {
                    _startEdgeScroll(true);
                    return false;
                  },
                  onLeave: (data) => _stopEdgeScroll(),
                  builder: (context, candidateData, rejectedData) {
                    return Container(color: Colors.transparent);
                  },
                ),
              ),

            if (_isDraggingList)
              Positioned(
                right: 0,
                top: 120,
                bottom: 80,
                width: 50,
                child: DragTarget<TaskListRecord>(
                  onWillAcceptWithDetails: (details) {
                    _startEdgeScroll(false);
                    return false;
                  },
                  onLeave: (data) => _stopEdgeScroll(),
                  builder: (context, candidateData, rejectedData) {
                    return Container(color: Colors.transparent);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Card Detail Bottom Sheet ──────────────────────────────────────
