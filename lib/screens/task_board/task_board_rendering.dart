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
                      backgroundImage:
                          hasAvatar ? NetworkImage(avatarUrl) : null,
                      onBackgroundImageError:
                          hasAvatar ? (error, stack) {} : null,
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
    final dateLabel = _formatDateRange(card.startDate, card.dueDate);
    final dateColor = _deadlineColor(card.dueDate, isCompleted: isCompleted);
    final badgeBg = _statusBgColors[card.status] ?? const Color(0xFFF1F5F9);
    final badgeText = _statusTextColors[card.status] ?? workMuted;
    final badgeLabel = _statusLabels[card.status] ?? 'รอทำ';

    return InkWell(
      onTap: () => _showCardDetailSheet(card),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: _isCompactMode
            ? const EdgeInsets.fromLTRB(8, 6, 5, 6)
            : const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFFBBF7D0)
                : const Color(0xFFF1F5F9),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tick checkbox — touch target 44×44 ตาม WCAG
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
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 0),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
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
                            fontSize: _isCompactMode ? 11.5 : 12.5,
                            color: isCompleted
                                ? const Color(0xFF6B7280)
                                : workText,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: PriorityBadge(
                          priority: card.priority,
                          isCompact: true,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isCompactMode && card.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      card.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: workMuted, fontSize: 10.5),
                    ),
                  ],
                  if (card.startDate != null ||
                      card.dueDate != null ||
                      card.assignees.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (card.startDate != null || card.dueDate != null) ...[
                          Icon(
                            dateColor == workMuted
                                ? Icons.calendar_today_outlined
                                : Icons.schedule_rounded,
                            size: 10.5,
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
                        ] else ...[
                          const Spacer(),
                        ],
                        if (card.assignees.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _buildAssigneeAvatars(card.assignees),
                        ],
                      ],
                    ),
                  ],
                  if (card.subItems.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(left: 7),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          for (final subItem in card.subItems.take(2))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    subItem.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 10,
                                    color: subItem.isDone
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      subItem.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: subItem.isDone
                                            ? workMuted
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '+${card.subItems.length - 2} รายการย่อย',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: workMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (totalCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.playlist_add_check_rounded,
                              size: 12,
                              color: workBlue,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'ความคืบหน้า',
                              style: TextStyle(
                                fontSize: 10,
                                color: workMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: workBlue,
                            fontWeight: FontWeight.bold,
                          ),
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
