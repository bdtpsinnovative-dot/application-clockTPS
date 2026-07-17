import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';

class AdminHolidaysPage extends StatefulWidget {
  const AdminHolidaysPage({
    super.key,
    required this.service,
  });

  final AuthFlowService service;

  @override
  State<AdminHolidaysPage> createState() => _AdminHolidaysPageState();
}

class _AdminHolidaysPageState extends State<AdminHolidaysPage> {
  bool _loading = true;
  List<HolidayRecord> _holidays = [];
  String? _error;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final hols = await widget.service.getHolidays(_selectedYear);
      if (mounted) {
        setState(() {
          _holidays = hols;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteHoliday(HolidayRecord hol) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบวันหยุด'),
        content: Text('ต้องการลบวันหยุด "${hol.name}" หรือไม่? พนักงานจะถูกดึงสิทธิ์วันหยุดนี้คืน'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ยืนยันการลบ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.service.deleteHoliday(hol.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบวันหยุด "${hol.name}" สำเร็จแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHolidays();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddHolidayDialog() {
    final formKey = GlobalKey<FormState>();
    String name = '';
    DateTime? selectedDate;
    int numDays = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('เพิ่มวันหยุดบริษัท', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: workText)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'ชื่อวันหยุด / เทศกาล', hintText: 'เช่น วันสงกรานต์, วันขึ้นปีใหม่'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อวันหยุด' : null,
                  onSaved: (val) => name = val!.trim(),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE4E9F0)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF5F7FA),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate == null
                              ? 'เลือกวันที่หยุด'
                              : 'วันที่หยุด: ${DateFormat('dd MMM yyyy').format(selectedDate!)}',
                          style: TextStyle(
                            color: selectedDate == null ? workMuted : workText,
                            fontSize: 14,
                            fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.calendar_month_rounded, color: workBlue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'จำนวนวันที่หยุดต่อเนื่อง (วัน)', hintText: 'ปกติกำหนดเป็น 1 วัน'),
                  keyboardType: TextInputType.number,
                  initialValue: '1',
                  validator: (val) => val == null || int.tryParse(val) == null || int.parse(val) <= 0 ? 'กรุณาระบุจำนวนวันมากกว่า 0' : null,
                  onSaved: (val) => numDays = int.parse(val!),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('กรุณาเลือกวันที่หยุดก่อนบันทึก'), backgroundColor: Colors.amber),
                      );
                      return;
                    }
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      Navigator.pop(context);

                      try {
                        await widget.service.createHoliday(name: name, date: selectedDate!, numDays: numDays);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('เพิ่มวันหยุดบริษัทสำเร็จแล้ว 🎉'), backgroundColor: Colors.green),
                          );
                          _loadHolidays();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: workBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('บันทึกวันหยุด', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text('ปฏิทินวันหยุดบริษัท (Admin)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: _showAddHolidayDialog,
            icon: const Icon(Icons.add_card_rounded, color: workBlue),
            tooltip: 'เพิ่มวันหยุดใหม่',
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('เลือกปีที่ต้องการดู', style: TextStyle(fontWeight: FontWeight.bold, color: workText, fontSize: 14)),
                DropdownButton<int>(
                  value: _selectedYear,
                  items: [
                    DropdownMenuItem(value: DateTime.now().year - 1, child: Text('${DateTime.now().year - 1}')),
                    DropdownMenuItem(value: DateTime.now().year, child: Text('${DateTime.now().year}')),
                    DropdownMenuItem(value: DateTime.now().year + 1, child: Text('${DateTime.now().year + 1}')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = val;
                      });
                      _loadHolidays();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoadingView(message: 'กำลังโหลดข้อมูลวันหยุด...')
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('โหลดข้อมูลล้มเหลว: $_error', style: const TextStyle(color: workText)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadHolidays, child: const Text('ลองอีกครั้ง')),
                          ],
                        ),
                      )
                    : _holidays.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit_calendar_rounded, size: 64, color: workMuted),
                                const SizedBox(height: 16),
                                const Text('ยังไม่มีข้อมูลวันหยุดบริษัทในปีนี้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: workText)),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: _showAddHolidayDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('เพิ่มวันหยุดแรก'),
                                  style: FilledButton.styleFrom(backgroundColor: workBlue),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _holidays.length,
                            itemBuilder: (context, index) {
                              final hol = _holidays[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                  boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 1))],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFFEDD5)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            DateFormat('dd').format(hol.date),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFEA580C),
                                            ),
                                          ),
                                          Text(
                                            DateFormat('MMM').format(hol.date),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFD97706),
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
                                          Text(
                                            hol.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: workText),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'หยุดต่อเนื่อง: ${hol.numDays} วัน',
                                            style: const TextStyle(fontSize: 10, color: workMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteHoliday(hol),
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                                      tooltip: 'ลบวันหยุด',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
