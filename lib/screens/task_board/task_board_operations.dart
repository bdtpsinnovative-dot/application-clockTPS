part of '../task_board_page.dart';

extension _TaskBoardOperations on _TaskBoardPageState {
  Future<void> _loadBoard() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.service.getTrelloBoard(widget.task.id),
        widget.service.getTaskMembers(widget.task.id),
      ]);
      final boardLists = results[0] as List<TaskListRecord>;
      final members = results[1] as List<UserSummary>;

      if (mounted) {
        // ลำดับจากผู้ใช้เป็น source of truth เพื่อให้การลากเรียงคงอยู่หลังรีโหลด
        for (var list in boardLists) {
          list.cards.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }

        setState(() {
          _lists = boardLists;
          _members = members;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('โหลดข้อมูลบอร์ดล้มเหลว: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // เรียงลำดับการ์ดใหม่ภายในคอลัมน์เดียวกัน
  // onReorderItem ปรับ newIndex ให้อัตโนมัติแล้ว (ไม่ต้องลบ 1 เอง)
  Future<void> _toggleListCompleted(TaskListRecord list) async {
    if (_updatingListIds.contains(list.id)) return;

    final nextStatus = list.status == 'completed' ? 'pending' : 'completed';
    setState(() => _updatingListIds.add(list.id));
    try {
      await widget.service.updateTaskList(list.id, status: nextStatus);
      await _loadBoard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปเดตสถานะงานไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _updatingListIds.remove(list.id));
    }
  }

  Future<void> _reorderCards(
    TaskListRecord list,
    int oldIndex,
    int newIndex,
  ) async {
    final listIdx = _lists.indexWhere((l) => l.id == list.id);
    if (listIdx == -1) return;

    // Optimistic update
    final movedCard = _lists[listIdx].cards.removeAt(oldIndex);
    setState(() {
      _lists[listIdx].cards.insert(newIndex, movedCard);
    });

    // Persist sort order to backend
    try {
      for (int i = 0; i < _lists[listIdx].cards.length; i++) {
        await widget.service.updateTaskCard(
          _lists[listIdx].cards[i].id,
          sortOrder: i,
        );
      }
    } catch (e) {
      // Rollback: reload board
      if (mounted) {
        _loadBoard();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เรียงลำดับการ์ดล้มเหลว: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
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
          SnackBar(
            content: Text('สลับตำแหน่งรายการล้มเหลว: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Create new List (คอลัมน์)
  Future<void> _createNewList() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDueDate;
    String selectedPriority = 'medium';
    String selectedStatus = 'todo';
    List<UserSummary> selectedAssignees = [];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: workBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'เพิ่มงานย่อยใหม่',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: workText,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: workMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    
                    // Form Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ชื่องานย่อย *
                            const Row(
                              children: [
                                Text(
                                  'ชื่องานย่อย',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: workText,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  ' *',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: titleController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'เช่น ออกแบบหน้าเว็บ...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: workBlue, width: 1.5),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13, color: workText),
                            ),
                            const SizedBox(height: 20),

                            // รายละเอียดงานย่อย
                            const Text(
                              'รายละเอียดงานย่อย',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: workText,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'รายละเอียดเพิ่มเติมของงานย่อย...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: workBlue, width: 1.5),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13, color: workText),
                            ),
                            const SizedBox(height: 20),

                            // Row of 3 Fields: Date, Priority, Status
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // วันที่กำหนดส่ง
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'วันที่กำหนดส่ง',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: workText,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: selectedDueDate ?? DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2030),
                                          );
                                          if (picked != null) {
                                            setModalState(() {
                                              selectedDueDate = picked;
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  selectedDueDate != null
                                                      ? _formatDate(selectedDueDate)
                                                      : 'วว/ดด/ปปปป',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: selectedDueDate != null
                                                        ? workText
                                                        : const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.calendar_today_rounded,
                                                size: 14,
                                                color: Color(0xFF64748B),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // ความสำคัญ
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ความสำคัญ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: workText,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: selectedPriority,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                            style: const TextStyle(fontSize: 12, color: workText),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'low',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.blue),
                                                    SizedBox(width: 4),
                                                    Text('ต่ำ'),
                                                  ],
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'medium',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.remove_rounded, size: 14, color: Colors.amber),
                                                    SizedBox(width: 4),
                                                    Text('ปานกลาง'),
                                                  ],
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'high',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.flash_on_rounded, size: 14, color: Colors.orange),
                                                    SizedBox(width: 4),
                                                    Text('ด่วน'),
                                                  ],
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'urgent',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.report_problem_rounded, size: 14, color: Colors.red),
                                                    SizedBox(width: 4),
                                                    Text('ด่วนที่สุด'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setModalState(() {
                                                  selectedPriority = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // สถานะ
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'สถานะ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: workText,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: selectedStatus,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                            style: const TextStyle(fontSize: 12, color: workText),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'todo',
                                                child: Text('รอรับ'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'in_progress',
                                                child: Text('กำลังทำ'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'completed',
                                                child: Text('เสร็จสิ้น'),
                                              ),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setModalState(() {
                                                  selectedStatus = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // มอบหมายให้
                            const Text(
                              'มอบหมายให้',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: workText,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ...selectedAssignees.map((user) {
                                  final initials = user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?';
                                  return InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        selectedAssignees.removeWhere((u) => u.id == user.id);
                                      });
                                    },
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: workBlue,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                // Plus dashed button
                                InkWell(
                                  onTap: () async {
                                    // Show user list picker dialog
                                    await showDialog<void>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          title: const Text(
                                            'เลือกผู้รับผิดชอบ',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Container(
                                            width: double.maxFinite,
                                            constraints: BoxConstraints(
                                              maxHeight: MediaQuery.of(context).size.height * 0.4,
                                            ),
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: _members.length,
                                              itemBuilder: (context, idx) {
                                                final member = _members[idx];
                                                final isSelected = selectedAssignees.any((u) => u.id == member.id);
                                                return CheckboxListTile(
                                                  value: isSelected,
                                                  title: Text(member.displayName),
                                                  activeColor: workBlue,
                                                  onChanged: (checked) {
                                                    setModalState(() {
                                                      if (checked == true) {
                                                        if (!selectedAssignees.any((u) => u.id == member.id)) {
                                                          selectedAssignees.add(member);
                                                        }
                                                      } else {
                                                        selectedAssignees.removeWhere((u) => u.id == member.id);
                                                      }
                                                    });
                                                    Navigator.pop(context);
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    
                    // Footer Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'ยกเลิก',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final name = titleController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('กรุณากรอกชื่องานย่อย'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              
                              Navigator.pop(context); // Close sheet
                              
                              setState(() => _loading = true);
                              try {
                                await widget.service.createTaskList(
                                  widget.task.id,
                                  name: name,
                                  description: descController.text.trim(),
                                  priority: selectedPriority,
                                  status: selectedStatus,
                                  dueDate: selectedDueDate,
                                  assigneeIds: selectedAssignees.map((u) => u.id).toList(),
                                );
                                widget.onRefreshNeeded();
                                _loadBoard();
                              } catch (e) {
                                setState(() => _loading = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('เพิ่มรายการล้มเหลว: $e'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: const Text(
                              'บันทึก',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: workBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Create Card inside List
  Future<void> _createNewCard(String listId) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? dueDate;
    String priority = 'medium';
    List<UserSummary> selectedAssignees = [];
    List<UserSummary> allMembers = [];
    bool loadingMembers = true;

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
          final dueDateIsPast = dueDate != null && isWorkDatePast(dueDate!);
          if (loadingMembers) {
            loadingMembers = false;
            widget.service
                .getTaskMembers(widget.task.id)
                .then((members) {
                  setDlgState(() {
                    allMembers = members;
                  });
                })
                .catchError((_) {});
          }
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: workText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ชื่องานของการ์ด',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: workText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'เช่น ทำหน้าชำระเงิน',
                      hintStyle: const TextStyle(
                        color: workMuted,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: workBlue,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'รายละเอียด (ไม่จำเป็นต้องใส่ก็ได้)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: workText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'คำอธิบายงานเพิ่มเติม...',
                      hintStyle: const TextStyle(
                        color: workMuted,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: workBlue,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ความสำคัญ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
                  const Text(
                    'ผู้รับผิดชอบ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: workText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (allMembers.isEmpty)
                    const Text(
                      'กำลังโหลดสมาชิก...',
                      style: TextStyle(fontSize: 12, color: workMuted),
                    )
                  else
                    SizedBox(
                      height: 56,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allMembers.length,
                        itemBuilder: (context, index) {
                          final member = allMembers[index];
                          final isSelected = selectedAssignees.any(
                            (m) => m.id == member.id,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Tooltip(
                              message: member.fullName,
                              child: GestureDetector(
                                onTap: () {
                                  setDlgState(() {
                                    if (isSelected) {
                                      selectedAssignees.removeWhere(
                                        (m) => m.id == member.id,
                                      );
                                    } else {
                                      selectedAssignees.add(member);
                                    }
                                  });
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? workBlue
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundImage:
                                            member.avatarUrl != null &&
                                                member.avatarUrl!.isNotEmpty
                                            ? NetworkImage(member.avatarUrl!)
                                            : null,
                                        child:
                                            member.avatarUrl == null ||
                                                member.avatarUrl!.isEmpty
                                            ? Text(
                                                member.firstName.isNotEmpty
                                                    ? member.firstName[0]
                                                    : '?',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: workBlue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
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
                                  Icons.date_range_rounded,
                                  size: 16,
                                  color: workBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'วันที่เริ่ม',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: workMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        startDate != null
                                            ? _formatDate(startDate)
                                            : 'เลือกวันเริ่ม',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: startDate != null
                                              ? workText
                                              : workMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                            final picked = await showWorkDueDatePicker(
                              context,
                              initialDate: dueDate,
                            );
                            if (picked != null) {
                              setDlgState(() => dueDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: dueDateIsPast
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.alarm_rounded,
                                  size: 16,
                                  color: dueDateIsPast
                                      ? const Color(0xFFDC2626)
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'วันสิ้นสุด',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: dueDateIsPast
                                              ? const Color(0xFFDC2626)
                                              : workMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dueDate != null
                                            ? _formatDate(dueDate)
                                            : 'เลือกกำหนดส่ง',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: dueDateIsPast
                                              ? const Color(0xFFDC2626)
                                              : dueDate != null
                                              ? workText
                                              : workMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                  if (dueDateIsPast) ...[
                    const SizedBox(height: 7),
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFDC2626),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'วันที่สิ้นสุดผ่านมาแล้ว แต่ยังสร้างการ์ดได้',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'สร้างการ์ด',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
          priority: priority,
          startDate: startDate,
          dueDate: dueDate,
          assigneeIds: selectedAssignees.map((m) => m.id).toList(),
        );
        widget.onRefreshNeeded();
        _loadBoard();
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('สร้างการ์ดล้มเหลว: $e'),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // Show Card Details & Checklists Bottom Sheet
  void _showCardDetailSheet(TaskCardRecord card) {
    final user = widget.service.currentUser;
    var listName = 'รายการงาน';
    for (final list in _lists) {
      if (list.id == card.listId) {
        listName = list.name;
        break;
      }
    }
    final bool canEdit =
        (user?.role == 'admin') ||
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
        listName: listName,
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
}
