import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';

class CardAssigneePicker extends StatefulWidget {
  final AuthFlowService service;
  final String taskId;
  final String cardId;
  final List<String> initialAssigneeIds;
  final List<UserSummary> initialAssignees;
  final Function(List<String>, List<UserSummary>) onAssigneesChanged;
  final bool isReadOnly;

  const CardAssigneePicker({
    super.key,
    required this.service,
    required this.taskId,
    required this.cardId,
    required this.initialAssigneeIds,
    required this.initialAssignees,
    required this.onAssigneesChanged,
    this.isReadOnly = false,
  });

  @override
  State<CardAssigneePicker> createState() => _CardAssigneePickerState();
}

class _CardAssigneePickerState extends State<CardAssigneePicker> {
  List<UserSummary> _allMembers = [];
  List<String> _selectedIds = [];
  List<UserSummary> _selectedAssignees = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialAssigneeIds);
    _selectedAssignees = List.from(widget.initialAssignees);
    _loadMembers();
  }

  @override
  void didUpdateWidget(covariant CardAssigneePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAssigneeIds != widget.initialAssigneeIds ||
        oldWidget.initialAssignees != widget.initialAssignees) {
      setState(() {
        _selectedIds = List.from(widget.initialAssigneeIds);
        _selectedAssignees = List.from(widget.initialAssignees);
      });
    }
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.service.getTaskMembers(widget.taskId);
      if (mounted) {
        setState(() {
          _allMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถโหลดรายชื่อสมาชิกได้')),
        );
      }
    }
  }

  Widget _buildUserAvatarWidget(UserSummary user, {double radius = 18}) {
    final avatarUrl = _resolveAvatarUrl(user.avatarUrl);
    final hasAvatar = avatarUrl.isNotEmpty;
    final isSvg = hasAvatar && (avatarUrl.toLowerCase().contains('.svg') || avatarUrl.toLowerCase().contains('/svg'));

    Widget avatarWidget;
    if (hasAvatar) {
      if (isSvg) {
        avatarWidget = SvgPicture.network(
          avatarUrl,
          fit: BoxFit.cover,
          placeholderBuilder: (BuildContext context) => _buildFallbackTextWidget(user, radius),
        );
      } else {
        avatarWidget = Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          errorBuilder: (context, error, stackTrace) => _buildFallbackTextWidget(user, radius),
        );
      }
    } else {
      avatarWidget = _buildFallbackTextWidget(user, radius);
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDBEAFE),
      ),
      child: ClipOval(
        child: avatarWidget,
      ),
    );
  }

  Widget _buildFallbackTextWidget(UserSummary user, double radius) {
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

  void _showPermissionErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'ไม่สามารถแก้ไขได้',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Text(
            errorMsg.contains('403') || errorMsg.contains('สิทธิ์')
                ? 'คุณไม่มีสิทธิ์แก้ไขผู้รับผิดชอบการ์ดงานนี้'
                : 'เกิดข้อผิดพลาดในการอัปเดตผู้รับผิดชอบ: $errorMsg',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateAssignees({
    required List<String> newSelectedIds,
    required List<String> oldSelectedIds,
    required List<UserSummary> oldSelectedAssignees,
    required StateSetter setModalState,
  }) async {
    if (widget.isReadOnly || _isSaving) return;

    setState(() => _isSaving = true);
    setModalState(() {});

    try {
      final updatedList = await widget.service.updateCardAssignees(widget.cardId, newSelectedIds);
      if (mounted) {
        setState(() {
          _selectedIds = updatedList.map((e) => e.id).toList();
          _selectedAssignees = updatedList;
          _isSaving = false;
        });
        setModalState(() {});
        widget.onAssigneesChanged(_selectedIds, _selectedAssignees);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedIds = oldSelectedIds;
          _selectedAssignees = oldSelectedAssignees;
          _isSaving = false;
        });
        setModalState(() {});
        _showPermissionErrorDialog(e.toString());
      }
    }
  }

  void _showPickerModal() {
    if (widget.isReadOnly || _isLoading) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredMembers = _allMembers.where((m) {
              final query = _searchQuery.toLowerCase();
              return m.fullName.toLowerCase().contains(query) ||
                     m.position.toLowerCase().contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return SafeArea(
                  top: false,
                  child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ผู้รับผิดชอบ',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_isSaving) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'ค้นหาชื่อ หรือตำแหน่ง...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = filteredMembers[index];
                          final isSelected = _selectedIds.contains(member.id);

                          return ListTile(
                            enabled: !_isSaving,
                            leading: _buildUserAvatarWidget(member, radius: 18),
                            title: Text(member.displayName),
                            subtitle: Text(member.position, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.blue)
                                : const Icon(Icons.circle_outlined, color: Colors.grey),
                            onTap: _isSaving
                                ? null
                                : () {
                                    final oldIds = List<String>.from(_selectedIds);
                                    final oldAssignees = List<UserSummary>.from(_selectedAssignees);
                                    final newIds = List<String>.from(_selectedIds);
                                    if (isSelected) {
                                      newIds.remove(member.id);
                                    } else {
                                      newIds.add(member.id);
                                    }

                                    setModalState(() {
                                      _selectedIds = newIds;
                                    });

                                    _updateAssignees(
                                      newSelectedIds: newIds,
                                      oldSelectedIds: oldIds,
                                      oldSelectedAssignees: oldAssignees,
                                      setModalState: setModalState,
                                    );
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      },
    ).whenComplete(() {
      setState(() {
        _searchQuery = '';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_selectedAssignees.isEmpty) {
      return GestureDetector(
        onTap: _showPickerModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('ยังไม่มอบหมาย', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showPickerModal,
      child: SizedBox(
        height: 32,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              _selectedAssignees.length > 3 ? 3 : _selectedAssignees.length,
              (index) {
                final assignee = _selectedAssignees[index];
                return Align(
                  widthFactor: 0.7,
                  child: _buildUserAvatarWidget(assignee, radius: 16),
                );
              },
            ),
            if (_selectedAssignees.length > 3)
              Align(
                widthFactor: 0.7,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    '+${_selectedAssignees.length - 3}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
