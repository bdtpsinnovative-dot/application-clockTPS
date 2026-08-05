import 'package:flutter/material.dart';
import '../widgets/work_ui.dart';
import '../services/auth_flow_service.dart';
import '../models/app_user.dart';

class EditUserInfoPage extends StatefulWidget {
  final AuthFlowService service;
  final AppUser user;
  final VoidCallback onProfileUpdated;

  const EditUserInfoPage({
    super.key,
    required this.service,
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  State<EditUserInfoPage> createState() => _EditUserInfoPageState();
}

class _EditUserInfoPageState extends State<EditUserInfoPage> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _nickCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.user.firstName);
    _lastCtrl = TextEditingController(text: widget.user.lastName);
    _nickCtrl = TextEditingController(text: widget.user.nickname);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    final fName = _firstCtrl.text.trim();
    final lName = _lastCtrl.text.trim();
    final nName = _nickCtrl.text.trim();

    if (fName.isEmpty || lName.isEmpty || nName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อ นามสกุล และชื่อเล่น'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.service.updateProfileInfo(
        firstName: fName,
        lastName: lName,
        nickname: nName,
        avatarUrl: widget.user.avatarUrl ?? '',
      );

      if (mounted) {
        widget.onProfileUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปเดตข้อมูลผู้ใช้เรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text(
          'ข้อมูลผู้ใช้',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: workBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ตั้งค่าชื่อของคุณ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: workText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ชื่อนี้จะแสดงให้เพื่อนร่วมงานเห็น',
                    style: TextStyle(
                      fontSize: 13,
                      color: workMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('ชื่อจริง'),
                  const SizedBox(height: 8),
                  _buildModernTextField(_firstCtrl, 'กรอกชื่อจริง', Icons.person_outline_rounded),
                  
                  const SizedBox(height: 20),
                  _buildLabel('นามสกุล'),
                  const SizedBox(height: 8),
                  _buildModernTextField(_lastCtrl, 'กรอกนามสกุล', Icons.badge_outlined),
                  
                  const SizedBox(height: 20),
                  _buildLabel('ชื่อเล่น'),
                  const SizedBox(height: 8),
                  _buildModernTextField(_nickCtrl, 'กรอกชื่อเล่น', Icons.face_retouching_natural_rounded),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: workBlue.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _saveInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: workBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'บันทึกข้อมูล',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC), // Very soft slate
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: workBlue, width: 1.5),
        ),
      ),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: workText,
      ),
    );
  }
}
