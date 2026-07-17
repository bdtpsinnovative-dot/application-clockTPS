import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/app_loading_view.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'pending_approval_page.dart';
import 'profile_setup_page.dart';

enum _GateState { loading, signedOut, profileRequired, pending, active, error, suspended }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.service});
  final AuthFlowService? service;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthFlowService _service;
  _GateState _state = _GateState.loading;
  AppUser? _user;
  String _errorMessage = '';
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AuthFlowService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAndResolve());
  }

  Future<void> _restoreAndResolve() async {
    try {
      await _service.restoreSession();
      await _resolve();
    } catch (_) {
      await _service.signOut();
      _setState(_GateState.signedOut);
    }
  }

  Future<void> _resolve() async {
    if (_resolving || !mounted) return;
    _resolving = true;

    if (!_service.hasSession) {
      _setState(_GateState.signedOut);
      _resolving = false;
      return;
    }

    _setState(_GateState.loading);
    try {
      final user = await _service.getMe();
      _user = user;
      if (!user.isProfileComplete) {
        _setState(_GateState.profileRequired);
      } else {
        if (user.status == 'disabled' || user.status == 'suspended') {
          _setState(_GateState.suspended);
          _resolving = false;
          return;
        }
        if (user.status == 'active') {
          try {
            final deviceId = await _getDeviceId();
            await _service.bindDevice(deviceId);
          } catch (e) {
            debugPrint('Device binding failed: $e');
            _errorMessage = e.toString()
                .replaceAll('Exception: ', '')
                .replaceAll('AuthFlowException: ', '');
            _setState(_GateState.error);
            _resolving = false;
            return;
          }
        }
        _setState(
          user.status == 'active' ? _GateState.active : _GateState.pending,
        );
      }
    } on ProfileRequiredException {
      _user = null;
      _setState(_GateState.profileRequired);
    } on SessionExpiredException {
      await _service.signOut();
      _setState(_GateState.signedOut);
    } on AccountSuspendedException {
      _setState(_GateState.suspended);
    } on ApprovalPendingException {
      _setState(_GateState.pending);
    } on AuthFlowException catch (error) {
      _errorMessage = error.message;
      _setState(_GateState.error);
    } catch (_) {
      _errorMessage = 'เกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่';
      _setState(_GateState.error);
    } finally {
      _resolving = false;
    }
  }

  Future<String> _getDeviceId() async {
    if (AuthFlowService.mockDeviceId != null) {
      return AuthFlowService.mockDeviceId!;
    }
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios_unknown_device';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isMacOS) {
      final macosInfo = await deviceInfo.macOsInfo;
      return macosInfo.systemGUID ?? 'macos_unknown_device';
    }
    return 'unknown_device';
  }

  void _setState(_GateState value) {
    if (mounted) setState(() => _state = value);
  }

  Future<void> _signOut() async {
    await _service.signOut();
    _user = null;
    _setState(_GateState.signedOut);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _GateState.loading => const AppLoadingView(
        message: 'กำลังตรวจสอบบัญชี...',
      ),
      _GateState.signedOut => LoginPage(
        service: _service,
        onAuthenticated: _resolve,
      ),
      _GateState.profileRequired => ProfileSetupPage(
        service: _service,
        initialUser: _user,
        onProfileSaved: _resolve,
        onSignOut: _signOut,
      ),
      _GateState.pending => PendingApprovalPage(
        onCheckStatus: _resolve,
        onSignOut: _signOut,
      ),
      _GateState.active => HomePage(
        user: _user!,
        service: _service,
        onSignOut: _signOut,
      ),
      _GateState.error => _ConnectionErrorPage(
        message: _errorMessage,
        onRetry: _resolve,
        onSignOut: _signOut,
      ),
      _GateState.suspended => _SuspendedPage(
        onSignOut: _signOut,
      ),
    };
  }
}

class _ConnectionErrorPage extends StatelessWidget {
  const _ConnectionErrorPage({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 72,
                color: Color(0xFF637083),
              ),
              const SizedBox(height: 24),
              Text(
                'เชื่อมต่อระบบไม่ได้',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('ลองใหม่'),
              ),
              TextButton(onPressed: onSignOut, child: const Text('ออกจากระบบ')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuspendedPage extends StatelessWidget {
  const _SuspendedPage({required this.onSignOut});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'บัญชีถูกระงับ',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'บัญชีของคุณถูกระงับการใช้งาน\nกรุณาติดต่อผู้ดูแลระบบ',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSignOut,
                  child: const Text('ไปหน้า Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
