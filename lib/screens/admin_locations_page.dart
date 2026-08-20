import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/skeleton_loading.dart';

class AdminLocationsPage extends StatefulWidget {
  const AdminLocationsPage({super.key, required this.service});

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
        title: const Text('ยืนยันการปิดใช้งานจุดทำงาน'),
        content: Text(
          'ต้องการปิดใช้งาน "${loc['name']}" หรือไม่? ประวัติการลงเวลาเดิมจะยังคงอยู่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ปิดใช้งาน'),
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
            content: Text('ปิดใช้งาน "${loc['name']}" แล้ว'),
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

  void _showAddLocationDialog([Map<String, dynamic>? existing]) {
    final formKey = GlobalKey<FormState>();
    final isEditing = existing != null;
    String name = existing?['name']?.toString() ?? '';
    double lat = double.tryParse('${existing?['latitude'] ?? ''}') ?? 0.0;
    double lng = double.tryParse('${existing?['longitude'] ?? ''}') ?? 0.0;
    double radius = double.tryParse('${existing?['radius_m'] ?? ''}') ?? 100.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'แก้ไขจุดทำงาน' : 'เพิ่มจุดทำงาน',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: workText,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(
                  labelText: 'ชื่อสถานที่ / สาขา',
                  hintText: 'เช่น สำนักงานใหญ่, สาขาสาทร',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'กรุณากรอกชื่อสถานที่'
                    : null,
                onSaved: (val) => name = val!.trim(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: isEditing ? '$lat' : null,
                      decoration: const InputDecoration(
                        labelText: 'พิกัด ละติจูด (Latitude)',
                        hintText: 'เช่น 13.7563',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                          ? 'ข้อมูลไม่ถูกต้อง'
                          : null,
                      onSaved: (val) => lat = double.parse(val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: isEditing ? '$lng' : null,
                      decoration: const InputDecoration(
                        labelText: 'พิกัด ลองจิจูด (Longitude)',
                        hintText: 'เช่น 100.5018',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                          ? 'ข้อมูลไม่ถูกต้อง'
                          : null,
                      onSaved: (val) => lng = double.parse(val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'รัศมีการบันทึกเวลา (เมตร)',
                  hintText: 'ปกติกำหนดเป็น 50 หรือ 100 เมตร',
                ),
                keyboardType: TextInputType.number,
                initialValue: radius.toStringAsFixed(0),
                validator: (val) => val == null || double.tryParse(val) == null
                    ? 'กรุณาระบุตัวเลขรัศมี'
                    : null,
                onSaved: (val) => radius = double.parse(val!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();

                    try {
                      if (isEditing) {
                        await widget.service.updateLocation(
                          id: existing['id'].toString(),
                          name: name,
                          lat: lat,
                          lng: lng,
                          radius: radius,
                        );
                      } else {
                        await widget.service.createLocation(
                          name: name,
                          lat: lat,
                          lng: lng,
                          radius: radius,
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing
                                  ? 'แก้ไขจุดทำงานเรียบร้อย'
                                  : 'เพิ่มจุดทำงานเรียบร้อย',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadLocations();
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เกิดข้อผิดพลาด: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: workBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEditing ? 'บันทึกการแก้ไข' : 'บันทึกจุดทำงานใหม่',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.service.currentUser?.role == 'admin';

    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: Text(
          isAdmin ? 'จัดการจุดปฏิบัติงาน (Geofence)' : 'จุดทำงาน',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () => _showAddLocationDialog(),
              icon: const Icon(Icons.add_location_alt_rounded, color: workBlue),
              tooltip: 'เพิ่มจุดทำงานใหม่',
            ),
        ],
      ),
      body: _loading && _locations.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SimpleManagementListSkeleton(),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'โหลดข้อมูลล้มเหลว: $_error',
                    style: const TextStyle(color: workText),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadLocations,
                    child: const Text('ลองอีกครั้ง'),
                  ),
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
                    const Text(
                      'ยังไม่มีการตั้งค่าจุดพิกัดปฏิบัติงาน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: workText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAdmin
                          ? 'กรุณากดเพิ่มจุดปฏิบัติงานใหม่ด้านบนเพื่อให้พนักงานลงเวลาสแกนหน้าได้'
                          : 'ยังไม่มีจุดทำงานที่เปิดให้เช็คอิน',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: workMuted),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _showAddLocationDialog(),
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: const Text('เพิ่มสาขาใหม่'),
                        style: FilledButton.styleFrom(
                          backgroundColor: workBlue,
                        ),
                      ),
                    ],
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
                final lat =
                    double.tryParse(loc['latitude']?.toString() ?? '') ?? 0.0;
                final lng =
                    double.tryParse(loc['longitude']?.toString() ?? '') ?? 0.0;
                final radius =
                    double.tryParse(loc['radius_m']?.toString() ?? '') ?? 100.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x040F172A),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _showLocationDetails(
                      name: name,
                      lat: lat,
                      lng: lng,
                      radius: radius,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: workBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: workBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: workText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'พิกัด: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: workMuted,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'แตะเพื่อดูพื้นที่เช็คอิน · รัศมี ${radius.toStringAsFixed(0)} เมตร',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: workMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isAdmin)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _showAddLocationDialog(loc),
                                  icon: const Icon(
                                    Icons.edit_location_alt_outlined,
                                    color: workBlue,
                                    size: 20,
                                  ),
                                  tooltip: 'แก้ไข',
                                ),
                                IconButton(
                                  onPressed: () => _deleteLocation(loc),
                                  icon: const Icon(
                                    Icons.location_off_outlined,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  tooltip: 'ปิดใช้งาน',
                                ),
                              ],
                            )
                          else
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: workMuted,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showLocationDetails({
    required String name,
    required double lat,
    required double lng,
    required double radius,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: workBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: workText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nexhr.hr_management',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(lat, lng),
                            radius: radius,
                            useRadiusInMeter: true,
                            color: const Color(0x332563EB),
                            borderColor: workBlue,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lng),
                            width: 48,
                            height: 48,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x330F172A),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.red,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'พื้นที่อนุญาตให้เช็คอินประมาณ ${radius.toStringAsFixed(0)} เมตรจากจุดกลาง',
                style: const TextStyle(
                  fontSize: 12,
                  color: workText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'พิกัด $lat, $lng',
                style: const TextStyle(fontSize: 11, color: workMuted),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: workMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'วงสีน้ำเงินคือพื้นที่ที่อนุญาตให้เช็คอินตามพิกัดจริงของจุดทำงาน',
                      style: TextStyle(fontSize: 10.5, color: workMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
