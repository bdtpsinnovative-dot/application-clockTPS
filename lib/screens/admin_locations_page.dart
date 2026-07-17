import 'package:flutter/material.dart';

import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';

class AdminLocationsPage extends StatefulWidget {
  const AdminLocationsPage({
    super.key,
    required this.service,
  });

  final AuthFlowService service;

  @override
  State<AdminLocationsPage> createState() => _AdminLocationsPageState();
}

class _AdminLocationsPageState extends State<AdminLocationsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _locations = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final locs = await widget.service.getWorkLocations();
      if (mounted) {
        setState(() {
          _locations = locs;
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

  Future<void> _deleteLocation(Map<String, dynamic> loc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบจุดทำงาน'),
        content: Text('ต้องการลบจุดทำงาน "${loc['name']}" หรือไม่? การลบจะทำให้พนักงานไม่สามารถบันทึกเวลาในจุดพิกัดนี้ได้อีก'),
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
      final id = loc['id']?.toString() ?? '';
      await widget.service.deleteLocation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบจุดทำงาน "${loc['name']}" สำเร็จแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        _loadLocations();
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

  void _showAddLocationDialog() {
    final formKey = GlobalKey<FormState>();
    String name = '';
    double lat = 0.0;
    double lng = 0.0;
    double radius = 100.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
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
                  const Text('เพิ่มจุดพิกัดสาขา/สถานที่ทำงาน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: workText)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'ชื่อสถานที่ / สาขา', hintText: 'เช่น สำนักงานใหญ่, สาขาสาทร'),
                validator: (val) => val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อสถานที่' : null,
                onSaved: (val) => name = val!.trim(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'พิกัด ละติจูด (Latitude)', hintText: 'เช่น 13.7563'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'ข้อมูลไม่ถูกต้อง' : null,
                      onSaved: (val) => lat = double.parse(val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'พิกัด ลองจิจูด (Longitude)', hintText: 'เช่น 100.5018'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'ข้อมูลไม่ถูกต้อง' : null,
                      onSaved: (val) => lng = double.parse(val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'รัศมีการบันทึกเวลา (เมตร)', hintText: 'ปกติกำหนดเป็น 50 หรือ 100 เมตร'),
                keyboardType: TextInputType.number,
                initialValue: '100',
                validator: (val) => val == null || double.tryParse(val) == null ? 'กรุณาระบุตัวเลขรัศมี' : null,
                onSaved: (val) => radius = double.parse(val!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    Navigator.pop(context);

                    try {
                      await widget.service.createLocation(name: name, lat: lat, lng: lng, radius: radius);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('เพิ่มจุดพิกัดทำงานสำเร็จแล้ว 🎉'), backgroundColor: Colors.green),
                        );
                        _loadLocations();
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
                child: const Text('บันทึกจุดพิกัดใหม่', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
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
        title: const Text('จัดการจุดปฏิบัติงาน (Geofence)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: _showAddLocationDialog,
            icon: const Icon(Icons.add_location_alt_rounded, color: workBlue),
            tooltip: 'เพิ่มจุดทำงานใหม่',
          )
        ],
      ),
      body: _loading
          ? const AppLoadingView(message: 'กำลังโหลดข้อมูลสถานที่...')
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('โหลดข้อมูลล้มเหลว: $_error', style: const TextStyle(color: workText)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadLocations, child: const Text('ลองอีกครั้ง')),
                    ],
                  ),
                )
              : _locations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map_rounded, size: 64, color: workMuted),
                            const SizedBox(height: 16),
                            const Text('ยังไม่มีการตั้งค่าจุดพิกัดปฏิบัติงาน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: workText)),
                            const SizedBox(height: 8),
                            const Text('กรุณากดเพิ่มจุดปฏิบัติงานใหม่ด้านบนเพื่อให้พนักงานลงเวลาสแกนหน้าได้', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: workMuted)),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _showAddLocationDialog,
                              icon: const Icon(Icons.add_location_alt_rounded),
                              label: const Text('เพิ่มสาขาใหม่'),
                              style: FilledButton.styleFrom(backgroundColor: workBlue),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final loc = _locations[index];
                        final name = loc['name']?.toString() ?? 'สาขา';
                        final lat = double.tryParse(loc['latitude']?.toString() ?? '') ?? 0.0;
                        final lng = double.tryParse(loc['longitude']?.toString() ?? '') ?? 0.0;
                        final radius = double.tryParse(loc['radius_m']?.toString() ?? '') ?? 100.0;

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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: workBlue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on_rounded, color: workBlue, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: workText),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'พิกัด: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                      style: const TextStyle(fontSize: 10, color: workMuted),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'รัศมีตรวจจับ Geofence: ${radius.toStringAsFixed(0)} เมตร',
                                      style: const TextStyle(fontSize: 10, color: workMuted, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteLocation(loc),
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                                tooltip: 'ลบสาขา',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
