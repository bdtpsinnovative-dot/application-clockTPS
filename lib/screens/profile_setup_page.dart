import 'dart:io';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/work_ui.dart';
import 'face_scanner_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.service,
    this.initialUser,
    required this.onProfileSaved,
    required this.onSignOut,
  });

  final AuthFlowService service;
  final AppUser? initialUser;
  final Future<void> Function() onProfileSaved;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  List<double>? _faceVector;
  File? _avatarFile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.initialUser?.firstName,
    );
    _lastNameController = TextEditingController(
      text: widget.initialUser?.lastName,
    );
  }

  Future<void> _scanFace() async {
    final vector = await Navigator.of(context).push<List<double>>(
      MaterialPageRoute(builder: (_) => const FaceScannerPage()),
    );

    if (vector != null) {
      setState(() {
        _faceVector = vector;
      });
      _showMessage('สแกนใบหน้าสำเร็จ ระบบจดจำโครงหน้าของคุณแล้ว');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_avatarFile == null &&
        !(widget.initialUser?.avatarUrl?.isNotEmpty ?? false)) {
      _showMessage('กรุณาเลือกรูปภาพโปรไฟล์');
      return;
    }
    if (_faceVector == null) {
      _showMessage('กรุณาสแกนใบหน้าก่อนส่งข้อมูล');
      return;
    }
    setState(() => _busy = true);
    try {
      String? avatarUrl = widget.initialUser?.avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await widget.service.uploadImage(_avatarFile!);
      }
      if (avatarUrl == null || avatarUrl.trim().isEmpty) {
        throw const AuthFlowException(
          'อัปโหลดรูปโปรไฟล์ไป Cloudflare R2 ไม่สำเร็จ',
        );
      }

      await widget.service.registerProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        avatarUrl: avatarUrl,
        faceVector: _faceVector!,
      );
      await widget.onProfileSaved();
    } on AuthFlowException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('บันทึกโปรไฟล์ไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.service.currentUserEmail;
    return Scaffold(
      body: ColoredBox(
        color: workBackground,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                WorkHeader(
                  title: 'ตั้งค่าโปรไฟล์',
                  subtitle: 'กรอกข้อมูลให้เรียบร้อย แล้วรอผู้ดูแลอนุมัติบัญชี',
                  action: IconButton.filledTonal(
                    onPressed: _busy ? null : widget.onSignOut,
                    icon: const Icon(Icons.logout_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -42),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: WorkCard(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AvatarPicker(
                              initialImageUrl: widget.initialUser?.avatarUrl,
                              onImagePicked: (file) =>
                                  setState(() => _avatarFile = file),
                              onError: _showMessage,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              initialValue: email,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'อีเมล',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _firstNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'ชื่อ',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'กรุณากรอกชื่อ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: const InputDecoration(
                                labelText: 'นามสกุล',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'กรุณากรอกนามสกุล';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            // ส่วนสแกนใบหน้า
                            InkWell(
                              onTap: _busy ? null : _scanFace,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: _faceVector != null
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _faceVector != null
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFE4E9F0),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _faceVector != null
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .face_retouching_natural_rounded,
                                      size: 48,
                                      color: _faceVector != null
                                          ? const Color(0xFF2563EB)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _faceVector != null
                                          ? 'ข้อมูลใบหน้าพร้อมใช้งาน'
                                          : 'แตะเพื่อสแกนใบหน้า',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _faceVector != null
                                            ? const Color(0xFF1E40AF)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    if (_faceVector == null)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Text(
                                          'จำเป็นสำหรับการลงเวลาเข้างานด้วยใบหน้า',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF637083),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _busy ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('บันทึกและส่งอนุมัติ'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_busy)
              const AppLoadingOverlay(message: 'กำลังบันทึกโปรไฟล์...'),
          ],
        ),
      ),
    );
  }
}
