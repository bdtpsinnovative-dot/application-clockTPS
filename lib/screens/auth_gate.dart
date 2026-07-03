import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/app_loading_view.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'pending_approval_page.dart';
import 'profile_setup_page.dart';

enum _GateState { loading, signedOut, profileRequired, pending, active, error }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthFlowService _service = AuthFlowService();
  _GateState _state = _GateState.loading;
  AppUser? _user;
  String _errorMessage = '';
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
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
        _setState(
          user.status == 'active' ? _GateState.active : _GateState.pending,
        );
      }
    } on ProfileRequiredException {
      _setState(_GateState.profileRequired);
    } on SessionExpiredException {
      await _service.signOut();
      _setState(_GateState.signedOut);
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

  void _setState(_GateState value) {
    if (mounted) setState(() => _state = value);
  }

  Future<void> _signOut() async {
    await _service.signOut();
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
