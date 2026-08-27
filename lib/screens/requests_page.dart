import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({
    super.key,
    required this.service,
    required this.onMenu,
    required this.isActive,
    this.targetRequestId,
    this.onClearTargetRequest,
  });

  final AuthFlowService service;
  final VoidCallback onMenu;
  final bool isActive;
  final String? targetRequestId;
  final VoidCallback? onClearTargetRequest;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<WorkRequestRecord> _requests = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void didUpdateWidget(covariant RequestsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadRequestsBackground();
    } else if (widget.isActive && widget.targetRequestId != oldWidget.targetRequestId) {
      _checkTargetRequest();
    }
  }

  void _checkTargetRequest() {
    if (widget.targetRequestId == null || !widget.isActive || _requests.isEmpty) return;

    final targetIdx = _requests.indexWhere((r) => r.id == widget.targetRequestId);
    if (targetIdx != -1) {
      final target = _requests[targetIdx];

      // ล้างค่า target เพื่อไม่ให้เปิดซ้ำเมื่อมีการ rebuild
      widget.onClearTargetRequest?.call();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _RequestDetailSheet(
            request: target,
            service: widget.service,
            onRefresh: _loadRequests,
          ),
        );
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await widget.service.getMyRequests();
      if (mounted) {
        setState(() => _requests = requests);
        _checkTargetRequest();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRequestsBackground() async {
    try {
      final requests = await widget.service.getMyRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _error = null;
        });
        _checkTargetRequest();
      }
    } catch (_) {
      // Ignore background load errors silently
    }
  }

  Future<void> _openCreateRequestSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateRequestSheet(service: widget.service),
    );
    if (result == true) {
      _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งคำขอเรียบร้อย รอแอดมินอนุมัติ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: workBackground,
      child: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 28),
                  child: WorkHeader(
                    title: 'ระบบคำขอ',
                    subtitle: 'ลา / ออกหน้างาน',
                    bottomPadding: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ยื่นคำขอให้ผู้ดูแลอนุมัติ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: _CreateRequestButton(
                    onPressed: _openCreateRequestSheet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: WorkCard(
                child: Column(
                  children: [
                    const WorkCardTitle(
                      icon: Icons.history_rounded,
                      title: 'ประวัติคำขอของฉัน',
                    ),
                    const SizedBox(height: 12),
                    if (_loading && _requests.isEmpty)
                      const RequestListSkeleton()
                    else if (_error != null)
                      _RequestEmpty(
                        icon: Icons.cloud_off_rounded,
                        message: _error!,
                      )
                    else if (_requests.isEmpty)
                      const _RequestEmpty(
                        icon: Icons.inbox_outlined,
                        message: 'ยังไม่มีคำขอ',
                      )
                    else
                      ..._requests.map((r) => _RequestRow(
                            r,
                            service: widget.service,
                            onRefresh: _loadRequests,
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(this.request, {required this.service, required this.onRefresh});

  final WorkRequestRecord request;
  final AuthFlowService service;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _RequestDetailSheet(
            request: request,
            service: service,
            onRefresh: onRefresh,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                request.isOffsite
                    ? Icons.directions_car_outlined
                    : Icons.event_busy_outlined,
                color: workBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.type,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    request.type == 'สลับวันหยุด' && request.swapDate != null
                        ? 'หยุด: ${DateFormat('dd MMM yyyy').format(request.date)} ➔ ชดเชย: ${DateFormat('dd MMM yyyy').format(request.swapDate!)} · ${request.reason}'
                        : '${DateFormat('dd MMM yyyy').format(request.date)} · ${request.reason}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: workMuted, fontSize: 12),
                  ),
                  if (request.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: request.attachments.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final rawUrl = request.attachments[index];
                          final httpUrl = rawUrl.startsWith('r2://')
                              ? rawUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                              : rawUrl;

                          return GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(16),
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Center(
                                        child: InteractiveViewer(
                                          maxScale: 4.0,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              httpUrl,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                httpUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 36,
                                  height: 36,
                                  color: const Color(0xFFF1F5F9),
                                  child: const Icon(Icons.broken_image_outlined, size: 16, color: workMuted),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: request.status),
          ],
        ),
      ),
    );
  }
}

class _RequestEmpty extends StatelessWidget {
  const _RequestEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, color: workMuted, size: 38),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: workMuted),
          ),
        ],
      ),
    );
  }
}

class _CreateRequestSheet extends StatefulWidget {
  const _CreateRequestSheet({required this.service, this.requestToEdit});

  final AuthFlowService service;
  final WorkRequestRecord? requestToEdit;

  @override
  State<_CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class _CreateRequestSheetState extends State<_CreateRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  final _types = const [
    'ออกหน้างาน',
    'ลาป่วย',
    'ลากิจ',
    'ลาพักร้อน',
    'สลับวันหยุด',
  ];
  final _durations = const ['เต็มวัน', 'ครึ่งวันเช้า', 'ครึ่งวันบ่าย'];

  String _type = 'ออกหน้างาน';
  String _duration = 'เต็มวัน';
  DateTime _selectedDate = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool _submitting = false;
  List<HolidayRecord> _holidays = [];
  final List<File> _selectedImages = [];
  List<String> _existingUrls = [];
  final ImagePicker _picker = ImagePicker();
  DateTime? _swapDate;

  @override
  void initState() {
    super.initState();
    if (widget.requestToEdit != null) {
      final req = widget.requestToEdit!;
      _type = req.type;
      _duration = req.duration ?? 'เต็มวัน';
      _selectedDate = req.date;
      _swapDate = req.swapDate;
      _month = DateTime(_selectedDate.year, _selectedDate.month);
      _reasonController.text = req.reason;
      _existingUrls = List<String>.from(req.attachments);
    }
    _loadHolidays();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadHolidays() async {
    try {
      final holidays = await widget.service.getHolidays(_month.year);
      if (mounted) {
        setState(() {
          _holidays = holidays;
        });
      }
    } catch (_) {
      // Ignore background holiday load errors silently
    }
  }

  HolidayRecord? _holidayAt(DateTime date) {
    for (final h in _holidays) {
      if (h.date.year == date.year && h.date.month == date.month && h.date.day == date.day) {
        return h;
      }
    }
    return null;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _loadHolidays();
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickSwapDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _swapDate ?? _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'เลือกวันทำงานชดเชย',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
      selectableDayPredicate: (date) {
        final holiday = _holidayAt(date);
        return holiday == null; // Cannot swap on a holiday
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: workBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: workText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (_sameDate(picked, _selectedDate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('วันทำงานชดเชยต้องเป็นคนละวันกับวันที่ต้องการหยุด')),
          );
        }
        return;
      }
      setState(() {
        _swapDate = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเลือกรูปภาพได้: $e')),
        );
      }
    }
  }

  Future<File> _compressToWebpUnder1MB(File file) async {
    int quality = 90;
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last.split('\\').last.replaceAll('.tmp', '')}.webp';

    File currentFile = file;
    File compressedFile = File(targetPath);

    while (true) {
      final result = await FlutterImageCompress.compressAndGetFile(
        currentFile.absolute.path,
        targetPath,
        quality: quality,
        format: CompressFormat.webp,
      );

      if (result == null) {
        throw Exception('ไม่สามารถบีบอัดรูปภาพได้');
      }

      compressedFile = File(result.path);
      final fileSize = await compressedFile.length();

      if (fileSize <= 1024 * 1024) {
        break;
      }

      quality -= 15;
      if (quality <= 10) {
        break;
      }
      currentFile = compressedFile;
    }

    return compressedFile;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_type == 'สลับวันหยุด') {
      if (_swapDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกวันทำงานชดเชย')),
        );
        return;
      }
      if (_sameDate(_selectedDate, _swapDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('วันทำงานชดเชยต้องเป็นคนละวันกับวันที่ต้องการหยุด')),
        );
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      String? medicalCertUrl;

      // Process attachments if type is not 'ออกหน้างาน'
      if (_type != 'ออกหน้างาน') {
        final List<String> finalUrls = [..._existingUrls];
        for (final img in _selectedImages) {
          // 1. Compress image to WebP under 1MB
          final compressedFile = await _compressToWebpUnder1MB(img);

          // 2. Upload to Cloudflare R2
          final r2Url = await widget.service.uploadImage(compressedFile);
          finalUrls.add(r2Url);
        }

        // 3. Format as JSON array string
        if (finalUrls.isNotEmpty) {
          medicalCertUrl = jsonEncode(finalUrls);
        }
      }

      if (widget.requestToEdit != null) {
        await widget.service.updateRequest(
          id: widget.requestToEdit!.id,
          isOffsite: widget.requestToEdit!.isOffsite,
          type: _type,
          date: _selectedDate,
          reason: _reasonController.text,
          duration: _duration,
          medicalCertUrl: medicalCertUrl,
          swapDate: _type == 'สลับวันหยุด' ? _swapDate : null,
        );
      } else {
        await widget.service.createRequest(
          type: _type,
          date: _selectedDate,
          reason: _reasonController.text,
          duration: _duration,
          medicalCertUrl: medicalCertUrl,
          swapDate: _type == 'สลับวันหยุด' ? _swapDate : null,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7;
    final cells = List<DateTime?>.generate(
      leading + daysInMonth,
      (index) => index < leading
          ? null
          : DateTime(_month.year, _month.month, index - leading + 1),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ยื่นคำขอใหม่',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: workText,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF8FAFC),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: workMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ประเภทคำขอ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ประเภทคำขอ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: workMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _type,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: workBlue,
                                    size: 20,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: workText,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  dropdownColor: Colors.white,
                                  items: _types.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: _type == type ? FontWeight.w700 : FontWeight.w500,
                                          color: _type == type ? workBlue : workText,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _type = val;
                                        if (val == 'ออกหน้างาน' || val == 'สลับวันหยุด') {
                                          _duration = 'เต็มวัน';
                                        }
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
                      // ระยะเวลา
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final isDurationDisabled = _type == 'ออกหน้างาน' || _type == 'สลับวันหยุด';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ระยะเวลา',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: workMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDurationDisabled
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: isDurationDisabled ? 'เต็มวัน' : _duration,
                                      isExpanded: true,
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: isDurationDisabled ? workMuted : workBlue,
                                        size: 20,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDurationDisabled ? workMuted : workText,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      dropdownColor: Colors.white,
                                      items: _durations.map((d) {
                                        return DropdownMenuItem<String>(
                                          value: d,
                                          child: Text(
                                            d,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: _duration == d ? FontWeight.w700 : FontWeight.w500,
                                              color: _duration == d && !isDurationDisabled ? workBlue : workText,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: isDurationDisabled
                                          ? null
                                          : (val) {
                                              if (val != null) {
                                                setState(() => _duration = val);
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _type == 'สลับวันหยุด'
                        ? '1. เลือกวันที่ต้องการหยุด'
                        : (_type == 'ออกหน้างาน'
                            ? 'เลือกวันที่ออกหน้างาน'
                            : 'เลือกวันที่ต้องการลา'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: workMuted),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => _changeMonth(-1),
                              icon: const Icon(Icons.chevron_left_rounded, size: 20),
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_month),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: workText,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _changeMonth(1),
                              icon: const Icon(Icons.chevron_right_rounded, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            _MiniWeekday('Su', isWeekend: true),
                            _MiniWeekday('Mo'),
                            _MiniWeekday('Tu'),
                            _MiniWeekday('We'),
                            _MiniWeekday('Th'),
                            _MiniWeekday('Fr'),
                            _MiniWeekday('Sa', isWeekend: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisExtent: 36,
                          ),
                          itemCount: cells.length,
                          itemBuilder: (context, idx) {
                            final date = cells[idx];
                            if (date == null) return const SizedBox.shrink();

                            final holiday = _holidayAt(date);
                            final isHoliday = holiday != null;
                            final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                            final isClickable = !isHoliday;
                            final isSelected = _sameDate(date, _selectedDate);
                            final isToday = _sameDate(date, DateTime.now());

                            return InkWell(
                              onTap: !isClickable ? null : () => setState(() => _selectedDate = date),
                              borderRadius: BorderRadius.circular(99),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? workBlue : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: isToday && !isSelected
                                          ? Border.all(color: workBlue.withValues(alpha: 0.5), width: 1.5)
                                          : null,
                                    ),
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: !isClickable
                                            ? const Color(0xFFCBD5E1)
                                            : (isSelected
                                                ? Colors.white
                                                : (isToday
                                                    ? workBlue
                                                    : (isWeekend
                                                        ? const Color(0xFF94A3B8)
                                                        : workText))),
                                        fontWeight: isSelected || isToday
                                            ? FontWeight.w700
                                            : (isWeekend ? FontWeight.normal : FontWeight.w500),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  if (isHoliday)
                                    Positioned(
                                      bottom: 1,
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.circle, size: 6, color: Color(0xFFEF4444)),
                            SizedBox(width: 6),
                            Text(
                              'จุดสีแดง = วันหยุดนักขัตฤกษ์ (ไม่สามารถเลือกยื่นคำขอได้)',
                              style: TextStyle(fontSize: 10, color: workMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_type == 'สลับวันหยุด') ...[
                    const SizedBox(height: 16),
                    const Text(
                      '2. เลือกวันที่มาทำงานชดเชย',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: workMuted),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickSwapDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _swapDate != null ? workBlue.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                            width: _swapDate != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  color: _swapDate == null ? workMuted : workBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _swapDate == null
                                      ? 'แตะเพื่อเลือกวันทำงานชดเชย'
                                      : DateFormat('dd MMM yyyy').format(_swapDate!),
                                  style: TextStyle(
                                    color: _swapDate == null ? const Color(0xFF94A3B8) : workText,
                                    fontSize: 14,
                                    fontWeight: _swapDate == null ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: workBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: workBlue, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_swapDate != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: workBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: workBlue.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: workBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'สรุป: หยุดวันที่ ${DateFormat('dd MMM yyyy').format(_selectedDate)} ➔ มาทำงานชดเชยวันที่ ${DateFormat('dd MMM yyyy').format(_swapDate!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: workBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'เหตุผล / รายละเอียด',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: workMuted),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'กรุณากรอกเหตุผล...',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'กรุณากรอกเหตุผล';
                      }
                      return null;
                    },
                  ),
                  if (_type != 'ออกหน้างาน') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'แนบหลักฐานรูปภาพ (หลายรูปได้)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: workMuted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Pick Photo button
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: workBlue,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // List of selected images
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: (_existingUrls.isEmpty && _selectedImages.isEmpty)
                                ? const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'ยังไม่ได้เลือกรูปหลักฐาน',
                                      style: TextStyle(color: workMuted, fontSize: 11),
                                    ),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _existingUrls.length + _selectedImages.length,
                                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      if (index < _existingUrls.length) {
                                        // Existing image from R2
                                        final rawUrl = _existingUrls[index];
                                        final httpUrl = rawUrl.startsWith('r2://')
                                            ? rawUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                                            : rawUrl;
                                        return Stack(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                image: DecorationImage(
                                                  image: NetworkImage(
                                                    httpUrl,
                                                    headers: const {
                                                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                                    },
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _existingUrls.removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.black54,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        // Local file picked
                                        final fileIndex = index - _existingUrls.length;
                                        final file = _selectedImages[fileIndex];
                                        return Stack(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                image: DecorationImage(
                                                  image: FileImage(file),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedImages.removeAt(fileIndex);
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.black54,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: workBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'ส่งคำขอ',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                    ),
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

class _MiniWeekday extends StatelessWidget {
  const _MiniWeekday(this.label, {this.isWeekend = false});

  final String label;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isWeekend ? const Color(0xFF94A3B8) : workMuted,
        ),
      ),
    );
  }
}

class _CreateRequestButton extends StatelessWidget {
  const _CreateRequestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: workBlue.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('create_request_button'),
          onTap: onPressed,
          splashColor: workBlue.withValues(alpha: 0.12),
          highlightColor: workBlue.withValues(alpha: 0.06),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: workBlue, size: 22),
                SizedBox(width: 8),
                Text(
                  'ยื่นคำขอใหม่',
                  style: TextStyle(
                    color: workBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestDetailSheet extends StatefulWidget {
  const _RequestDetailSheet({required this.request, required this.service, required this.onRefresh});

  final WorkRequestRecord request;
  final AuthFlowService service;
  final VoidCallback onRefresh;

  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  bool _cancelling = false;

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันยกเลิกคำขอ'),
        content: const Text('คุณต้องการยกเลิกคำขอนี้ใช่หรือไม่? (การดำเนินการนี้ไม่สามารถย้อนกลับได้)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(color: workMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _cancelling = true);
    try {
      await widget.service.deleteRequest(
        id: widget.request.id,
        isOffsite: widget.request.isOffsite,
      );
      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onRefresh(); // Refresh parent
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกคำขอเรียบร้อยแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ยกเลิกคำขอล้มเหลว: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _editRequest() async {
    Navigator.pop(context); // Close details sheet
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateRequestSheet(
        service: widget.service,
        requestToEdit: widget.request,
      ),
    );
    if (result == true) {
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isPending = req.status == 'pending';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รายละเอียดคำขอ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: workMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('ประเภทคำขอ', req.type),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('วันที่ยื่นคำขอ', DateFormat('dd MMM yyyy').format(req.date)),
                    if (req.type == 'สลับวันหยุด' && req.swapDate != null) ...[
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildDetailRow('วันที่ทำงานชดเชย', DateFormat('dd MMM yyyy').format(req.swapDate!)),
                    ],
                    if (!req.isOffsite) ...[
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildDetailRow('ระยะเวลา', req.duration ?? 'เต็มวัน'),
                    ],
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('เหตุผล / รายละเอียด', req.reason),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'สถานะอนุมัติ',
                          style: TextStyle(color: workMuted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        StatusBadge(status: req.status),
                      ],
                    ),
                    if (!req.isOffsite && req.attachments.isNotEmpty) ...[
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      const Text(
                        'ภาพหลักฐานแนบ',
                        style: TextStyle(color: workMuted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: req.attachments.length,
                        itemBuilder: (context, index) {
                          final rawUrl = req.attachments[index];
                          final httpUrl = rawUrl.startsWith('r2://')
                              ? rawUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                              : rawUrl;
                          return GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(16),
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Center(
                                        child: InteractiveViewer(
                                          maxScale: 4.0,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(httpUrl, fit: BoxFit.contain),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(httpUrl, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelling ? null : _cancelRequest,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _cancelling
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                          : const Text('ยกเลิกคำขอ', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _cancelling ? null : _editRequest,
                      style: FilledButton.styleFrom(
                        backgroundColor: workBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('แก้ไขคำขอ', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: workMuted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ปิดหน้าต่าง', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: workMuted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
}
