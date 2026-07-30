part of '../task_board_page.dart';

extension _TaskBoardFilters on _TaskBoardPageState {
  void _clearAllBoardFilters() {
    setState(() {
      _cardSearchQuery = '';
      _selectedListIds = [];
      _selectedCardStatus = null;
      _cardSearchController.clear();
    });
  }

  void _setCompactMode(bool value) {
    if (_isCompactMode == value) return;
    final previousController = _pageController;
    final targetPage = _currentPage;
    setState(() {
      _isCompactMode = value;
      _pageController = PageController(
        initialPage: targetPage,
        viewportFraction: boardViewportFraction(value),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previousController.dispose();
    });
  }

  void _showBoardFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BoardFilterBottomSheetContent(
        lists: _lists,
        initialSelectedListIds: _selectedListIds,
        initialSelectedStatus: _selectedCardStatus,
        onApply: (listIds, status) {
          setState(() {
            _selectedListIds = listIds;
            _selectedCardStatus = status;
            _currentPage = 0;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });
        },
      ),
    );
  }

  Widget _buildActiveBoardFilter({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.only(left: 7, right: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: workMuted),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 145),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: workText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 12, color: workMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardBottomDock({required int filterCount}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              MediaQuery.paddingOf(context).bottom + 10,
            ),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cardSearchController,
                      onChanged: (value) =>
                          setState(() => _cardSearchQuery = value.trim()),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 13, color: workText),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาการ์ด...',
                        hintStyle: const TextStyle(
                          color: workMuted,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: workMuted,
                          size: 18,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 35,
                        ),
                        suffixIcon: _cardSearchQuery.isEmpty
                            ? null
                            : IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    _cardSearchQuery = '';
                                    _cardSearchController.clear();
                                  });
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: workMuted,
                                ),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(
                            color: Color(0xFFBFDBFE),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  _BoardDockButton(
                    tooltip: filterCount > 0
                        ? 'ตัวกรองที่ใช้ $filterCount รายการ'
                        : 'ตัวกรอง',
                    icon: Icons.tune_rounded,
                    active: filterCount > 0,
                    badge: filterCount > 0 ? '$filterCount' : null,
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _showBoardFilterBottomSheet();
                    },
                  ),
                  const SizedBox(width: 5),
                  _BoardDockButton(
                    tooltip: _isCompactMode
                        ? 'ปิด Compact mode'
                        : 'เปิด Compact mode',
                    icon: _isCompactMode
                        ? Icons.view_week_rounded
                        : Icons.view_column_outlined,
                    active: _isCompactMode,
                    onTap: () => _setCompactMode(!_isCompactMode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
