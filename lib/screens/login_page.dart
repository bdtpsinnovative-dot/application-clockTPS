import 'package:flutter/material.dart';

import '../services/auth_flow_service.dart';
import '../widgets/animated_app_logo.dart';
import '../widgets/app_loading_view.dart';
import '../widgets/work_ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.service,
    required this.onAuthenticated,
  });

  final AuthFlowService service;
  final Future<void> Function() onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      if (_isRegister) {
        final response = await widget.service.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        if (response.requiresEmailConfirmation) {
          setState(() {
            _isRegister = false;
            _successMessage =
                'สมัครสำเร็จ กรุณายืนยันอีเมล แล้วกลับมาเข้าสู่ระบบ';
          });
          return;
        }
      } else {
        await widget.service.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      await widget.onAuthenticated();
    } on AuthApiException catch (error) {
      if (error.message == 'บัญชีของคุณถูกระงับการใช้งาน') {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('บัญชีถูกระงับ', textAlign: TextAlign.center),
              content: const Text(
                'บัญชีของคุณถูกระงับการใช้งาน\nกรุณาติดต่อผู้ดูแลระบบ',
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ตกลง'),
                ),
              ],
            ),
          );
        }
      } else {
        _showError(error.message);
      }
    } catch (error) {
      _showError(_friendlyUnexpectedMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyUnexpectedMessage(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('network') ||
        value.contains('socket') ||
        value.contains('connection') ||
        value.contains('failed host lookup') ||
        value.contains('clientexception')) {
      return 'อินเทอร์เน็ตมีปัญหา กรุณาตรวจสัญญาณแล้วลองอีกครั้ง';
    }
    return 'ระบบขัดข้องชั่วคราว กรุณาลองใหม่อีกครั้ง';
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _successMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: workBackground,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.sizeOf(context).height * 0.4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [workBlue, workSky],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: WorkCard(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(child: AnimatedAppLogo(size: 90, heroEnabled: true)),
                        const SizedBox(height: 20),
                        Text(
                          _isRegister ? 'สมัครสมาชิก' : 'ยินดีต้อนรับ',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: workText,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isRegister
                              ? 'สร้างบัญชี Clock in TPS'
                              : 'เข้าสู่ระบบเพื่อเริ่มลงเวลา',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: workMuted, fontSize: 14),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 20),
                          _FeedbackBanner(message: _errorMessage!, isError: true),
                        ],
                        if (_successMessage != null) ...[
                          const SizedBox(height: 20),
                          _FeedbackBanner(message: _successMessage!),
                        ],
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: 'อีเมล',
                            prefixIcon: const Icon(Icons.email_outlined, color: workMuted),
                            filled: true,
                            fillColor: workBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'กรุณากรอกอีเมลให้ถูกต้อง';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: _isRegister
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: _isRegister
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          onFieldSubmitted: (_) {
                            if (!_isRegister) _submit();
                          },
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: workMuted),
                            filled: true,
                            fillColor: workBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: workMuted,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                            }
                            return null;
                          },
                        ),
                        if (!_isRegister)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('ลืมรหัสผ่าน'),
                                    content: const Text(
                                      'กรุณาติดต่อฝ่ายบุคคล (HR) ของบริษัทเพื่อรีเซ็ตรหัสผ่านของคุณ หรือตรวจสอบอีเมลยืนยันการตั้งค่าจากระบบหลังบ้าน',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('ตกลง'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text(
                                'ลืมรหัสผ่าน?',
                                style: TextStyle(color: workMuted),
                              ),
                            ),
                          ),
                        if (_isRegister) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'ยืนยันรหัสผ่าน',
                              prefixIcon: const Icon(Icons.verified_user_outlined, color: workMuted),
                              filled: true,
                              fillColor: workBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'รหัสผ่านไม่ตรงกัน';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 28),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: workBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _busy ? null : _submit,
                          child: Text(_isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: workBlue),
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _isRegister = !_isRegister;
                                  _errorMessage = null;
                                  _successMessage = null;
                                  _formKey.currentState?.reset();
                                }),
                          child: Text(
                            _isRegister
                                ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                                : 'ยังไม่มีบัญชี? สมัครสมาชิก',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_busy)
            AppLoadingOverlay(
              message: _isRegister
                  ? 'กำลังสมัครสมาชิก...'
                  : 'กำลังเข้าสู่ระบบ...',
            ),
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC62828) : const Color(0xFF087F72);
    final background = isError
        ? const Color(0xFFFFEBEE)
        : const Color(0xFFE7F8F5);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
