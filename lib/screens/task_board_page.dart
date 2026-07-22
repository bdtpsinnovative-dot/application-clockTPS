import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

String _formatDate(DateTime? dt) {
  if (dt == null) return '';
  final thaiMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];
  return '${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year + 543}';
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
  bool _isDraggingCard = false;
  TaskCardRecord? _draggedCard;
  final ValueNotifier<double> _cardDragXNotifier = ValueNotifier<double>(0.0);
  bool _isDraggingList = false;
  TaskListRecord? _draggedList;
  bool _scrolling = false;

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
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.90);
    _loadBoard();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardDragXNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadBoard() async {
    setState(() => _loading = true);
    try {
      final boardLists = await widget.service.getTrelloBoard(widget.task.id);
      if (mounted) {
        setState(() {
          _lists = boardLists;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลบอร์ดล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _moveCardToList(TaskCardRecord card, String targetListId) async {
    final originalLists = List<TaskListRecord>.from(
      _lists.map(
        (l) => TaskListRecord(
          id: l.id,
          taskId: l.taskId,
          name: l.name,
          sortOrder: l.sortOrder,
          cards: List<TaskCardRecord>.from(l.cards),
        ),
      ),
    );

    setState(() {
      TaskCardRecord? foundCard;
      for (var l in _lists) {
        final idx = l.cards.indexWhere((c) => c.id == card.id);
        if (idx != -1) {
          foundCard = l.cards.removeAt(idx);
          break;
        }
      }

      if (foundCard != null) {
        final targetList = _lists.firstWhere((l) => l.id == targetListId);
        targetList.cards.add(
          TaskCardRecord(
            id: foundCard.id,
            listId: targetListId,
            title: foundCard.title,
            description: foundCard.description,
            status: foundCard.status,
            sortOrder: foundCard.sortOrder,
            subItems: foundCard.subItems,
            attachments: foundCard.attachments,
            adminComment: foundCard.adminComment,
          ),
        );
      }
    });

    try {
      await widget.service.updateTaskCard(card.id, status: card.status, description: card.description, listId: targetListId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _lists = originalLists;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ย้ายการ์ดล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startEdgeScroll(bool isLeft) {
    if (_scrolling) return;
    _scrolling = true;
    _scrollLoop(isLeft);
  }

  void _stopEdgeScroll() {
    _scrolling = false;
  }

  Future<void> _scrollLoop(bool isLeft) async {
    while (_scrolling && mounted) {
      final targetPage = _currentPage + (isLeft ? -1 : 1);
      final pageCount = _lists.length + 1;
      
      if (targetPage >= 0 && targetPage < pageCount) {
        await _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        await Future.delayed(const Duration(milliseconds: 600));
      } else {
        break;
      }
    }
    _scrolling = false;
  }

  Future<void> _swapLists(TaskListRecord listA, TaskListRecord listB) async {
    final idxA = _lists.indexWhere((l) => l.id == listA.id);
    final idxB = _lists.indexWhere((l) => l.id == listB.id);
    if (idxA == -1 || idxB == -1 || idxA == idxB) return;

    setState(() {
      final temp = _lists[idxA];
      _lists[idxA] = _lists[idxB];
      _lists[idxB] = temp;
    });

    try {
      for (int i = 0; i < _lists.length; i++) {
        await widget.service.updateTaskList(_lists[i].id, sortOrder: i);
      }
    } catch (e) {
      _loadBoard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สลับตำแหน่งรายการล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  // Create new List (คอลัมน์)
  Future<void> _createNewList() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('เพิ่มรายการใหม่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ชื่อรายการ (เช่น ทำหน้าจ่ายเงิน)',
            filled: true,
            fillColor: Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก', style: TextStyle(color: workMuted))),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('เพิ่ม', style: TextStyle(color: workBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      setState(() => _loading = true);
      try {
        await widget.service.createTaskList(widget.task.id, name);
        widget.onRefreshNeeded();
        _loadBoard();
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เพิ่มรายการล้มเหลว: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Create Card inside List
  Future<void> _createNewCard(String listId) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? dueDate;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'เพิ่มการ์ดใหม่',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: workText),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ชื่องานของการ์ด',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: workText),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'เช่น ทำหน้าชำระเงิน',
                      hintStyle: const TextStyle(color: workMuted, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: workBlue, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'รายละเอียด (ไม่จำเป็นต้องใส่ก็ได้)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: workText),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'คำอธิบายงานเพิ่มเติม...',
                      hintStyle: const TextStyle(color: workMuted, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: workBlue, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: workBlue,
                                      onPrimary: Colors.white,
                                      onSurface: workText,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDlgState(() => startDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.date_range_rounded, size: 16, color: workBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('วันที่เริ่ม', style: TextStyle(fontSize: 10, color: workMuted, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        startDate != null ? _formatDate(startDate) : 'เลือกวันเริ่ม',
                                        style: TextStyle(fontSize: 12, color: startDate != null ? workText : workMuted, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: workBlue,
                                      onPrimary: Colors.white,
                                      onSurface: workText,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDlgState(() => dueDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.alarm_rounded, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('วันสิ้นสุด', style: TextStyle(fontSize: 10, color: workMuted, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(
                                        dueDate != null ? _formatDate(dueDate) : 'เลือกกำหนดส่ง',
                                        style: TextStyle(fontSize: 12, color: dueDate != null ? workText : workMuted, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (titleController.text.trim().isNotEmpty) {
                              Navigator.pop(context, true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: workBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('สร้างการ์ด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      try {
        await widget.service.createTaskCard(
          listId,
          titleController.text.trim(),
          description: descController.text.trim(),
          startDate: startDate,
          dueDate: dueDate,
        );
        widget.onRefreshNeeded();
        _loadBoard();
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('สร้างการ์ดล้มเหลว: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Show Card Details & Checklists Bottom Sheet
  void _showCardDetailSheet(TaskCardRecord card) {
    final user = widget.service.currentUser;
    final bool canEdit = (user?.role == 'admin') || 
                         (user?.id == widget.task.assignedTo) || 
                         (widget.task.assigneeIds.contains(user?.id));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _CardDetailSheet(
        taskId: widget.task.id,
        card: card,
        service: widget.service,
        canEdit: canEdit,
        onChanged: () {
          widget.onRefreshNeeded();
          _loadBoard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _lists.length + 1; // last page is "+ เพิ่มรายการ"

    return Scaffold(
      backgroundColor: workBackground,
      body: Stack(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                                  ),
                                  if (widget.task.description.isNotEmpty)
                                    Text(
                                      widget.task.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _loadBoard,
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Lists PageView
              Expanded(
                child: _loading && _lists.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: workBlue))
                    : PageView.builder(
                        controller: _pageController,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentPage = idx;
                          });
                        },
                        itemCount: pageCount,
                        itemBuilder: (context, idx) {
                          if (idx == _lists.length) {
                            // "+ เพิ่มรายการ" page
                            return _buildAddListPage();
                          }
                          final list = _lists[idx];
                          return _buildListPage(list, idx);
                        },
                      ),
              ),

              // Page indicators (Dots)
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pageCount, (idx) {
                      final active = _currentPage == idx;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? workBlue : workMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),

          // Left auto-scroll edge trigger strip (50px wide)
          if (_isDraggingCard || _isDraggingList)
            Positioned(
              left: 0,
              top: 120,
              bottom: 80,
              width: 50,
              child: DragTarget<Object>(
                onWillAcceptWithDetails: (details) {
                  _startEdgeScroll(true);
                  return false; // Don't accept drop, only scroll page!
                },
                onLeave: (data) => _stopEdgeScroll(),
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    color: Colors.transparent, // Fully invisible to users
                  );
                },
              ),
            ),

          // Right auto-scroll edge trigger strip (50px wide)
          if (_isDraggingCard || _isDraggingList)
            Positioned(
              right: 0,
              top: 120,
              bottom: 80,
              width: 50,
              child: DragTarget<Object>(
                onWillAcceptWithDetails: (details) {
                  _startEdgeScroll(false);
                  return false; // Don't accept drop, only scroll page!
                },
                onLeave: (data) => _stopEdgeScroll(),
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    color: Colors.transparent, // Fully invisible to users
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editListName(TaskListRecord list) async {
    final nameController = TextEditingController(text: list.name);
    final descController = TextEditingController(text: list.description);
    DateTime? startDate = list.startDate;
    DateTime? dueDate = list.dueDate;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('แก้ไขข้อมูลรายการ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อรายการ',
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียดรายการ',
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDlgState(() => startDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('วันที่เริ่ม', style: TextStyle(fontSize: 10, color: workMuted)),
                              const SizedBox(height: 2),
                              Text(
                                startDate != null ? _formatDate(startDate) : 'เลือกวันเริ่ม',
                                style: TextStyle(fontSize: 11, color: startDate != null ? workText : workMuted, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDlgState(() => dueDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('วันที่สิ้นสุด', style: TextStyle(fontSize: 10, color: workMuted)),
                              const SizedBox(height: 2),
                              Text(
                                dueDate != null ? _formatDate(dueDate) : 'เลือกวันสิ้นสุด',
                                style: TextStyle(fontSize: 11, color: dueDate != null ? workText : workMuted, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก', style: TextStyle(color: workMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: workBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && nameController.text.trim().isNotEmpty) {
      setState(() => _loading = true);
      try {
        await widget.service.updateTaskList(
          list.id,
          name: nameController.text.trim(),
          description: descController.text.trim(),
          startDate: startDate,
          dueDate: dueDate,
        );
        widget.onRefreshNeeded();
        _loadBoard();
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('แก้ไขข้อมูลรายการล้มเหลว: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildListHeaderContent(TaskListRecord list) {
    final totalCards = list.cards.length;
    final doneCards = list.cards.where((c) => c.status == 'completed').length;
    final pct = totalCards == 0 ? 0 : (doneCards / totalCards * 100).toInt();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.drag_indicator_rounded, color: workMuted, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      list.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: workText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (totalCards > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 20),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: totalCards == 0 ? 0 : doneCards / totalCards,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: pct == 100 ? const Color(0xFF10B981) : workBlue,
                          minHeight: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: pct == 100 ? const Color(0xFF10B981) : workBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _editListName(list),
          icon: const Icon(Icons.mode_edit_outline_rounded, color: workMuted, size: 16),
        ),
      ],
    );
  }

  Widget _buildListPage(TaskListRecord list, int listIdx) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        if (details.data is TaskListRecord) {
          return (details.data as TaskListRecord).id != list.id;
        }
        if (details.data is TaskCardRecord) {
          return (details.data as TaskCardRecord).listId != list.id;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        if (details.data is TaskCardRecord) {
          _moveCardToList(details.data as TaskCardRecord, list.id);
        } else if (details.data is TaskListRecord) {
          _swapLists(details.data as TaskListRecord, list);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;

        final columnCardWidget = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.fromLTRB(5, 8, 5, 6),
          decoration: BoxDecoration(
            color: isOver ? workBlue.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOver ? workBlue : const Color(0xFFF1F5F9),
              width: isOver ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0D0F172A), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header of list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _buildListHeaderContent(list),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Cards inside list with compact + เพิ่มการ์ด button at the end
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                  itemCount: list.cards.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    if (index < list.cards.length) {
                      final card = list.cards[index];
                      return _buildCardItem(card, listIdx);
                    }
                    return _buildCompactAddCardButton(list.id);
                  },
                ),
              ),
            ],
          ),
        );

        // Calculate 3D tilt angle for background column pages
        double pageTiltAngle = 0.0;
        if (_isDraggingCard || _isDraggingList) {
          if (listIdx < _currentPage) {
            pageTiltAngle = 0.08; // Left column page tilts RIGHT
          } else if (listIdx > _currentPage) {
            pageTiltAngle = -0.08; // Right column page tilts LEFT
          }
        }

        final scaledColumn = AnimatedRotation(
          turns: pageTiltAngle / (2 * 3.1415926535),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: (_isDraggingCard || _isDraggingList) ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: columnCardWidget,
          ),
        );

        return LongPressDraggable<TaskListRecord>(
          data: list,
          delay: const Duration(milliseconds: 200),
          feedback: Material(
            type: MaterialType.transparency,
            child: _TiltingDragCard(
              dragXNotifier: _cardDragXNotifier,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: columnCardWidget,
              ),
            ),
          ),
          childWhenDragging: const SizedBox.shrink(),
          onDragStarted: () {
            final curPage = _currentPage;
            _pageController.dispose();
            _cardDragXNotifier.value = MediaQuery.of(context).size.width / 2;
            setState(() {
              _isDraggingList = true;
              _draggedList = list;
              _pageController = PageController(initialPage: curPage, viewportFraction: 0.75);
            });
          },
          onDragUpdate: (details) {
            _cardDragXNotifier.value = details.globalPosition.dx;
          },
          onDragEnd: (details) {
            final curPage = _currentPage;
            _pageController.dispose();
            setState(() {
              _isDraggingList = false;
              _draggedList = null;
              _pageController = PageController(initialPage: curPage, viewportFraction: 0.90);
            });
          },
          child: scaledColumn,
        );
      },
    );
  }

  Widget _buildCardItem(TaskCardRecord card, int listIdx) {
    return LongPressDraggable<TaskCardRecord>(
      data: card,
      maxSimultaneousDrags: 1,
      feedback: Material(
        type: MaterialType.transparency,
        child: _TiltingDragCard(
          dragXNotifier: _cardDragXNotifier,
          child: _buildCardContent(card),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      onDragStarted: () {
        final curPage = _currentPage;
        _pageController.dispose();
        _cardDragXNotifier.value = MediaQuery.of(context).size.width / 2;
        setState(() {
          _isDraggingCard = true;
          _draggedCard = card;
          _pageController = PageController(initialPage: curPage, viewportFraction: 0.75);
        });
      },
      onDragUpdate: (details) {
        _cardDragXNotifier.value = details.globalPosition.dx;
      },
      onDragEnd: (details) {
        final curPage = _currentPage;
        _pageController.dispose();
        setState(() {
          _isDraggingCard = false;
          _draggedCard = null;
          _pageController = PageController(initialPage: curPage, viewportFraction: 0.90);
        });
      },
      child: _buildCardContent(card),
    );
  }

  Widget _buildCompactAddCardButton(String listId) {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      height: 32,
      child: InkWell(
        onTap: () => _createNewCard(listId),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 15, color: workBlue),
              SizedBox(width: 4),
              Text(
                'เพิ่มการ์ด',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: workBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(TaskCardRecord card) {
    final doneCount = card.subItems.where((s) => s.isDone).length;
    final totalCount = card.subItems.length;
    final pct = totalCount == 0 ? 0 : (doneCount / totalCount * 100).toInt();

    final isCompleted = card.status == 'completed';
    final badgeBg = _statusBgColors[card.status] ?? const Color(0xFFF1F5F9);
    final badgeText = _statusTextColors[card.status] ?? workMuted;
    final badgeLabel = _statusLabels[card.status] ?? 'รอทำ';

    return InkWell(
      onTap: () => _showCardDetailSheet(card),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFF1F5F9),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tick checkbox
            GestureDetector(
              onTap: () async {
                final newStatus = isCompleted ? 'pending' : 'completed';
                try {
                  await widget.service.updateTaskCard(card.id, status: newStatus);
                  _loadBoard();
                } catch (_) {}
              },
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1, right: 8),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
            ),
            // Card content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isCompleted ? const Color(0xFF6B7280) : workText,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(color: badgeText, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (card.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      card.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: workMuted, fontSize: 10.5),
                    ),
                  ],
                  if (card.startDate != null || card.dueDate != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 10, color: workBlue),
                        const SizedBox(width: 3),
                        Text(
                          '${card.startDate != null ? _formatDate(card.startDate) : ''}${card.startDate != null && card.dueDate != null ? ' - ' : ''}${card.dueDate != null ? _formatDate(card.dueDate) : ''}',
                          style: const TextStyle(fontSize: 10, color: workMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  if (totalCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.playlist_add_check_rounded, size: 12, color: workBlue),
                            SizedBox(width: 3),
                            Text(
                              'ความคืบหน้า',
                              style: TextStyle(fontSize: 10, color: workMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Text(
                          '$pct%',
                          style: const TextStyle(fontSize: 10.5, color: workBlue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: totalCount == 0 ? 0 : doneCount / totalCount,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: workBlue,
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddListPage() {
    final addWidget = Container(
      margin: const EdgeInsets.fromLTRB(5, 8, 5, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D0F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.playlist_add_rounded, size: 36, color: workBlue),
              ),
              const SizedBox(height: 16),
              const Text(
                'เพิ่มรายการงาน',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: workText),
              ),
              const SizedBox(height: 6),
              const Text(
                'คุณสามารถเพิ่มคอลัมน์ขั้นตอนการทำงานใหม่ได้\nเช่น ทำหน้าขาย, ออกแบบ UI, ตรวจสอบงาน',
                textAlign: TextAlign.center,
                style: TextStyle(color: workMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                height: 48,
                child: ElevatedButton(
                  onPressed: _createNewList,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: workBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('เพิ่มรายการ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    double pageTiltAngle = 0.0;
    if (_isDraggingCard || _isDraggingList) {
      pageTiltAngle = -0.08; // Add list page on right side tilts LEFT
    }

    return AnimatedRotation(
      turns: pageTiltAngle / (2 * 3.1415926535),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: (_isDraggingCard || _isDraggingList) ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: addWidget,
      ),
    );
  }
}

// ─── Card Detail Bottom Sheet ──────────────────────────────────────
class _CardDetailSheet extends StatefulWidget {
  const _CardDetailSheet({
    required this.taskId,
    required this.card,
    required this.service,
    required this.canEdit,
    required this.onChanged,
  });

  final String taskId;
  final TaskCardRecord card;
  final AuthFlowService service;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  State<_CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<_CardDetailSheet> {
  late List<TaskSubItem> _subItems;
  late List<CardAttachment> _attachments;
  late String _currentStatus;
  bool _saving = false;
  final _subItemController = TextEditingController();
  late TextEditingController _adminCommentController;

  final List<String> _statusKeys = ['pending', 'in_progress', 'completed'];
  final List<String> _statusLabels = ['รอทำ', 'กำลังทำ', 'เสร็จสิ้น'];
  final List<Color> _statusColors = [
    const Color(0xFF64748B),
    const Color(0xFFEA580C),
    const Color(0xFF10B981)
  ];

  bool _loadingCard = false;

  @override
  void initState() {
    super.initState();
    _subItems = List.from(widget.card.subItems);
    _attachments = List.from(widget.card.attachments);
    _currentStatus = widget.card.status;
    _adminCommentController = TextEditingController(text: widget.card.adminComment);
    
    // Auto-refresh card details from the server to prevent stale state across different devices
    Future.microtask(() => _refreshCardData());
  }

  Future<void> _refreshCardData() async {
    if (!mounted) return;
    try {
      final board = await widget.service.getTrelloBoard(widget.taskId);
      TaskCardRecord? updatedCard;
      for (var list in board) {
        for (var card in list.cards) {
          if (card.id == widget.card.id) {
            updatedCard = card;
            break;
          }
        }
      }
      if (updatedCard != null && mounted) {
        setState(() {
          _subItems = List.from(updatedCard!.subItems);
          _attachments = List.from(updatedCard.attachments);
          _currentStatus = updatedCard.status;
          _adminCommentController.text = updatedCard.adminComment ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error auto-refreshing card detail: $e');
    }
  }

  @override
  void dispose() {
    _adminCommentController.dispose();
    _subItemController.dispose();
    super.dispose();
  }

  Future<void> _updateCardStatus(String status) async {
    setState(() {
      _currentStatus = status;
      _saving = true;
    });

    try {
      await widget.service.updateTaskCard(widget.card.id, status: status, description: widget.card.description);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เปลี่ยนสถานะการ์ดล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAdminComment() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateTaskCard(
        widget.card.id,
        status: widget.card.status,
        description: widget.card.description,
        adminComment: _adminCommentController.text.trim(),
      );
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกความคิดเห็นผู้ดูแลแล้ว!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกความคิดเห็นล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSubItem(TaskSubItem item, int index) async {
    final originalState = item.isDone;
    final newStatus = !originalState ? 'completed' : 'pending';

    setState(() {
      _subItems[index] = TaskSubItem(
        id: item.id,
        taskId: item.taskId,
        cardId: item.cardId,
        title: item.title,
        isDone: !originalState,
        status: newStatus,
        sortOrder: item.sortOrder,
      );
    });

    try {
      await widget.service.toggleTaskSubItem(item.id, newStatus);
      widget.onChanged();
    } catch (e) {
      setState(() {
        _subItems[index] = item; // Revert
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตความคืบหน้าล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addSubItem() async {
    final title = _subItemController.text.trim();
    if (title.isEmpty) return;

    _subItemController.clear();
    setState(() => _saving = true);

    try {
      final newItem = await widget.service.createCardSubItem(widget.card.id, title);
      setState(() {
        _subItems.add(newItem);
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่มรายการย่อยล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCard() async {
    final titleController = TextEditingController(text: widget.card.title);
    final descController = TextEditingController(text: widget.card.description);
    DateTime? startDate = widget.card.startDate;
    DateTime? dueDate = widget.card.dueDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: workBlue, size: 22),
              SizedBox(width: 8),
              Text('แก้ไขข้อมูลการ์ด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: workText)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ชื่องาน', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: workText)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 13.5, color: workText),
                  decoration: InputDecoration(
                    hintText: 'กรอกชื่องาน...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: workBlue, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('รายละเอียด', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: workText)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13.5, color: workText),
                  decoration: InputDecoration(
                    hintText: 'กรอกรายละเอียดเพิ่มเติม...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: workBlue, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('วันที่เริ่ม', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: workText)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: workBlue,
                                      onPrimary: Colors.white,
                                      onSurface: workText,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDlgState(() => startDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 14, color: workMuted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      startDate != null ? _formatDate(startDate) : 'เลือกวันเริ่ม',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: startDate != null ? workText : workMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('วันสิ้นสุด', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: workText)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: workBlue,
                                      onPrimary: Colors.white,
                                      onSurface: workText,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDlgState(() => dueDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 14, color: workMuted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dueDate != null ? _formatDate(dueDate) : 'เลือกวันส่ง',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: dueDate != null ? workText : workMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: workMuted,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text('ยกเลิก', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: workBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 0,
              ),
              child: const Text('บันทึก', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _saving = true);
      try {
        await widget.service.updateTaskCard(
          widget.card.id,
          title: titleController.text.trim(),
          description: descController.text.trim(),
          startDate: startDate,
          dueDate: dueDate,
        );
        widget.onChanged();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('แก้ไขการ์ดล้มเหลว: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _subItems.where((s) => s.isDone).length;
    final totalCount = _subItems.length;
    final pct = totalCount == 0 ? 0 : (doneCount / totalCount * 100).toInt();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Navigation / Action Bar (ชิดซ้ายเป็นระเบียบเรียบร้อย)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                // Left side: Back Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: workText),
                  tooltip: 'ย้อนกลับ',
                ),
                const SizedBox(width: 6),
                // Left-aligned Title
                const Text(
                  'การ์ดงาน',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: workText),
                ),
                const Spacer(), // ดันปุ่มทั้งหมดไปด้านขวา
                // Right side: Action Menu Buttons (+ and ...)
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: workBlue),
                  tooltip: 'เพิ่มรายการย่อย',
                  onPressed: () async {
                    final textController = TextEditingController();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        title: const Text('เพิ่มรายการย่อยใหม่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        content: TextField(
                          controller: textController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'พิมพ์หัวข้อรายการย่อย...',
                            filled: true,
                            fillColor: Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก', style: TextStyle(color: workMuted)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (textController.text.trim().isNotEmpty) {
                                Navigator.pop(context, true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: workBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('เพิ่ม'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && textController.text.trim().isNotEmpty) {
                      setState(() => _saving = true);
                      try {
                        final newItem = await widget.service.createCardSubItem(widget.card.id, textController.text.trim());
                        setState(() {
                          _subItems.add(newItem);
                        });
                        widget.onChanged();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('เพิ่มรายการย่อยล้มเหลว: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        setState(() => _saving = false);
                      }
                    }
                  },
                ),
                const SizedBox(width: 4),
                // Action Menu Button (... icon)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: workMuted),
                  onSelected: (action) async {
                    if (action == 'edit_card') {
                      _editCard();
                    } else if (action == 'delete_card') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: const Text('ลบการ์ด', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: Text('คุณต้องการลบการ์ด "${widget.card.title}" หรือไม่?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: workMuted))),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('ลบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await widget.service.deleteTaskCard(widget.card.id);
                          widget.onChanged();
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('ลบการ์ดล้มเหลว: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    } else if (action.startsWith('status_')) {
                      final newStatus = action.substring(7); // Extract "todo", "doing", "done"
                      _updateCardStatus(newStatus);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit_card',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: workBlue, size: 18),
                          SizedBox(width: 8),
                          Text('แก้ไขการ์ด', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete_card',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('ลบการ์ด', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'status_todo',
                      child: Row(
                        children: [
                          Icon(Icons.circle_rounded, color: _statusColors[0], size: 12),
                          const SizedBox(width: 8),
                          const Text('ย้ายไป "รอทำ"', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'status_doing',
                      child: Row(
                        children: [
                          Icon(Icons.circle_rounded, color: _statusColors[1], size: 12),
                          const SizedBox(width: 8),
                          const Text('ย้ายไป "กำลังทำ"', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'status_done',
                      child: Row(
                        children: [
                          Icon(Icons.circle_rounded, color: _statusColors[2], size: 12),
                          const SizedBox(width: 8),
                          const Text('ย้ายไป "เสร็จสิ้น"', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. รายการย่อย (Checklist)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.playlist_add_check_rounded, color: workBlue, size: 20),
                              const SizedBox(width: 6),
                              const Text('รายการย่อย (Checklist)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: workText)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (totalCount == 0)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('ไม่มีรายการย่อยในการ์ดนี้', style: TextStyle(color: workMuted, fontSize: 12.5, fontStyle: FontStyle.italic)),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: totalCount,
                          itemBuilder: (context, i) {
                            final item = _subItems[i];
                            final hasDetails = item.startDate != null ||
                                item.dueDate != null ||
                                (item.linkUrl != null && item.linkUrl!.isNotEmpty) ||
                                (item.attachmentUrl != null && item.attachmentUrl!.isNotEmpty) ||
                                (item.verificationNotes != null && item.verificationNotes!.isNotEmpty);

                            return Container(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: item.isDone,
                                    activeColor: workBlue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (_) => _toggleSubItem(item, i),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showSubItemDetailSheet(item, i),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.title,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: item.isDone ? workMuted : workText,
                                                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                                                    ),
                                                  ),
                                                  if (hasDetails) ...[
                                                    const SizedBox(height: 3),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 2,
                                                      children: [
                                                        if (item.startDate != null || item.dueDate != null)
                                                          Text(
                                                            '${item.startDate != null ? _formatThaiDate(item.startDate) : 'เริ่ม'} - ${item.dueDate != null ? _formatThaiDate(item.dueDate) : 'กำหนด'}',
                                                            style: const TextStyle(fontSize: 9.5, color: workMuted),
                                                          ),
                                                        if (item.linkUrl != null && item.linkUrl!.isNotEmpty)
                                                          const Text('• ลิงก์', style: TextStyle(fontSize: 9.5, color: workBlue, fontWeight: FontWeight.bold)),
                                                        if (item.attachmentUrl != null && item.attachmentUrl!.isNotEmpty)
                                                          const Text('• ไฟล์แนบ', style: TextStyle(fontSize: 9.5, color: workMuted)),
                                                        if (item.verificationNotes != null && item.verificationNotes!.isNotEmpty)
                                                          const Text('• ตรวจสอบแล้ว', style: TextStyle(fontSize: 9.5, color: Colors.green)),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right_rounded, color: workMuted, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),

                      // 2. เพิ่มไฟล์แนบ (ปุ่มแนบไฟล์/แนบลิงก์)
                      if (widget.canEdit) ...[
                        Row(
                          children: [
                            const Icon(Icons.add_circle_outline_rounded, color: workBlue, size: 18),
                            const SizedBox(width: 6),
                            const Text('เพิ่มไฟล์แนบหลักฐาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: workText)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionBoxCard(
                                icon: Icons.attach_file_rounded,
                                label: 'แนบไฟล์',
                                color: workBlue,
                                onTap: () => _uploadEvidenceFileCombined(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildActionBoxCard(
                                icon: Icons.link_rounded,
                                label: 'แนบลิงก์',
                                color: Colors.green,
                                onTap: () => _attachEvidenceLink(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 3. แสดงสิ่งที่แนบ
                      if (_attachments.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: workBlue, size: 18),
                            const SizedBox(width: 6),
                            const Text('หลักฐานที่แนบมา', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: workText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (int idx = 0; idx < _attachments.length; idx++)
                              _buildAttachmentBox(_attachments[idx], idx),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 4. รายละเอียดการ์ดงาน
                      Row(
                        children: [
                          const Icon(Icons.subject_rounded, color: workBlue, size: 18),
                          const SizedBox(width: 6),
                          const Text('รายละเอียดการ์ดงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: workText)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.card.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: workText),
                            ),
                            if (widget.card.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.card.description,
                                style: const TextStyle(fontSize: 13, color: workMuted, height: 1.4),
                              ),
                            ],
                            if (widget.card.startDate != null || widget.card.dueDate != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: workBlue),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ระยะเวลา: ${widget.card.startDate != null ? _formatDate(widget.card.startDate) : ''}${widget.card.startDate != null && widget.card.dueDate != null ? ' ถึง ' : ''}${widget.card.dueDate != null ? _formatDate(widget.card.dueDate) : ''}',
                                      style: const TextStyle(fontSize: 12, color: workText, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. ความคิดเห็น
                      _buildCardAdminCommentSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildAttachmentBox(CardAttachment attachment, int index) {
    final user = widget.service.currentUser;
    final bool isTemp = attachment.id.startsWith('temp_');
    final bool isImage = attachment.type == 'image';
    final bool isLink = attachment.type == 'link';
    final fullUrl = isImage && !isTemp
        ? resolveFullR2Url(attachment.url, widget.service.baseUrl)
        : attachment.url;

    return Container(
      width: 105,
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (isTemp) return;
                if (isLink || !isImage) {
                  // Show URL in snackbar (open externally when url_launcher available)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('URL: $fullUrl'), backgroundColor: workBlue),
                  );
                } else {
                  // Show image fullscreen
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      insetPadding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(fullUrl, fit: BoxFit.contain),
                      ),
                    ),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isImage
                    ? (isTemp
                        ? Image.file(
                            File(attachment.url),
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            fullUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.broken_image_rounded, color: workMuted),
                            ),
                          ))
                    : Container(
                        padding: const EdgeInsets.all(8),
                        color: isLink ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isLink ? Icons.link_rounded : Icons.insert_drive_file_rounded,
                              size: 28,
                              color: isLink ? Colors.green : Colors.redAccent,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attachment.name.isEmpty ? attachment.url : attachment.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isLink ? Colors.green[800] : Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (isImage)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                color: Colors.black54,
                child: Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          if (widget.canEdit && !isTemp && (user?.role == 'admin' || attachment.createdBy == user?.id || attachment.createdBy == null))
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () async {
                  try {
                    await widget.service.deleteCardAttachment(attachment.id);
                    setState(() {
                      _attachments.removeAt(index);
                    });
                    widget.onChanged();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ลบหลักฐานล้มเหลว: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),
          if (isTemp)
            Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardAdminCommentSection() {
    final bool isAdminOrHr = widget.service.currentUser?.role == 'admin' || widget.service.currentUser?.role == 'hr';
    final hasComment = widget.card.adminComment != null && widget.card.adminComment!.trim().isNotEmpty;

    if (!isAdminOrHr && !hasComment) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // warm light amber background for comments
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment_rounded, size: 16, color: Colors.amber[800]),
              const SizedBox(width: 6),
              Text(
                'ความคิดเห็นจากผู้ดูแล (Admin Comment)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.amber[900]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isAdminOrHr) ...[
            TextField(
              controller: _adminCommentController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, color: workText),
              decoration: const InputDecoration(
                hintText: 'พิมพ์ความคิดเห็น/คำแนะนำผู้ดูแล...',
                hintStyle: TextStyle(fontSize: 12.5, color: workMuted),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAdminComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('บันทึกความเห็น', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            Text(
              widget.card.adminComment ?? '',
              style: const TextStyle(fontSize: 13, color: workText, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBoxCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadSingleFileInBackground(File uploadFile, String filename, bool isImage, String tempId) async {
    try {
      final url = await widget.service.uploadImage(uploadFile);
      final attachType = isImage ? 'image' : 'file';

      final attachment = await widget.service.createCardAttachment(
        widget.card.id,
        url: url,
        name: filename,
        type: attachType,
      );

      if (mounted) {
        setState(() {
          final idx = _attachments.indexWhere((element) => element.id == tempId);
          if (idx != -1) {
            _attachments[idx] = attachment;
          } else {
            _attachments.add(attachment);
          }
        });
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _attachments.removeWhere((element) => element.id == tempId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปโหลดไฟล์ $filename ล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadEvidenceFileCombined() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        int tempCount = 0;
        for (var fileItem in result.files) {
          if (fileItem.path == null) continue;
          File file = File(fileItem.path!);
          final filename = fileItem.name;
          final lowerName = filename.toLowerCase();
          
          final bool isImage = lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerName.endsWith('.png');
          final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${tempCount++}';

          // Immediately add temporary item for instant local display
          final tempAttachment = CardAttachment(
            id: tempId,
            cardId: widget.card.id,
            url: file.path, // Store local path temporarily
            name: filename,
            type: (isImage || lowerName.endsWith('.webp')) ? 'image' : 'file',
            createdAt: DateTime.now(),
          );

          setState(() {
            _attachments.add(tempAttachment);
          });

          // Upload and finalize in background without blocking UI
          _uploadSingleFileInBackground(file, filename, isImage, tempId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('แนบไฟล์ล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _attachEvidenceLink() async {
    final titleController = TextEditingController();
    final linkController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('แนบหลักฐานลิงก์ใหม่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'ชื่อหลักฐาน/ลิงก์ (เช่น งานออกแบบเว็บ)...',
                filled: true,
                fillColor: Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: linkController,
              decoration: const InputDecoration(
                hintText: 'https://example.com...',
                filled: true,
                fillColor: Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(color: workMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: workBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (confirm == true && linkController.text.trim().isNotEmpty) {
      final link = linkController.text.trim();
      final name = titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'ลิงก์แนบ';
      setState(() => _saving = true);
      try {
        final attachment = await widget.service.createCardAttachment(
          widget.card.id,
          url: link,
          name: name,
          type: 'link',
        );
        setState(() {
          _attachments.add(attachment);
        });
        widget.onChanged();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('แนบลิงก์ล้มเหลว: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  void _showSubItemDetailSheet(TaskSubItem item, int index) async {
    await showModalBottomSheet<TaskSubItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _SubItemDetailSheet(
        item: item,
        service: widget.service,
        canEdit: widget.canEdit,
        onChanged: widget.onChanged,
      ),
    );

    await _refreshCardData();
  }
}

// ─── Sub-item Detail Sheet ──────────────────────────────────────────
class _SubItemDetailSheet extends StatefulWidget {
  const _SubItemDetailSheet({
    required this.item,
    required this.service,
    required this.canEdit,
    required this.onChanged,
  });

  final TaskSubItem item;
  final AuthFlowService service;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  State<_SubItemDetailSheet> createState() => _SubItemDetailSheetState();
}

class _SubItemDetailSheetState extends State<_SubItemDetailSheet> {
  late TextEditingController _titleController;
  late TextEditingController _linkUrlController;
  late TextEditingController _attachmentUrlController;
  late TextEditingController _verificationController;
  late TextEditingController _adminCommentController;
  late TextEditingController _inspectionNotesController;

  DateTime? _startDate;
  DateTime? _dueDate;
  bool _saving = false;
  bool _verifying = false;
  String _selectedInspectionStatus = 'approved';
  List<SubItemVerification> _verifications = [];
  String _currentStatus = 'pending';
  final List<Map<String, String>> _uploadingFiles = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _linkUrlController = TextEditingController(text: widget.item.linkUrl ?? '');
    _attachmentUrlController = TextEditingController(text: widget.item.attachmentUrl ?? '');
    _verificationController = TextEditingController(text: widget.item.verificationNotes ?? '');
    _adminCommentController = TextEditingController(text: widget.item.adminComment ?? '');
    _inspectionNotesController = TextEditingController();
    _startDate = widget.item.startDate;
    _dueDate = widget.item.dueDate;
    _verifications = List.from(widget.item.verifications);
    _currentStatus = widget.item.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkUrlController.dispose();
    _attachmentUrlController.dispose();
    _verificationController.dispose();
    _adminCommentController.dispose();
    _inspectionNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: workBlue,
            onPrimary: Colors.white,
            onSurface: workText,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: workBlue,
            onPrimary: Colors.white,
            onSurface: workText,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _pickFileOrImage(bool isImageOnly) async {
    setState(() => _saving = true);
    try {
      final result = await fp.FilePicker.pickFiles(
        type: isImageOnly ? fp.FileType.image : fp.FileType.custom,
        allowedExtensions: isImageOnly ? null : ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _saving = false);
        return;
      }

      File selectedFile = File(result.files.single.path!);
      final filename = result.files.single.name.toLowerCase();

      // Compress if it is an image (jpg, jpeg, png) to WebP for Cloudflare savings
      if (filename.endsWith('.jpg') || filename.endsWith('.jpeg') || filename.endsWith('.png')) {
        final tempDir = await getTemporaryDirectory();
        final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          selectedFile.path,
          targetPath,
          format: CompressFormat.webp,
          quality: 75,
        );
        if (compressedFile != null) {
          selectedFile = File(compressedFile.path);
        }
      }

      // Upload using existing service (R2 Cloudflare upload API)
      final uploadedUrl = await widget.service.uploadImage(selectedFile);
      setState(() {
        _attachmentUrlController.text = uploadedUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดไฟล์สำเร็จ!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _getAttachmentUrls() {
    final text = _attachmentUrlController.text.trim();
    if (text.isEmpty) return [];
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> _getLinkUrls() {
    final text = _linkUrlController.text.trim();
    if (text.isEmpty) return [];
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  String _resolveFullUrl(String url) {
    return resolveFullR2Url(url, widget.service.baseUrl);
  }

  Widget _buildSubItemEvidencePreviewBox({
    required String url,
    required bool isLink,
    required VoidCallback onDelete,
  }) {
    final fullUrl = _resolveFullUrl(url);
    final bool isImage = !isLink &&
        (fullUrl.toLowerCase().contains('.webp') ||
         fullUrl.toLowerCase().contains('.jpg') ||
         fullUrl.toLowerCase().contains('.jpeg') ||
         fullUrl.toLowerCase().contains('.png'));

    return Container(
      width: 100,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage
                  ? Image.network(
                      fullUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.broken_image_rounded, color: workMuted),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(6),
                      color: isLink ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLink ? Icons.link_rounded : Icons.picture_as_pdf_rounded,
                            size: 24,
                            color: isLink ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLink ? 'ลิงก์ภายนอก' : 'เอกสารแนบ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isLink ? Colors.green[800] : Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (widget.canEdit)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubItemUploadingPreviewBox(Map<String, String> item) {
    final bool isImage = item['type'] == 'image';
    final String localPath = item['localPath'] ?? '';

    return Container(
      width: 100,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage && localPath.isNotEmpty
                  ? Image.file(
                      File(localPath),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      padding: const EdgeInsets.all(6),
                      color: const Color(0xFFFEF2F2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.insert_drive_file_rounded,
                            size: 24,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['name'] ?? 'กำลังอัปโหลด',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadSubItemFileInBackground(File uploadFile, String filename, String localPathKey) async {
    try {
      final uploadedUrl = await widget.service.uploadImage(uploadFile);
      if (mounted) {
        setState(() {
          _uploadingFiles.removeWhere((item) => item['path'] == localPathKey);
          final existing = _getAttachmentUrls();
          existing.add(uploadedUrl);
          _attachmentUrlController.text = existing.join(',');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingFiles.removeWhere((item) => item['path'] == localPathKey);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปโหลดไฟล์ $filename ล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickFileOrImageCombined() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      int tempCount = 0;
      for (var fileItem in result.files) {
        if (fileItem.path == null) continue;
        File file = File(fileItem.path!);
        final filename = fileItem.name;
        final localPathKey = 'local_${DateTime.now().millisecondsSinceEpoch}_${tempCount++}';

        setState(() {
          _uploadingFiles.add({
            'path': localPathKey,
            'localPath': file.path,
            'name': filename,
            'type': (filename.toLowerCase().endsWith('.jpg') || filename.toLowerCase().endsWith('.jpeg') || filename.toLowerCase().endsWith('.png') || filename.toLowerCase().endsWith('.webp')) ? 'image' : 'file',
          });
        });

        // Trigger background upload
        _uploadSubItemFileInBackground(file, filename, localPathKey);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เลือกไฟล์ล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDetail() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกหัวข้อรายการย่อย'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final linkUrl = _linkUrlController.text.trim();
      final attachmentUrl = _attachmentUrlController.text.trim();
      final verification = _verificationController.text.trim();
      final adminComment = _adminCommentController.text.trim();

      await widget.service.updateTaskSubItemDetail(
        widget.item.id,
        title: title,
        startDate: _startDate,
        dueDate: _dueDate,
        linkUrl: linkUrl.isNotEmpty ? linkUrl : null,
        attachmentUrl: attachmentUrl.isNotEmpty ? attachmentUrl : null,
        verificationNotes: verification.isNotEmpty ? verification : null,
        adminComment: adminComment.isNotEmpty ? adminComment : null,
      );

      widget.onChanged();

      if (mounted) {
        Navigator.pop(
          context,
          TaskSubItem(
            id: widget.item.id,
            taskId: widget.item.taskId,
            cardId: widget.item.cardId,
            title: title,
            isDone: _currentStatus == 'completed',
            status: _currentStatus,
            sortOrder: widget.item.sortOrder,
            startDate: _startDate,
            dueDate: _dueDate,
            linkUrl: linkUrl.isNotEmpty ? linkUrl : null,
            attachmentUrl: attachmentUrl.isNotEmpty ? attachmentUrl : null,
            verificationNotes: verification.isNotEmpty ? verification : null,
            adminComment: adminComment.isNotEmpty ? adminComment : null,
            verifications: _verifications,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกรายละเอียดล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdminOrHr = widget.service.currentUser?.role == 'admin' || widget.service.currentUser?.role == 'hr';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: workText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('การดำเนินการรายการย่อย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: workText)),
        centerTitle: true,
        actions: [
          // Plus Action menu (+ ...)
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline_rounded, color: workBlue),
            onSelected: (action) {
              if (action == 'pick_image') {
                _pickFileOrImage(true);
              } else if (action == 'pick_pdf') {
                _pickFileOrImage(false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pick_image',
                child: Row(
                  children: [
                    Icon(Icons.image_rounded, color: workBlue, size: 18),
                    SizedBox(width: 8),
                    Text('เลือกรูปภาพ (บีบอัด WebP)', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pick_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: workBlue, size: 18),
                    SizedBox(width: 8),
                    Text('เลือกไฟล์ PDF', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          // Delete SubItem Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: const Text('ลบรายการย่อย', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Text('คุณต้องการลบรายการย่อย "${widget.item.title}" หรือไม่?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: workMuted))),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ลบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                setState(() => _saving = true);
                try {
                  await widget.service.deleteTaskSubItem(widget.item.id);
                  widget.onChanged();
                  if (mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close detail sheet with empty update
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ลบรายการย่อยล้มเหลว: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            tooltip: 'ลบรายการย่อย',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('หัวข้อรายการย่อย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'พิมพ์หัวข้อรายการย่อย...',
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('วันที่เริ่มต้น', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickStartDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: workMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _startDate != null ? _formatThaiDate(_startDate!) : 'เลือกวันที่เริ่ม',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _startDate != null ? workText : workMuted,
                                      ),
                                    ),
                                  ),
                                  if (_startDate != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _startDate = null;
                                        });
                                      },
                                      child: const Icon(Icons.clear_rounded, size: 16, color: workMuted),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('วันครบกำหนด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickDueDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 16, color: workMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _dueDate != null ? _formatThaiDate(_dueDate!) : 'เลือกวันกำหนดส่ง',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _dueDate != null ? workText : workMuted,
                                      ),
                                    ),
                                  ),
                                  if (_dueDate != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _dueDate = null;
                                        });
                                      },
                                      child: const Icon(Icons.clear_rounded, size: 16, color: workMuted),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── แนบหลักฐาน Section ───
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: workBlue, size: 18),
                    const SizedBox(width: 6),
                    const Text('แนบหลักฐาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText)),
                  ],
                ),
                const SizedBox(height: 10),

                // Attached Evidence Preview Card Box (If attached or uploading)
                if (_getAttachmentUrls().isNotEmpty || _getLinkUrls().isNotEmpty || _uploadingFiles.isNotEmpty) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (int i = 0; i < _getAttachmentUrls().length; i++)
                        _buildSubItemEvidencePreviewBox(
                          url: _getAttachmentUrls()[i],
                          isLink: false,
                          onDelete: () {
                            setState(() {
                              final list = _getAttachmentUrls();
                              list.removeAt(i);
                              _attachmentUrlController.text = list.join(',');
                            });
                          },
                        ),
                      for (int i = 0; i < _getLinkUrls().length; i++)
                        _buildSubItemEvidencePreviewBox(
                          url: _getLinkUrls()[i],
                          isLink: true,
                          onDelete: () {
                            setState(() {
                              final list = _getLinkUrls();
                              list.removeAt(i);
                              _linkUrlController.text = list.join(',');
                            });
                          },
                        ),
                      for (int i = 0; i < _uploadingFiles.length; i++)
                        _buildSubItemUploadingPreviewBox(_uploadingFiles[i]),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 1 Row with 3 Action Boxes (แนบไฟล์, แนบลิงก์, ล้างหลักฐาน)
                if (widget.canEdit) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickFileOrImageCombined(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: workBlue.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: workBlue.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.attach_file_rounded, size: 18, color: workBlue),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'แนบไฟล์',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: workBlue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final textController = TextEditingController(text: _linkUrlController.text);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                title: const Text('แนบลิงก์อ้างอิง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                content: TextField(
                                  controller: textController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'https://example.com...',
                                    filled: true,
                                    fillColor: Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(color: workMuted))),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: workBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('ตกลง'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              setState(() {
                                _linkUrlController.text = textController.text.trim();
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.link_rounded, size: 18, color: Colors.green),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'แนบลิงก์',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _attachmentUrlController.clear();
                              _linkUrlController.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ล้างไฟล์แนบแล้ว'), backgroundColor: Colors.orange),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'ล้างหลักฐาน',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                const Text('ข้อกำหนดในการตรวจสอบงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText)),
                const SizedBox(height: 6),
                TextField(
                  controller: _verificationController,
                  enabled: isAdminOrHr,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'กรอกรายละเอียดข้อกำหนดในการตรวจสอบงาน...',
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
                _buildVerificationRoundsSection(),
                _buildSubItemAdminCommentSection(),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveDetail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: workBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubItemAdminCommentSection() {
    final bool isAdminOrHr = widget.service.currentUser?.role == 'admin' || widget.service.currentUser?.role == 'hr';
    final hasComment = widget.item.adminComment != null && widget.item.adminComment!.trim().isNotEmpty;

    if (!isAdminOrHr && !hasComment) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.comment_rounded, size: 16, color: Colors.amber[800]),
            const SizedBox(width: 6),
            Text(
              'ความคิดเห็นจากผู้ดูแล',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber[900]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (isAdminOrHr)
          TextField(
            controller: _adminCommentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'พิมพ์ความคิดเห็นหรือข้อสังเกตของผู้ดูแล...',
              filled: true,
              fillColor: Color(0xFFFFFBEB), // warm amber tint
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Text(
              widget.item.adminComment ?? '',
              style: const TextStyle(fontSize: 13, color: workText, height: 1.4),
            ),
          ),
      ],
    );
  }

  Future<void> _submitInspection() async {
    final notes = _inspectionNotesController.text.trim();
    setState(() => _verifying = true);
    try {
      await widget.service.createSubItemVerification(
        widget.item.id,
        status: _selectedInspectionStatus,
        notes: notes,
      );

      widget.onChanged();

      final verifierName = widget.service.currentUser?.firstName ?? 'ผู้ตรวจสอบ';
      final newV = SubItemVerification(
        id: '',
        subItemId: widget.item.id,
        round: _verifications.length + 1,
        status: _selectedInspectionStatus,
        notes: notes.isNotEmpty ? notes : null,
        verifierName: verifierName,
        createdAt: DateTime.now(),
      );

      setState(() {
        _verifications.insert(0, newV);
        _currentStatus = _selectedInspectionStatus == 'approved' ? 'completed' : 'pending';
        _inspectionNotesController.clear();
        _verifying = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกผลการตรวจสอบสำเร็จ'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกผลการตรวจสอบล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildVerificationRoundsSection() {
    final bool isAdminOrHr = widget.service.currentUser?.role == 'admin' || widget.service.currentUser?.role == 'hr';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.history_rounded, size: 18, color: workText),
            SizedBox(width: 8),
            Text(
              'ประวัติการตรวจสอบงาน',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_verifications.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFF6FF)),
            ),
            child: const Center(
              child: Text(
                'ยังไม่มีประวัติการตรวจสอบของรายการนี้',
                style: TextStyle(color: workMuted, fontSize: 12),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _verifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final v = _verifications[index];
              final isApproved = v.status == 'approved';
              final dateStr = _formatInspectionDate(v.createdAt);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isApproved ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isApproved ? 'ผ่าน' : 'ไม่ผ่าน',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isApproved ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'รอบที่ ${v.round}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: workText),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 10.5, color: workMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: workMuted),
                        const SizedBox(width: 4),
                        Text(
                          'ผู้ตรวจ: ${v.verifierName}',
                          style: const TextStyle(fontSize: 11, color: workText, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (v.notes != null && v.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          v.notes!,
                          style: const TextStyle(fontSize: 11.5, color: workText),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

        if (isAdminOrHr) ...[
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.rate_review_rounded, size: 18, color: workText),
              SizedBox(width: 8),
              Text(
                'บันทึกผลการตรวจสอบใหม่',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                      SizedBox(width: 6),
                      Text('ผ่าน'),
                    ],
                  ),
                  selected: _selectedInspectionStatus == 'approved',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedInspectionStatus = 'approved');
                    }
                  },
                  selectedColor: const Color(0xFFDCFCE7),
                  backgroundColor: const Color(0xFFF8FAFC),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedInspectionStatus == 'approved' ? Colors.green[800] : workMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _selectedInspectionStatus == 'approved' ? Colors.green : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Text('ไม่ผ่าน'),
                    ],
                  ),
                  selected: _selectedInspectionStatus == 'rejected',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedInspectionStatus = 'rejected');
                    }
                  },
                  selectedColor: const Color(0xFFFEE2E2),
                  backgroundColor: const Color(0xFFF8FAFC),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedInspectionStatus == 'rejected' ? Colors.red[800] : workMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _selectedInspectionStatus == 'rejected' ? Colors.red : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _inspectionNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'ระบุคำอธิบายหรือเหตุผลการตรวจสอบรอบนี้...',
              filled: true,
              fillColor: Color(0xFFF8FAFC),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: _verifying ? null : _submitInspection,
              style: OutlinedButton.styleFrom(
                foregroundColor: workBlue,
                side: const BorderSide(color: workBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _verifying ? 'กำลังบันทึกผล...' : 'บันทึกผลการตรวจสอบรอบนี้',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatInspectionDate(DateTime dt) {
    final thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    return '${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year + 543} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
  }
}

// ─── Thai Date Formatter Helper ────────────────────────────────────
String _formatThaiDate(DateTime? date) {
  if (date == null) return '';
  final months = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
}

class _TiltingDragCard extends StatelessWidget {
  const _TiltingDragCard({
    required this.dragXNotifier,
    required this.child,
  });

  final ValueNotifier<double> dragXNotifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<double>(
      valueListenable: dragXNotifier,
      builder: (context, dragX, _) {
        final normX = ((dragX - (screenWidth / 2)) / (screenWidth / 2)).clamp(-1.0, 1.0);
        // Left side (normX < 0) tilts right (+0.20 rad = ~11.5 deg)
        // Right side (normX > 0) tilts left (-0.20 rad = ~-11.5 deg)
        final angle = -normX * 0.20;

        return Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: 1.06,
            child: Container(
              width: screenWidth * 0.80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x35000000), blurRadius: 20, offset: Offset(0, 10)),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

String resolveFullR2Url(String? url, String baseUrl) {
  if (url == null) return '';
  var trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('r2://')) {
    return trimmed.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/');
  }
  if (trimmed.startsWith('okpr2://')) {
    return trimmed.replaceFirst('okpr2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/');
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('/')) {
    return '$baseUrl$trimmed';
  }
  return '$baseUrl/$trimmed';
}
