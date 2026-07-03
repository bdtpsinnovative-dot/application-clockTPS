import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/work_ui.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, required this.service, required this.onMenu});

  final AuthFlowService service;
  final VoidCallback onMenu;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
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
  DateTime _date = DateTime.now();
  List<WorkRequestRecord> _requests = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await widget.service.getMyRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await widget.service.createRequest(
        type: _type,
        date: _date,
        reason: _reasonController.text,
        duration: _duration,
      );
      _reasonController.clear();
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งคำขอเรียบร้อย รอแอดมินอนุมัติ')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: workBackground,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadRequests,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                WorkHeader(
                  title: 'ระบบคำขอ',
                  subtitle: 'ลา / ออกหน้างาน',
                  onMenu: widget.onMenu,
                  bottomPadding: 58,
                  child: const Align(
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
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: WorkCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const WorkCardTitle(
                              icon: Icons.edit_calendar_rounded,
                              title: 'กรอกข้อมูลคำขอ',
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              initialValue: _type,
                              decoration: const InputDecoration(
                                labelText: 'ประเภทคำขอ',
                              ),
                              items: _types
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _type = value);
                                }
                              },
                            ),
                            if (_type != 'ออกหน้างาน') ...[
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _duration,
                                decoration: const InputDecoration(
                                  labelText: 'ระยะเวลา',
                                ),
                                items: _durations
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _duration = value);
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'วันที่ต้องการ',
                                  prefixIcon: Icon(Icons.event_outlined),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(_date),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _reasonController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'เหตุผล / รายละเอียด',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'กรุณากรอกเหตุผล';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: const Icon(Icons.send_rounded),
                              label: const Text('ส่งคำขอให้ Admin อนุมัติ'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                        if (_loading)
                          const LinearProgressIndicator(minHeight: 3)
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
                          ..._requests.map(_RequestRow.new),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_submitting) const AppLoadingOverlay(message: 'กำลังส่งคำขอ...'),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(this.request);

  final WorkRequestRecord request;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
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
                  '${DateFormat('dd MMM yyyy').format(request.date)} · ${request.reason}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: workMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: request.status),
        ],
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
