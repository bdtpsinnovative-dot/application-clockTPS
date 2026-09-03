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
  List<RememberedAccount> _rememberedAccounts = const [];
  bool _showAccountChooser = false;
  bool _rememberedAccountsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedAccounts();
  }

  Future<void> _loadRememberedAccounts() async {
    try {
      final accounts = await widget.service.loadRememberedAccounts();
      if (!mounted) return;
      setState(() {
        _rememberedAccounts = accounts;
        _showAccountChooser = accounts.isNotEmpty;
        _rememberedAccountsLoaded = true;
      });
    } catch (error) {
      debugPrint('[AUTH] Could not load remembered accounts: $error');
      if (mounted) {
        setState(() => _rememberedAccountsLoaded = true);
      }
    }
  }

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

  Future<void> _quickSignIn(RememberedAccount account) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await widget.service.signInRememberedAccount(account);
      await widget.onAuthenticated();
    } on AuthApiException catch (error) {
      _showManualLogin(email: account.email, errorMessage: error.message);
    } catch (error) {
      _showManualLogin(
        email: account.email,
        errorMessage: _friendlyUnexpectedMessage(error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgetRememberedAccount(RememberedAccount account) async {
    try {
      await widget.service.forgetRememberedAccount(account.email);
      if (!mounted) return;
      setState(() {
        _rememberedAccounts = _rememberedAccounts
            .where((saved) => saved.email != account.email)
            .toList(growable: false);
        if (_rememberedAccounts.isEmpty) {
          _showAccountChooser = false;
          _emailController.clear();
          _passwordController.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('นำ ${account.label} ออกจากเครื่องนี้แล้ว')),
      );
    } catch (_) {
      _showError('ไม่สามารถลบบัญชีที่จำไว้ได้ กรุณาลองใหม่อีกครั้ง');
    }
  }

  void _showAccountOptions() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'จัดการบัญชีที่จำไว้',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: workText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _rememberedAccounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final account = _rememberedAccounts[index];
                    final avatarUrl = account.avatarUrl?.trim() ?? '';
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1),
                      tileColor: workBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: workBlue,
                        foregroundImage: avatarUrl.isEmpty
                            ? null
                            : NetworkImage(avatarUrl),
                        child: Text(
                          account.initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        account.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: workText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'ลบโปรไฟล์นี้ออก',
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _forgetRememberedAccount(account);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualLogin({String? email, String? errorMessage}) {
    if (!mounted) return;
    setState(() {
      _showAccountChooser = false;
      _isRegister = false;
      _emailController.text = email ?? '';
      _passwordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = errorMessage;
      _successMessage = null;
    });
  }

  void _showRegistration() {
    setState(() {
      _showAccountChooser = false;
      _isRegister = true;
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = null;
      _successMessage = null;
    });
  }

  void _showChooser() {
    if (_rememberedAccounts.isEmpty) return;
    setState(() {
      _showAccountChooser = true;
      _isRegister = false;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = null;
      _successMessage = null;
      _formKey.currentState?.reset();
    });
  }

  Widget _rememberedAccountCard(RememberedAccount account) {
    final avatarUrl = account.avatarUrl?.trim() ?? '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _busy ? null : () => _quickSignIn(account),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: workBlue,
                  foregroundImage: avatarUrl.isEmpty
                      ? null
                      : NetworkImage(avatarUrl),
                  child: Text(
                    account.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: workText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      isDense: true,
      prefixIcon: Icon(icon, color: workMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: workBlue, width: 1.4),
      ),
    );
  }

  String _friendlyUnexpectedMessage(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('network') ||
        value.contains('socket') ||
        value.contains('connection') ||
        value.contains('failed host lookup') ||
        value.contains('clientexception') ||
        value.contains('os error') ||
        value.contains('operation not permitted') ||
        value.contains('errno')) {
      return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสัญญาณหรือ URL แล้วลองอีกครั้ง';
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
    if (!_rememberedAccountsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FD),
        body: Center(child: AnimatedAppLogo(size: 58, heroEnabled: true)),
      );
    }

    return Scaffold(
      backgroundColor: workBackground,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF3F7FF), Colors.white],
                  stops: [0, 0.72],
                ),
              ),
            ),
          ),
          Positioned(
            top: -150,
            right: -110,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      workSky.withValues(alpha: 0.16),
                      workSky.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  20,
                  18,
                  _showAccountChooser ? 88 : 20,
                ),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: EdgeInsets.symmetric(
                    horizontal: _showAccountChooser ? 2 : 22,
                    vertical: _showAccountChooser ? 12 : 24,
                  ),
                  decoration: BoxDecoration(
                    color: _showAccountChooser
                        ? Colors.transparent
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showAccountChooser
                          ? Colors.transparent
                          : const Color(0xFFE8EDF5),
                    ),
                    boxShadow: _showAccountChooser
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0x0A0F172A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const AnimatedAppLogo(
                                size: 58,
                                heroEnabled: true,
                              ),
                              if (!_showAccountChooser &&
                                  _rememberedAccounts.isNotEmpty)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    tooltip: 'กลับไปเลือกบัญชี',
                                    onPressed: _busy ? null : _showChooser,
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: workText,
                                      size: 19,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showAccountChooser
                              ? 'เลือกบัญชี'
                              : _isRegister
                              ? 'สร้างบัญชี'
                              : 'เข้าสู่ระบบ',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: workText,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _showAccountChooser
                              ? 'เลือกบัญชีเพื่อเข้าสู่ระบบ'
                              : _isRegister
                              ? 'สมัครใช้งาน Clock in TPS'
                              : 'ลงชื่อเข้าใช้ Clock in TPS',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: workMuted,
                            fontSize: 13,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _FeedbackBanner(
                            message: _errorMessage!,
                            isError: true,
                          ),
                        ],
                        if (_successMessage != null) ...[
                          const SizedBox(height: 16),
                          _FeedbackBanner(message: _successMessage!),
                        ],
                        const SizedBox(height: 22),
                        if (_showAccountChooser) ...[
                          for (
                            var index = 0;
                            index < _rememberedAccounts.length;
                            index++
                          ) ...[
                            _rememberedAccountCard(_rememberedAccounts[index]),
                            if (index < _rememberedAccounts.length - 1)
                              const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: workBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _busy ? null : _showManualLogin,
                            child: const Text(
                              'ใช้บัญชีอื่น',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: _fieldDecoration(
                              label: 'อีเมล',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!email.contains('@') ||
                                  !email.contains('.')) {
                                return 'กรุณากรอกอีเมลให้ถูกต้อง';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
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
                            decoration: _fieldDecoration(
                              label: 'รหัสผ่าน',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                visualDensity: VisualDensity.compact,
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
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('ตกลง'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text(
                                  'ลืมรหัสผ่าน?',
                                  style: TextStyle(
                                    color: workMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          if (_isRegister) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: _fieldDecoration(
                                label: 'ยืนยันรหัสผ่าน',
                                icon: Icons.verified_user_outlined,
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'รหัสผ่านไม่ตรงกัน';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: workBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _busy ? null : _submit,
                            child: Text(
                              _isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: workBlue,
                            ),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showAccountChooser)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 2,
              right: 6,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'จัดการบัญชีที่จำไว้',
                onPressed: _busy ? null : _showAccountOptions,
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: workText,
                  size: 26,
                ),
              ),
            ),
          if (_showAccountChooser)
            Positioned(
              left: 18,
              right: 18,
              bottom: MediaQuery.paddingOf(context).bottom + 10,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: workBlue,
                        backgroundColor: Colors.white.withValues(alpha: 0.94),
                        side: const BorderSide(color: workBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _busy ? null : _showRegistration,
                      child: const Text(
                        'สร้างบัญชีใหม่',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
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
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
