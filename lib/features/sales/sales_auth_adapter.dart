import '../../models/app_user.dart';
import '../../services/auth_flow_service.dart';

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.branchId = 1,
    this.branchName = 'สาขาหลัก',
  });

  final String id;
  final String? email;
  final String? fullName;
  final String role;
  final int? branchId;
  final String? branchName;

  factory AuthenticatedUser.fromAppUser(AppUser user) {
    return AuthenticatedUser(
      id: user.id,
      email: user.email,
      fullName: user.fullName.isNotEmpty
          ? user.fullName
          : (user.nickname.isNotEmpty ? user.nickname : user.email),
      role: user.role,
      branchId: user.branchId,
      branchName: user.branchName.isNotEmpty ? user.branchName : 'สาขาหลัก',
    );
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthService {
  AuthService(this._flowService);

  final AuthFlowService _flowService;

  Future<String?> accessToken() async {
    return _flowService.getValidAccessToken();
  }
}
