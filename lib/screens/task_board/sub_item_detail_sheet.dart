part of '../task_board_page.dart';

class _SubItemDetailSheet extends StatefulWidget {
  const _SubItemDetailSheet({
    required this.item,
    required this.parentCardTitle,
    required this.listName,
    required this.service,
    required this.canEdit,
    required this.onChanged,
  });

  final TaskSubItem item;
  final String parentCardTitle;
  final String listName;
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
  String _subItemPriority = 'medium';
  String _currentStatus = 'pending';
  final List<Map<String, String>> _uploadingFiles = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _linkUrlController = TextEditingController(text: widget.item.linkUrl ?? '');
    _attachmentUrlController = TextEditingController(
      text: widget.item.attachmentUrl ?? '',
    );
    _verificationController = TextEditingController(
      text: widget.item.verificationNotes ?? '',
    );
    _adminCommentController = TextEditingController(
      text: widget.item.adminComment ?? '',
    );
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
    final picked = await showWorkDueDatePicker(
      context,
      initialDate: _startDate ?? DateTime.now(),
      title: 'เลือกวันที่เริ่ม',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showWorkDueDatePicker(
      context,
      initialDate: _dueDate ?? DateTime.now(),
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
        allowedExtensions: isImageOnly
            ? null
            : ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _saving = false);
        return;
      }

      File selectedFile = File(result.files.single.path!);
      final filename = result.files.single.name.toLowerCase();

      // Compress if it is an image (jpg, jpeg, png) to WebP for Cloudflare savings
      if (filename.endsWith('.jpg') ||
          filename.endsWith('.jpeg') ||
          filename.endsWith('.png')) {
        final tempDir = await getTemporaryDirectory();
        final targetPath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';

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
          const SnackBar(
            content: Text('อัปโหลดไฟล์สำเร็จ!'),
            backgroundColor: Colors.green,
          ),
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
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _getLinkUrls() {
    final text = _linkUrlController.text.trim();
    if (text.isEmpty) return [];
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
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
    final bool isImage =
        !isLink &&
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage
                  ? Image.network(
                      fullUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: workMuted,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(6),
                      color: isLink
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLink
                                ? Icons.link_rounded
                                : Icons.picture_as_pdf_rounded,
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
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage && localPath.isNotEmpty
                  ? Image.file(File(localPath), fit: BoxFit.cover)
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

  Future<void> _uploadSubItemFileInBackground(
    File uploadFile,
    String filename,
    String localPathKey,
  ) async {
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
          SnackBar(
            content: Text('อัปโหลดไฟล์ $filename ล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFileOrImageCombined() async {
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

      if (result == null || result.files.isEmpty) {
        return;
      }

      int tempCount = 0;
      for (var fileItem in result.files) {
        if (fileItem.path == null) continue;
        File file = File(fileItem.path!);
        final filename = fileItem.name;
        final localPathKey =
            'local_${DateTime.now().millisecondsSinceEpoch}_${tempCount++}';

        setState(() {
          _uploadingFiles.add({
            'path': localPathKey,
            'localPath': file.path,
            'name': filename,
            'type':
                (filename.toLowerCase().endsWith('.jpg') ||
                    filename.toLowerCase().endsWith('.jpeg') ||
                    filename.toLowerCase().endsWith('.png') ||
                    filename.toLowerCase().endsWith('.webp'))
                ? 'image'
                : 'file',
          });
        });

        // Trigger background upload
        _uploadSubItemFileInBackground(file, filename, localPathKey);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เลือกไฟล์ล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveDetail() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกหัวข้อรายการย่อย'),
          backgroundColor: Colors.red,
        ),
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
          SnackBar(
            content: Text('บันทึกรายละเอียดล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteSubItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'ลบรายการย่อย',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('คุณต้องการลบรายการย่อย "${widget.item.title}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(color: workMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ลบ',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
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
          Navigator.pop(context); // Close detail sheet
        }
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบรายการย่อยล้มเหลว: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showVerificationsHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ประวัติการส่งงาน / ตรวจงาน',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: workText,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildVerificationRoundsSection()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdminOrHr =
        widget.service.currentUser?.role == 'admin' ||
        widget.service.currentUser?.role == 'hr';

    return DefaultTabController(
      length: 2,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          color: Colors.white,
          child: Column(
            children: [
              // ─── Header Bar ───
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.listName} › ${widget.parentCardTitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: workMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'แก้ไขข้อมูลงานย่อย',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: workText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: _showVerificationsHistory,
                      tooltip: 'ประวัติการตรวจงาน',
                    ),
                    if (widget.canEdit)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: _confirmDeleteSubItem,
                        tooltip: 'ลบรายการย่อย',
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'ปิด',
                    ),
                  ],
                ),
              ),

              // ─── Tab Bar (2 Tabs) ───
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: const TabBar(
                  indicatorColor: workBlue,
                  indicatorWeight: 2.5,
                  labelColor: workBlue,
                  unselectedLabelColor: Color(0xFF64748B),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(text: 'ข้อมูลทั่วไป (General Info)'),
                    Tab(text: 'เอกสาร & หมายเหตุ (Docs & Notes)'),
                  ],
                ),
              ),

              // ─── Tab Bar Views ───
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: General Info
                    _buildGeneralInfoTab(context, isAdminOrHr),

                    // Tab 2: Docs & Notes
                    _buildDocsAndNotesTab(context, isAdminOrHr),
                  ],
                ),
              ),

              // ─── Sticky Bottom Footer Bar ───
              Container(
                padding: EdgeInsets.fromLTRB(
                   16,
                  10,
                  16,
                  MediaQuery.viewInsetsOf(context).bottom +
                      MediaQuery.paddingOf(context).bottom +
                      10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveDetail,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        _saving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: workBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
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
      ),
    );
  }

  /// ─── Tab 1: ข้อมูลทั่วไป (General Info) ───
  Widget _buildGeneralInfoTab(BuildContext context, bool isAdminOrHr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ชื่อรายการคอร์สงาน
          const Text(
            'ชื่อรายการคอร์สงาน',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: workText,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 13.5, color: workText),
            decoration: InputDecoration(
              hintText: 'พิมพ์ชื่อรายการคอร์สงาน...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
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
          ),
          const SizedBox(height: 14),

          // Row: วันกำหนดส่ง & ความสำคัญ
          Row(
            children: [
              // วันกำหนดส่ง
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'วันกำหนดส่ง',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: workText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dueDate != null
                                    ? _formatThaiDate(_dueDate!)
                                    : 'วว/ดด/ปปปป',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _dueDate != null
                                      ? workText
                                      : workMuted,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ความสำคัญ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ความสำคัญ (Priority)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: workText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _subItemPriority,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                          style: const TextStyle(fontSize: 12, color: workText),
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('⚡ ต่ำ (Low)'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('⚡ ด่วนปานกลาง (Medium)'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('⚡ ด่วนมาก (High)'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('⚡ ด่วนที่สุด (Urgent)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _subItemPriority = val;
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
          const SizedBox(height: 14),

          // สถานะงาน (Status)
          const Text(
            'สถานะงาน (Status)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: workText,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentStatus,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: const TextStyle(fontSize: 12.5, color: workText),
                items: const [
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('รอรับงาน (Pending)'),
                  ),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('กำลังทำ (In Progress)'),
                  ),
                  DropdownMenuItem(
                    value: 'in_review',
                    child: Text('รอตรวจสอบ (In Review)'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('เสร็จสิ้น (Completed)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _currentStatus = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // มอบหมายให้ (Assignees)
          const Text(
            'มอบหมายให้ (Assignees)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: workText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.add, size: 18, color: workBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // รายละเอียดเพิ่มเติม (Details)
          const Text(
            'รายละเอียดเพิ่มเติม (Details)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: workText,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _verificationController,
            maxLines: 4,
            style: const TextStyle(fontSize: 13, color: workText),
            decoration: InputDecoration(
              hintText: 'กรอกรายละเอียดเพิ่มเติมของรายการย่อยนี้...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: workBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// ─── Tab 2: เอกสาร & หมายเหตุ (Docs & Notes) ───
  Widget _buildDocsAndNotesTab(BuildContext context, bool isAdminOrHr) {
    final attachmentUrls = _getAttachmentUrls();
    final linkUrls = _getLinkUrls();
    final hasAttachments =
        attachmentUrls.isNotEmpty ||
        linkUrls.isNotEmpty ||
        _uploadingFiles.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NOTE / Remark (ความคิดเห็นจากผู้ดูแล)
          const Text(
            'NOTE / Remark (ความคิดเห็นจากผู้ดูแล)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: workText,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _adminCommentController,
            maxLines: 4,
            enabled: isAdminOrHr,
            style: const TextStyle(fontSize: 13, color: workText),
            decoration: InputDecoration(
              hintText: 'เพิ่มคำอธิบายหรือความคิดเห็นผู้ดูแล...',
              filled: true,
              fillColor: const Color(0xFFFFFBEB),
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.amber, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // เอกสารแนบ & ลิงก์ไฟล์งาน (Attachments)
          const Text(
            'เอกสารแนบ & ลิงก์ไฟล์งาน (Attachments)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: workText,
            ),
          ),
          const SizedBox(height: 8),

          if (!hasAttachments)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'ยังไม่มีเอกสารแนบในคอร์สงานนี้',
                  style: TextStyle(fontSize: 12.5, color: workMuted),
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (int i = 0; i < attachmentUrls.length; i++)
                  _buildSubItemEvidencePreviewBox(
                    url: attachmentUrls[i],
                    isLink: false,
                    onDelete: () {
                      setState(() {
                        attachmentUrls.removeAt(i);
                        _attachmentUrlController.text = attachmentUrls.join(
                          ',',
                        );
                      });
                    },
                  ),
                for (int i = 0; i < linkUrls.length; i++)
                  _buildSubItemEvidencePreviewBox(
                    url: linkUrls[i],
                    isLink: true,
                    onDelete: () {
                      setState(() {
                        linkUrls.removeAt(i);
                        _linkUrlController.text = linkUrls.join(',');
                      });
                    },
                  ),
                for (int i = 0; i < _uploadingFiles.length; i++)
                  _buildSubItemUploadingPreviewBox(_uploadingFiles[i]),
              ],
            ),
          const SizedBox(height: 14),

          // 2 Action Buttons: [ 📎 แนบไฟล์ (ลิงก์) ]  [ 🔗 แนบลิงก์ ]
          if (widget.canEdit)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFileOrImageCombined(),
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                    label: const Text(
                      'แนบไฟล์ (ลิงก์)',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFA5B4FC)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final textController = TextEditingController(
                        text: _linkUrlController.text,
                      );
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: const Text(
                            'แนบลิงก์อ้างอิง',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          content: TextField(
                            controller: textController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'https://example.com...',
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
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: workBlue,
                                foregroundColor: Colors.white,
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
                    icon: const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    label: const Text(
                      'แนบลิงก์',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF6EE7B7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSubItemAdminCommentSection() {
    final bool isAdminOrHr =
        widget.service.currentUser?.role == 'admin' ||
        widget.service.currentUser?.role == 'hr';
    final hasComment =
        widget.item.adminComment != null &&
        widget.item.adminComment!.trim().isNotEmpty;

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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.amber[900],
              ),
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
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
              style: const TextStyle(
                fontSize: 13,
                color: workText,
                height: 1.4,
              ),
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

      final verifierName =
          widget.service.currentUser?.firstName ?? 'ผู้ตรวจสอบ';
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
        _currentStatus = _selectedInspectionStatus == 'approved'
            ? 'completed'
            : 'pending';
        _inspectionNotesController.clear();
        _verifying = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกผลการตรวจสอบสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกผลการตรวจสอบล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildVerificationRoundsSection() {
    final bool isAdminOrHr =
        widget.service.currentUser?.role == 'admin' ||
        widget.service.currentUser?.role == 'hr';

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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
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
                  color: isApproved
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isApproved
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isApproved
                                    ? const Color(0xFFBBF7D0)
                                    : const Color(0xFFFECACA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isApproved ? 'ผ่าน' : 'ไม่ผ่าน',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isApproved
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'รอบที่ ${v.round}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: workText,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: workMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: workMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ผู้ตรวจ: ${v.verifierName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: workText,
                            fontWeight: FontWeight.w500,
                          ),
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
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: workText,
                          ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: workText,
                ),
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
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: Colors.green,
                      ),
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
                    color: _selectedInspectionStatus == 'approved'
                        ? Colors.green[800]
                        : workMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _selectedInspectionStatus == 'approved'
                          ? Colors.green
                          : const Color(0xFFE2E8F0),
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
                    color: _selectedInspectionStatus == 'rejected'
                        ? Colors.red[800]
                        : workMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _selectedInspectionStatus == 'rejected'
                          ? Colors.red
                          : const Color(0xFFE2E8F0),
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _verifying ? 'กำลังบันทึกผล...' : 'บันทึกผลการตรวจสอบรอบนี้',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatInspectionDate(DateTime dt) {
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
    return '${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year + 543} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
  }
}

// ─── Thai Date Formatter Helper ────────────────────────────────────
String _formatThaiDate(DateTime? date) {
  if (date == null) return '';
  final months = [
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
  return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
}
