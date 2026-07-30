part of '../task_board_page.dart';

class _CardDetailSheet extends StatefulWidget {
  const _CardDetailSheet({
    required this.taskId,
    required this.listName,
    required this.card,
    required this.service,
    required this.canEdit,
    required this.onChanged,
  });

  final String taskId;
  final String listName;
  final TaskCardRecord card;
  final AuthFlowService service;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  State<_CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<_CardDetailSheet> {
  late String _cardTitle;
  int _selectedTab = 0;
  final ScrollController _detailScrollController = ScrollController();
  late List<TaskSubItem> _subItems;
  late List<CardAttachment> _attachments;
  late String _currentStatus;
  bool _saving = false;
  final _subItemController = TextEditingController();

  final List<String> _statusKeys = ['pending', 'in_progress', 'completed'];
  final List<String> _statusLabels = ['รอทำ', 'กำลังทำ', 'เสร็จสิ้น'];
  final List<Color> _statusColors = [
    const Color(0xFF64748B),
    const Color(0xFFEA580C),
    const Color(0xFF10B981),
  ];

  bool _loadingCard = false;

  @override
  void initState() {
    super.initState();
    _cardTitle = widget.card.title;
    _subItems = List.from(widget.card.subItems);
    _attachments = List.from(widget.card.attachments);
    _currentStatus = widget.card.status;

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
          _cardTitle = updatedCard!.title;
          _subItems = List.from(updatedCard.subItems);
          _attachments = List.from(updatedCard.attachments);
          _currentStatus = updatedCard.status;
        });
      }
    } catch (e) {
      debugPrint('Error auto-refreshing card detail: $e');
    }
  }

  @override
  void dispose() {
    _detailScrollController.dispose();
    _subItemController.dispose();
    super.dispose();
  }

  Future<void> _updateCardStatus(String status) async {
    setState(() {
      _currentStatus = status;
      _saving = true;
    });

    try {
      await widget.service.updateTaskCard(widget.card.id, status: status);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปลี่ยนสถานะการ์ดล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text('อัปเดตความคืบหน้าล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
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
      final newItem = await widget.service.createCardSubItem(
        widget.card.id,
        title,
      );
      setState(() {
        _subItems.add(newItem);
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เพิ่มรายการย่อยล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCard() async {
    final titleController = TextEditingController(text: _cardTitle);
    final descController = TextEditingController(text: widget.card.description);
    DateTime? startDate = widget.card.startDate;
    DateTime? dueDate = widget.card.dueDate;
    String priority = widget.card.priority;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: workBlue, size: 22),
              SizedBox(width: 8),
              Text(
                'แก้ไขข้อมูลการ์ด',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: workText,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ชื่องาน',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: workText,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 13.5, color: workText),
                  decoration: InputDecoration(
                    hintText: 'กรอกชื่องาน...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                const Text(
                  'รายละเอียด',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: workText,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13.5, color: workText),
                  decoration: InputDecoration(
                    hintText: 'กรอกรายละเอียดเพิ่มเติม...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                const Text(
                  'ความสำคัญ',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: workText,
                  ),
                ),
                const SizedBox(height: 6),
                PrioritySelector(
                  selectedPriority: priority,
                  onChanged: (val) {
                    setDlgState(() => priority = val);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'วันที่เริ่ม',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: workText,
                            ),
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: workMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      startDate != null
                                          ? _formatDate(startDate)
                                          : 'เลือกวันเริ่ม',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: startDate != null
                                            ? workText
                                            : workMuted,
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
                          const Text(
                            'วันสิ้นสุด',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: workText,
                            ),
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 14,
                                    color: workMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dueDate != null
                                          ? _formatDate(dueDate)
                                          : 'เลือกวันส่ง',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: dueDate != null
                                            ? workText
                                            : workMuted,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                if (_hasInvalidDateRange(startDate, dueDate)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('วันสิ้นสุดต้องไม่อยู่ก่อนวันที่เริ่ม'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: workBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              child: const Text(
                'บันทึก',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
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
          priority: priority,
        );
        widget.onChanged();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('แก้ไขการ์ดล้มเหลว: $e'),
              backgroundColor: Colors.red,
            ),
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Navigation / Action Bar (ชิดซ้ายเป็นระเบียบเรียบร้อย)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Left side: Back Button
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: workText,
                      ),
                      tooltip: 'ย้อนกลับ',
                    ),
                    // List > Card hierarchy
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.listName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: workMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 13,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                              const Text(
                                'การ์ด',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: workBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _cardTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: workText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right side: Action Menu Buttons (+ and ...)
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: workBlue),
                      tooltip: 'เพิ่มรายการย่อย',
                      onPressed: () async {
                        final textController = TextEditingController();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            title: const Text(
                              'เพิ่มรายการย่อยใหม่',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            content: TextField(
                              controller: textController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'พิมพ์หัวข้อรายการย่อย...',
                                filled: true,
                                fillColor: Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'ยกเลิก',
                                  style: TextStyle(color: workMuted),
                                ),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('เพิ่ม'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true &&
                            textController.text.trim().isNotEmpty) {
                          setState(() => _saving = true);
                          try {
                            final newItem = await widget.service
                                .createCardSubItem(
                                  widget.card.id,
                                  textController.text.trim(),
                                );
                            setState(() {
                              _subItems.add(newItem);
                            });
                            widget.onChanged();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('เพิ่มรายการย่อยล้มเหลว: $e'),
                                  backgroundColor: Colors.red,
                                ),
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
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: workMuted,
                      ),
                      onSelected: (action) async {
                        if (action == 'edit_card') {
                          _editCard();
                        } else if (action == 'delete_card') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: const Text(
                                'ลบการ์ด',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              content: Text(
                                'คุณต้องการลบการ์ด "$_cardTitle" หรือไม่?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    'ยกเลิก',
                                    style: TextStyle(color: workMuted),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'ลบ',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await widget.service.deleteTaskCard(
                                widget.card.id,
                              );
                              widget.onChanged();
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('ลบการ์ดล้มเหลว: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        } else if (action.startsWith('status_')) {
                          final newStatus = action.substring(
                            7,
                          ); // Extract "todo", "doing", "done"
                          _updateCardStatus(newStatus);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit_card',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                color: workBlue,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'แก้ไขการ์ด',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete_card',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
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
                              Icon(
                                Icons.circle_rounded,
                                color: _statusColors[0],
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ย้ายไป "รอทำ"',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'status_doing',
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle_rounded,
                                color: _statusColors[1],
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ย้ายไป "กำลังทำ"',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'status_done',
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle_rounded,
                                color: _statusColors[2],
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ย้ายไป "เสร็จสิ้น"',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ─── 2-Tab Segmented Switcher (รายละเอียด vs กิจกรรม/คอมเมนต์) ───
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 0),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 0
                                ? const [
                                    BoxShadow(
                                      color: Color(0x0C0F172A),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 14,
                                color: _selectedTab == 0 ? workBlue : workMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'รายละเอียดงาน',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedTab == 0
                                      ? workBlue
                                      : workMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 1
                                ? const [
                                    BoxShadow(
                                      color: Color(0x0C0F172A),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 14,
                                color: _selectedTab == 1 ? workBlue : workMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'กิจกรรม & คอมเมนต์',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedTab == 1
                                      ? workBlue
                                      : workMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Scrollable content area
              Expanded(
                child: _selectedTab == 0
                    ? SingleChildScrollView(
                        controller: _detailScrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. รายละเอียดการ์ดงาน (Card Details - Top Section)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.subject_rounded,
                                  color: workBlue,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _cardTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: workText,
                                    ),
                                  ),
                                ),
                                 Padding(
                                   padding: const EdgeInsets.only(left: 8),
                                   child: PriorityBadge(
                                     priority: widget.card.priority,
                                   ),
                                 ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.card.description.isNotEmpty
                                        ? widget.card.description
                                        : 'ไม่มีรายละเอียดคำอธิบาย',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: widget.card.description.isNotEmpty
                                          ? workText
                                          : workMuted,
                                      height: 1.4,
                                      fontStyle:
                                          widget.card.description.isNotEmpty
                                          ? FontStyle.normal
                                          : FontStyle.italic,
                                    ),
                                  ),
                                  if (widget.card.startDate != null ||
                                      widget.card.dueDate != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFF1F5F9),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (widget.card.startDate != null)
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'วันที่เริ่ม',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      color: workMuted,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatDate(
                                                      widget.card.startDate,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: workText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (widget.card.startDate != null &&
                                              widget.card.dueDate != null)
                                            Container(
                                              width: 1,
                                              height: 30,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          if (widget.card.dueDate != null)
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'วันที่สิ้นสุด',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      color: workMuted,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatDate(
                                                      widget.card.dueDate,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: _deadlineColor(
                                                        widget.card.dueDate,
                                                        isCompleted:
                                                            widget
                                                                .card
                                                                .status ==
                                                            'completed',
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 2. ผู้รับผิดชอบ (Assignees)
                            const Text(
                              'ผู้รับผิดชอบการ์ดงาน',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: workText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            CardAssigneePicker(
                              service: widget.service,
                              taskId: widget.taskId,
                              cardId: widget.card.id,
                              initialAssigneeIds: widget.card.assigneeIds,
                              initialAssignees: widget.card.assignees,
                              isReadOnly: !widget.canEdit,
                              onAssigneesChanged: (ids, assignees) {
                                widget.card.assigneeIds = ids;
                                widget.card.assignees = assignees;
                                widget.onChanged();
                              },
                            ),
                            const SizedBox(height: 24),

                            // 3. รายการย่อย (Checklist)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.account_tree_outlined,
                                  color: workBlue,
                                  size: 19,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'รายการย่อยของ “$_cardTitle”',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: workText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${widget.listName} › $_cardTitle',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: workMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (totalCount == 0)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'ไม่มีรายการย่อยในการ์ดนี้',
                                    style: TextStyle(
                                      color: workMuted,
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
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
                                  final hasDetails =
                                      item.startDate != null ||
                                      item.dueDate != null ||
                                      (item.linkUrl != null &&
                                          item.linkUrl!.isNotEmpty) ||
                                      (item.attachmentUrl != null &&
                                          item.attachmentUrl!.isNotEmpty) ||
                                      (item.verificationNotes != null &&
                                          item.verificationNotes!.isNotEmpty);

                                  return Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFF1F5F9),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: item.isDone,
                                          activeColor: workBlue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          onChanged: (_) =>
                                              _toggleSubItem(item, i),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () =>
                                                _showSubItemDetailSheet(
                                                  item,
                                                  i,
                                                ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 4,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          item.title,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: item.isDone
                                                                ? workMuted
                                                                : workText,
                                                            decoration:
                                                                item.isDone
                                                                ? TextDecoration
                                                                      .lineThrough
                                                                : null,
                                                          ),
                                                        ),
                                                        if (hasDetails) ...[
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          Wrap(
                                                            spacing: 6,
                                                            runSpacing: 2,
                                                            children: [
                                                              if (item.startDate !=
                                                                      null ||
                                                                  item.dueDate !=
                                                                      null)
                                                                Text(
                                                                  '${item.startDate != null ? _formatThaiDate(item.startDate) : 'เริ่ม'} - ${item.dueDate != null ? _formatThaiDate(item.dueDate) : 'กำหนด'}',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        9.5,
                                                                    color:
                                                                        workMuted,
                                                                  ),
                                                                ),
                                                              if (item.linkUrl !=
                                                                      null &&
                                                                  item
                                                                      .linkUrl!
                                                                      .isNotEmpty)
                                                                const Text(
                                                                  '• ลิงก์',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        9.5,
                                                                    color:
                                                                        workBlue,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              if (item.attachmentUrl !=
                                                                      null &&
                                                                  item
                                                                      .attachmentUrl!
                                                                      .isNotEmpty)
                                                                const Text(
                                                                  '• ไฟล์แนบ',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        9.5,
                                                                    color:
                                                                        workMuted,
                                                                  ),
                                                                ),
                                                              if (item.verificationNotes !=
                                                                      null &&
                                                                  item
                                                                      .verificationNotes!
                                                                      .isNotEmpty)
                                                                const Text(
                                                                  '• ตรวจสอบแล้ว',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        9.5,
                                                                    color: Colors
                                                                        .green,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: workMuted,
                                                    size: 20,
                                                  ),
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
                            const SizedBox(height: 24),

                            // 4. หลักฐานและไฟล์แนบ (Attachments Section)
                            Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  color: workBlue,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'หลักฐานและไฟล์แนบ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: workText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_attachments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(left: 24, bottom: 10),
                                child: Text(
                                  'ไม่มีไฟล์แนบในขณะนี้',
                                  style: TextStyle(
                                    color: workMuted,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else ...[
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (
                                    int idx = 0;
                                    idx < _attachments.length;
                                    idx++
                                  )
                                    _buildAttachmentBox(_attachments[idx], idx),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (widget.canEdit) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionBoxCard(
                                      icon: Icons.attach_file_rounded,
                                      label: 'แนบไฟล์',
                                      color: workBlue,
                                      onTap: () =>
                                          _uploadEvidenceFileCombined(),
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
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CardCommentSection(
                          service: widget.service,
                          cardId: widget.card.id,
                          taskId: widget.taskId,
                          isReadOnly: !widget.canEdit,
                        ),
                      ),
              ),
            ],
          ),
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
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
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
                    SnackBar(
                      content: Text('URL: $fullUrl'),
                      backgroundColor: workBlue,
                    ),
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
                          ? Image.file(File(attachment.url), fit: BoxFit.cover)
                          : Image.network(
                              fullUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: workMuted,
                                ),
                              ),
                            ))
                    : Container(
                        padding: const EdgeInsets.all(8),
                        color: isLink
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFEF2F2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isLink
                                  ? Icons.link_rounded
                                  : Icons.insert_drive_file_rounded,
                              size: 28,
                              color: isLink ? Colors.green : Colors.redAccent,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attachment.name.isEmpty
                                  ? attachment.url
                                  : attachment.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isLink
                                    ? Colors.green[800]
                                    : Colors.red[800],
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (widget.canEdit &&
              !isTemp &&
              (user?.role == 'admin' ||
                  attachment.createdBy == user?.id ||
                  attachment.createdBy == null))
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
                        SnackBar(
                          content: Text('ลบหลักฐานล้มเหลว: $e'),
                          backgroundColor: Colors.red,
                        ),
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
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadSingleFileInBackground(
    File uploadFile,
    String filename,
    bool isImage,
    String tempId,
  ) async {
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
          final idx = _attachments.indexWhere(
            (element) => element.id == tempId,
          );
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
          SnackBar(
            content: Text('อัปโหลดไฟล์ $filename ล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadEvidenceFileCombined() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'txt',
        ],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        int tempCount = 0;
        for (var fileItem in result.files) {
          if (fileItem.path == null) continue;
          File file = File(fileItem.path!);
          final filename = fileItem.name;
          final lowerName = filename.toLowerCase();

          final bool isImage =
              lowerName.endsWith('.jpg') ||
              lowerName.endsWith('.jpeg') ||
              lowerName.endsWith('.png');
          final String tempId =
              'temp_${DateTime.now().millisecondsSinceEpoch}_${tempCount++}';

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
          SnackBar(
            content: Text('แนบไฟล์ล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
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
        title: const Text(
          'แนบหลักฐานลิงก์ใหม่',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
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
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: linkController,
              decoration: const InputDecoration(
                hintText: 'https://example.com...',
                filled: true,
                fillColor: Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (confirm == true && linkController.text.trim().isNotEmpty) {
      final link = linkController.text.trim();
      final name = titleController.text.trim().isNotEmpty
          ? titleController.text.trim()
          : 'ลิงก์แนบ';
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
            SnackBar(
              content: Text('แนบลิงก์ล้มเหลว: $e'),
              backgroundColor: Colors.red,
            ),
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
        parentCardTitle: _cardTitle,
        listName: widget.listName,
        service: widget.service,
        canEdit: widget.canEdit,
        onChanged: widget.onChanged,
      ),
    );

    await _refreshCardData();
  }
}

// ─── Sub-item Detail Sheet ──────────────────────────────────────────
