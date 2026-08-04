part of '../task_board_page.dart';

extension _TaskBoardRendering on _TaskBoardPageState {
  Future<void> _editListName(TaskListRecord list) async {
    final nameController = TextEditingController(text: list.name);
    final descController = TextEditingController(text: list.description);
    DateTime? startDate = list.startDate;
    DateTime? dueDate = list.dueDate;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'แก้ไขข้อมูลรายการ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
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
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'วันที่เริ่ม',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: workMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                startDate != null
                                    ? _formatDate(startDate)
                                    : 'เลือกวันเริ่ม',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: startDate != null
                                      ? workText
                                      : workMuted,
                                  fontWeight: FontWeight.w500,
                                ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'วันที่สิ้นสุด',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: workMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dueDate != null
                                    ? _formatDate(dueDate)
                                    : 'เลือกวันสิ้นสุด',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dueDate != null ? workText : workMuted,
                                  fontWeight: FontWeight.w500,
                                ),
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
              onPressed: () {
                if (_hasInvalidDateRange(startDate, dueDate)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('วันที่สิ้นสุดต้องไม่อยู่ก่อนวันที่เริ่ม'),
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
            SnackBar(
              content: Text('แก้ไขข้อมูลรายการล้มเหลว: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSingleTaskBoard(List<TaskListRecord> lists) {
    return RefreshIndicator(
      onRefresh: _loadBoard,
      color: workBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          // Custom Board Header styled like the screenshot
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Drag indicator icon
                    const Icon(
                      Icons.drag_indicator_rounded,
                      color: Color(0xFF94A3B8), // slate-400
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    // Board/Project Title
                    Expanded(
                      child: Text(
                        widget.task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: workText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit pencil icon
                    const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF64748B), // slate-500
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress Bar and Percentage Row
                Row(
                  children: [
                    // Progress Bar
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: lists.isNotEmpty
                              ? (lists.where((l) => l.status == 'completed').length / lists.length)
                              : 0.0,
                          backgroundColor: const Color(0xFFE2E8F0), // light slate background
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981), // Emerald green progress fill
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Percentage Text
                    Text(
                      lists.isNotEmpty
                          ? '${((lists.where((l) => l.status == 'completed').length / lists.length) * 100).toInt()}%'
                          : '0%',
                      style: const TextStyle(
                        color: Color(0xFF10B981), // Emerald green text
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (lists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, color: workMuted, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'ยังไม่มีงานในบอร์ดนี้',
                    style: TextStyle(
                      color: workMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < lists.length; index++)
              _buildTaskBoardRow(
                lists[index],
                isLast: index == lists.length - 1,
              ),
        ],
      ),
    );
  }

  Widget _buildTaskBoardRow(TaskListRecord list, {required bool isLast}) {
    final isCompleted = list.status == 'completed';
    final isInProgress = list.status == 'in_progress';
    final isUpdating = _updatingListIds.contains(list.id);

    final dateLabel = _formatDateRange(list.startDate, list.dueDate);
    final dateColor = _deadlineColor(list.dueDate, isCompleted: isCompleted);
    final badgeText = _statusTextColors[list.status] ?? workMuted;
    final badgeLabel = _statusLabels[list.status] ?? 'รอทำ';

    Color cardBg;
    Color cardBorder;
    if (isCompleted) {
      cardBg = const Color(0xFFF0FDF4); // Soft emerald green background
      cardBorder = const Color(0xFFBBF7D0); // Soft emerald green border
    } else if (isInProgress) {
      cardBg = const Color(0xFFFFF7ED); // Soft orange background
      cardBorder = const Color(0xFFFED7AA); // Soft orange border
    } else {
      cardBg = Colors.white; // Clean white background for pending
      cardBorder = const Color(0xFFE2E8F0); // Light slate/grey border
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isUpdating ? null : () => _showTaskDetailModal(list),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cardBorder,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 4,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox on the left
                Semantics(
                  label: isCompleted
                      ? 'ทำเครื่องหมายว่ายังไม่เสร็จ'
                      : 'ทำเครื่องหมายว่าเสร็จแล้ว',
                  button: true,
                  child: GestureDetector(
                    onTap: isUpdating
                        ? null
                        : () => _toggleListCompleted(list),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1, right: 10),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
                // Card Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row of Title and Status text
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              list.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isCompleted
                                    ? const Color(0xFF6B7280) // Muted slate-green
                                    : workText,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isUpdating)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: workBlue,
                              ),
                            )
                          else ...[
                            // Status Text (e.g. เสร็จสิ้น) aligned to the right without container
                            Text(
                              badgeLabel,
                              style: TextStyle(
                                color: badgeText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: workMuted,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      // Date row (only if date is present)
                      if (list.startDate != null || list.dueDate != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: dateColor == workMuted
                                  ? const Color(0xFF94A3B8)
                                  : dateColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: dateColor == workMuted
                                    ? const Color(0xFF64748B)
                                    : dateColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTaskDetailModal(TaskListRecord list) async {
    final isCompleted = list.status == 'completed';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              list.name,
              style: const TextStyle(
                color: workText,
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isCompleted ? const Color(0xFF16A34A) : workMuted,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  isCompleted ? 'เสร็จแล้ว' : 'ยังไม่เสร็จ',
                  style: TextStyle(
                    color: isCompleted ? const Color(0xFF15803D) : workMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (list.description.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'รายละเอียด',
                style: TextStyle(
                  color: workMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                list.description.trim(),
                style: const TextStyle(
                  color: workText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            if (list.dueDate != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: workMuted,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _formatDate(list.dueDate),
                    style: const TextStyle(
                      color: workText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleListCompleted(list);
                },
                icon: Icon(
                  isCompleted
                      ? Icons.undo_rounded
                      : Icons.check_circle_outline_rounded,
                ),
                label: Text(
                  isCompleted
                      ? 'ทำเครื่องหมายว่ายังไม่เสร็จ'
                      : 'ทำเครื่องหมายว่าเสร็จแล้ว',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeaderContent(TaskListRecord list) {
    final totalCards = list.cards.length;
    final doneCards = list.cards.where((c) => c.status == 'completed').length;
    final pct = totalCards == 0 ? 0 : (doneCards / totalCards * 100).toInt();
    final dateLabel = _formatDateRange(list.startDate, list.dueDate);
    final isCompleted = totalCards > 0 && doneCards == totalCards;
    final dateColor = _deadlineColor(list.dueDate, isCompleted: isCompleted);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.drag_indicator_rounded,
                    color: workMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      list.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: workText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (list.description.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    list.description.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      color: workMuted,
                    ),
                  ),
                ),
              ],
              if (dateLabel.isNotEmpty || totalCards > 0) ...[
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      if (dateLabel.isNotEmpty) ...[
                        Icon(
                          list.dueDate != null &&
                                  _deadlineColor(
                                        list.dueDate,
                                        isCompleted: isCompleted,
                                      ) !=
                                      workMuted
                              ? Icons.schedule_rounded
                              : Icons.calendar_today_outlined,
                          size: 11,
                          color: dateColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: dateColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (totalCards > 0)
                        Text(
                          '$doneCards/$totalCards งาน',
                          style: const TextStyle(
                            fontSize: 10,
                            color: workMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
                          color: pct == 100
                              ? const Color(0xFF10B981)
                              : workBlue,
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
          icon: const Icon(
            Icons.mode_edit_outline_rounded,
            color: workMuted,
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildListPage(TaskListRecord list, int listIdx) {
    // เฉพาะรับ TaskListRecord drop สำหรับสลับ Column (ไม่รับ Card ข้ามคอลัมน์)
    return DragTarget<TaskListRecord>(
      onWillAcceptWithDetails: (details) => details.data.id != list.id,
      onAcceptWithDetails: (details) => _swapLists(details.data, list),
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;

        final columnCardWidget = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: _isCompactMode
              ? const EdgeInsets.fromLTRB(3, 6, 3, 4)
              : const EdgeInsets.fromLTRB(5, 8, 5, 6),
          decoration: BoxDecoration(
            color: isOver ? workBlue.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOver ? workBlue : const Color(0xFFF1F5F9),
              width: isOver ? 1.5 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header of list
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isCompactMode ? 9 : 12,
                  vertical: _isCompactMode ? 6 : 8,
                ),
                child: _buildListHeaderContent(list),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Cards inside list
              Expanded(
                child: Builder(
                  builder: (context) {
                    final hasActiveFilters =
                        _cardSearchQuery.isNotEmpty ||
                        _selectedCardStatus != null;
                    final filteredCards = list.cards.where((card) {
                      if (_cardSearchQuery.isNotEmpty) {
                        final query = _cardSearchQuery.toLowerCase();
                        final matchTitle = card.title.toLowerCase().contains(
                          query,
                        );
                        final matchDesc = card.description
                            .toLowerCase()
                            .contains(query);
                        if (!matchTitle && !matchDesc) return false;
                      }
                      if (_selectedCardStatus != null &&
                          card.status != _selectedCardStatus) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (hasActiveFilters) {
                      if (filteredCards.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  size: 28,
                                  color: Color(0xFFCBD5E1),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'ไม่พบการ์ดในหัวข้อนี้',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: workMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: _clearAllBoardFilters,
                                  child: const Text(
                                    'ล้างตัวกรอง',
                                    style: TextStyle(fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          5,
                          6,
                          5,
                          92 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: filteredCards.length,
                        itemBuilder: (context, index) {
                          final card = filteredCards[index];
                          return _buildCardItem(
                            card,
                            listIdx,
                            key: ValueKey(card.id),
                          );
                        },
                      );
                    }

                    return ReorderableListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        5,
                        6,
                        5,
                        92 + MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: list.cards.length,
                      onReorderItem: (oldIndex, newIndex) =>
                          _reorderCards(list, oldIndex, newIndex),
                      proxyDecorator: (child, index, animation) =>
                          AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) => Material(
                              elevation: 4 * animation.value,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: child,
                            ),
                            child: child,
                          ),
                      itemBuilder: (context, index) {
                        final card = list.cards[index];
                        return _buildCardItem(
                          card,
                          listIdx,
                          key: ValueKey(card.id),
                        );
                      },
                      footer: Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: _buildCompactAddCardButton(list.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

        // Calculate 3D tilt angle for background column pages
        double pageTiltAngle = 0.0;
        if (_isDraggingList) {
          if (listIdx < _currentPage) {
            pageTiltAngle = 0.08;
          } else if (listIdx > _currentPage) {
            pageTiltAngle = -0.08;
          }
        }

        final scaledColumn = AnimatedRotation(
          turns: pageTiltAngle / (2 * 3.1415926535),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _isDraggingList ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: columnCardWidget,
          ),
        );

        return LongPressDraggable<TaskListRecord>(
          data: list,
          // 500ms = Flutter standard kLongPressTimeout
          // ไม่มี Card LongPressDraggable แล้ว จึงไม่ต้องตั้ง delay ยาวพิเศษ
          delay: const Duration(milliseconds: 500),
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
              _pageController = PageController(
                initialPage: curPage,
                viewportFraction: _isCompactMode ? 0.64 : 0.75,
              );
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
              _pageController = PageController(
                initialPage: curPage,
                viewportFraction: boardViewportFraction(_isCompactMode),
              );
            });
          },
          child: scaledColumn,
        );
      },
    );
  }

  // การ์ดแต่ละใบ — key สำหรับ ReorderableListView
  Widget _buildCardItem(TaskCardRecord card, int listIdx, {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 6),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: workBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatars(List<UserSummary> assignees) {
    if (assignees.isEmpty) return const SizedBox.shrink();
    final visible = assignees.take(3).toList();
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            Align(
              widthFactor: 0.65,
              child: Builder(
                builder: (context) {
                  final user = visible[i];
                  final avatarUrl = user.resolvedAvatarUrl;
                  final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFFDBEAFE),
                      backgroundImage: hasAvatar
                          ? NetworkImage(avatarUrl)
                          : null,
                      onBackgroundImageError: hasAvatar
                          ? (error, stack) {}
                          : null,
                      child: !hasAvatar
                          ? Text(
                              user.firstName.isNotEmpty
                                  ? user.firstName[0]
                                  : '?',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF1E40AF),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
          if (assignees.length > 3)
            Align(
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text(
                    '+${assignees.length - 3}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardContent(TaskCardRecord card) {
    final doneCount = card.subItems.where((s) => s.isDone).length;
    final totalCount = card.subItems.length;
    final pct = totalCount == 0 ? 0 : (doneCount / totalCount * 100).toInt();

    final isCompleted = card.status == 'completed';
    final isInProgress = card.status == 'in_progress';
    final dateLabel = _formatDateRange(card.startDate, card.dueDate);
    final dateColor = _deadlineColor(card.dueDate, isCompleted: isCompleted);
    final badgeText = _statusTextColors[card.status] ?? workMuted;
    final badgeLabel = _statusLabels[card.status] ?? 'รอทำ';

    Color cardBg;
    Color cardBorder;
    if (isCompleted) {
      cardBg = const Color(0xFFF0FDF4); // Soft emerald green background
      cardBorder = const Color(0xFFBBF7D0); // Soft emerald green border
    } else if (isInProgress) {
      cardBg = const Color(0xFFFFF7ED); // Soft orange background
      cardBorder = const Color(0xFFFED7AA); // Soft orange border
    } else {
      cardBg = Colors.white; // Clean white background for pending
      cardBorder = const Color(0xFFE2E8F0); // Light slate/grey border
    }

    return InkWell(
      onTap: () => _showCardDetailSheet(card),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: _isCompactMode
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorder,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 4,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox on the left
            Semantics(
              label: isCompleted
                  ? 'ทำเครื่องหมายว่ายังไม่เสร็จ'
                  : 'ทำเครื่องหมายว่าเสร็จแล้ว',
              button: true,
              child: GestureDetector(
                onTap: () async {
                  final newStatus = isCompleted ? 'pending' : 'completed';
                  try {
                    await widget.service.updateTaskCard(
                      card.id,
                      status: newStatus,
                    );
                    _loadBoard();
                  } catch (_) {}
                },
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
            // Card Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row of Title and Status text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: _isCompactMode ? 12 : 13.5,
                            color: isCompleted
                                ? const Color(0xFF6B7280) // Muted slate-green
                                : workText,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Text (e.g. เสร็จสิ้น) aligned to the right without container
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Description (if not empty and not compact mode)
                  if (!_isCompactMode && card.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: workMuted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                  // Sub-items checklist (if not empty)
                  if (card.subItems.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFF8FAFC).withValues(alpha: 0.5)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final subItem in card.subItems.take(2))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    subItem.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 11,
                                    color: subItem.isDone
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      subItem.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: subItem.isDone
                                            ? const Color(0xFF94A3B8)
                                            : workText,
                                        decoration: subItem.isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (card.subItems.length > 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, left: 17),
                              child: Text(
                                '+อีก ${card.subItems.length - 2} รายการย่อย',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: workMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // Progress bar (if sub-items exist)
                  if (totalCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.playlist_add_check_rounded,
                          size: 13,
                          color: workBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$doneCount/$totalCount',
                          style: const TextStyle(
                            fontSize: 10,
                            color: workMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: doneCount / totalCount,
                              backgroundColor: const Color(0xFFE2E8F0),
                              color: pct == 100 ? const Color(0xFF10B981) : workBlue,
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 10,
                            color: pct == 100 ? const Color(0xFF10B981) : workBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Date and Assignees row
                  if (card.startDate != null ||
                      card.dueDate != null ||
                      card.assignees.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (card.startDate != null || card.dueDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: dateColor == workMuted
                                    ? const Color(0xFF94A3B8)
                                    : dateColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dateColor == workMuted
                                      ? const Color(0xFF64748B)
                                      : dateColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else
                          const Spacer(),
                        if (card.assignees.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildAssigneeAvatars(card.assignees),
                        ],
                      ],
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
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
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
                child: const Icon(
                  Icons.playlist_add_rounded,
                  size: 36,
                  color: workBlue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'เพิ่มรายการงาน',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: workText,
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'เพิ่มรายการ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    double pageTiltAngle = 0.0;
    if (_isDraggingList) {
      pageTiltAngle = -0.08; // Add list page on right side tilts LEFT
    }

    return AnimatedRotation(
      turns: pageTiltAngle / (2 * 3.1415926535),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: _isDraggingList ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: addWidget,
      ),
    );
  }
}
