import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/work_models.dart';

class AuthFlowService {
  AuthFlowService({Dio? dio, FlutterSecureStorage? storage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
              contentType: Headers.jsonContentType,
            ),
          ),
      _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _accessToken;
  String? _authId;
  String? _email;
  AppUser? _currentAppUser;

  static const _tokenKey = 'clock_in_tps_access_token';
  static const _authIdKey = 'clock_in_tps_auth_id';
  static const _emailKey = 'clock_in_tps_email';

  bool get hasSession => _accessToken?.isNotEmpty ?? false;
  String get currentUserEmail => _email ?? '';

  Future<void> signIn({required String email, required String password}) async {
    _currentAppUser = null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      await _captureSession(
        response.data,
        fallbackEmail: email,
        tokenRequired: true,
      );
    } on DioException catch (error) {
      throw AuthApiException.fromDio(error);
    }
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    _currentAppUser = null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/signup',
        data: {'email': email.trim(), 'password': password},
      );
      await _captureSession(response.data, fallbackEmail: email);
      return SignUpResult(requiresEmailConfirmation: !hasSession);
    } on DioException catch (error) {
      throw AuthApiException.fromDio(error);
    }
  }

  Future<void> restoreSession() async {
    _accessToken = await _storage.read(key: _tokenKey);
    _authId = await _storage.read(key: _authIdKey);
    _email = await _storage.read(key: _emailKey);
  }

  Future<void> signOut() async {
    _accessToken = null;
    _authId = null;
    _email = null;
    _currentAppUser = null;
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _authIdKey),
      _storage.delete(key: _emailKey),
    ]);
  }

  Future<AppUser> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/users/me',
        options: Options(headers: _authorizationHeaders()),
      );
      final user = _userFromResponse(response.data);
      _currentAppUser = user;
      return user;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = _apiMessage(error);
      if (statusCode == 404) {
        _currentAppUser = null;
        throw const ProfileRequiredException();
      }
      if (statusCode == 401) {
        if (message.contains('ไม่พบข้อมูลผู้ใช้')) {
          throw const ProfileRequiredException();
        }
        throw SessionExpiredException(message);
      }
      if (statusCode == 403) {
        throw ApprovalPendingException(message);
      }
      throw ApiUnavailableException(message);
    }
  }

  Future<String> uploadImage(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          contentType: DioMediaType('image', 'webp'),
        ),
      });

      // ใช้ authorizedGet ถ้า Endpoint เป็น Private หรือไม่ใช้ก็ได้ถ้าเปิด Public
      // สำหรับ register อาจจะยังไม่มี session ดังนั้นควรเป็น endpoint public หรือใช้ _dio ตรงๆ
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/upload',
        data: formData,
        options: Options(headers: _authorizationHeaders()),
      );

      final url = response.data?['url'] as String?;
      if (response.data?['ok'] == true &&
          url != null &&
          url.trim().isNotEmpty) {
        return url;
      }
      throw const AuthFlowException('Cloudflare R2 ไม่ได้ส่ง URL รูปภาพกลับมา');
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  Future<AppUser> registerProfile({
    required String firstName,
    required String lastName,
    required String avatarUrl,
    required List<double> faceVector,
  }) async {
    if (_authId == null || _email == null) {
      throw const AuthFlowException(
        'API ไม่ได้ส่งข้อมูลผู้ใช้กลับมา กรุณาล็อกอินใหม่',
      );
    }
    try {
      final data = {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'avatar_url': avatarUrl.trim(),
        'face_vector': faceVector,
      };
      if (_currentAppUser != null) {
        await _dio.put<Map<String, dynamic>>(
          '/api/users/me/profile',
          data: data,
          options: Options(headers: _authorizationHeaders()),
        );
        return getMe();
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'auth_id': _authId, 'email': _email, ...data},
      );
      final user = _userFromResponse(response.data);
      _currentAppUser = user;
      return user;
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  Future<void> updateFaceVector(List<double> faceVector) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/api/users/me/face',
        data: {'face_vector': faceVector},
        options: Options(headers: _authorizationHeaders()),
      );
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  Future<AttendanceRecord?> getAttendance(DateTime date) async {
    final response = await _authorizedGet(
      '/api/attendance',
      queryParameters: {'date': _dateValue(date)},
    );
    final data = response['data'];
    return data is Map<String, dynamic>
        ? AttendanceRecord.fromJson(data)
        : null;
  }

  Future<List<AttendanceRecord>> getAttendanceHistory(
    int year,
    int month,
  ) async {
    final response = await _authorizedGet(
      '/api/attendance/history',
      queryParameters: {'year': year, 'month': month},
    );
    return _listData(
      response,
    ).map(AttendanceRecord.fromJson).toList(growable: false);
  }

  Future<List<WorkRequestRecord>> getMyRequests() async {
    final responses = await Future.wait([
      _authorizedGet('/api/leaves'),
      _authorizedGet('/api/offsite'),
    ]);
    final requests = <WorkRequestRecord>[
      ..._listData(responses[0]).map(WorkRequestRecord.leave),
      ..._listData(responses[1]).map(WorkRequestRecord.offsite),
    ];
    requests.sort((a, b) => b.date.compareTo(a.date));
    return requests;
  }

  Future<void> createRequest({
    required String type,
    required DateTime date,
    required String reason,
    required String duration,
  }) async {
    if (type == 'ออกหน้างาน') {
      await _authorizedPost(
        '/api/offsite',
        data: {'date': _dateValue(date), 'reason': reason.trim()},
      );
      return;
    }
    await _authorizedPost(
      '/api/leaves',
      data: {
        'date': _dateValue(date),
        'leave_type': type,
        'duration': duration,
        'reason': reason.trim(),
      },
    );
  }

  Future<List<HolidayRecord>> getHolidays(int year) async {
    final response = await _authorizedGet(
      '/api/holidays',
      queryParameters: {'year': year},
    );
    return _listData(
      response,
    ).map(HolidayRecord.fromJson).toList(growable: false);
  }

  Future<void> _captureSession(
    Map<String, dynamic>? body, {
    required String fallbackEmail,
    bool tokenRequired = false,
  }) async {
    final root = body ?? const <String, dynamic>{};
    final data = root['data'] is Map<String, dynamic>
        ? root['data'] as Map<String, dynamic>
        : root;
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

    _accessToken =
        data['access_token'] as String? ??
        data['token'] as String? ??
        root['access_token'] as String? ??
        root['token'] as String?;
    _authId =
        user['auth_id'] as String? ??
        user['id'] as String? ??
        data['auth_id'] as String?;
    _email =
        user['email'] as String? ??
        data['email'] as String? ??
        fallbackEmail.trim();

    final claims = _decodeJwtClaims(_accessToken);
    _authId ??= claims['sub'] as String?;
    _email ??= claims['email'] as String?;

    if (tokenRequired && !hasSession) {
      throw const AuthFlowException(
        'รูปแบบข้อมูลจาก /auth/login ไม่ถูกต้อง: ไม่พบ access_token',
      );
    }
    if (hasSession) {
      await Future.wait([
        _storage.write(key: _tokenKey, value: _accessToken),
        _storage.write(key: _authIdKey, value: _authId),
        _storage.write(key: _emailKey, value: _email),
      ]);
    }
  }

  Map<String, dynamic> _decodeJwtClaims(String? token) {
    if (token == null) return const {};
    try {
      final parts = token.split('.');
      if (parts.length != 3) return const {};
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final value = jsonDecode(payload);
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  Map<String, String> _authorizationHeaders() {
    if (!hasSession) {
      throw const AuthFlowException('ไม่พบ access token กรุณาล็อกอินใหม่');
    }
    return {'Authorization': 'Bearer $_accessToken'};
  }

  Future<Map<String, dynamic>> _authorizedGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: _authorizationHeaders()),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  Future<Map<String, dynamic>> _authorizedPost(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(headers: _authorizationHeaders()),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  List<Map<String, dynamic>> _listData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  String _dateValue(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  AppUser _userFromResponse(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw const AuthFlowException('รูปแบบข้อมูลผู้ใช้จาก API ไม่ถูกต้อง');
    }
    return AppUser.fromJson(data);
  }

  String _apiMessage(DioException error) {
    final body = error.response?.data;
    if (body is Map && body['error'] is String) {
      return body['error'] as String;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'เชื่อมต่อ API ไม่ได้ กรุณาตรวจ IP และเซิร์ฟเวอร์';
    }
    return 'เกิดข้อผิดพลาดจาก API กรุณาลองใหม่';
  }
}

class SignUpResult {
  const SignUpResult({required this.requiresEmailConfirmation});

  final bool requiresEmailConfirmation;
}

class AuthApiException extends AuthFlowException {
  const AuthApiException(super.message);

  factory AuthApiException.fromDio(DioException error) {
    final body = error.response?.data;
    final message = body is Map && body['error'] is String
        ? body['error'] as String
        : error.message ?? '';
    final value = message.toLowerCase();
    final status = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const AuthApiException(
        'เชื่อมต่อ API ไม่ได้ กรุณาตรวจ IP และอินเทอร์เน็ต',
      );
    }
    if (status == 401 ||
        value.contains('invalid login') ||
        value.contains('invalid credentials') ||
        value.contains('user not found')) {
      return const AuthApiException(
        'ไม่พบบัญชีนี้ในระบบ หรือรหัสผ่านไม่ถูกต้อง',
      );
    }
    if (value.contains('email not confirmed')) {
      return const AuthApiException('กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ');
    }
    if (status == 409 || value.contains('already registered')) {
      return const AuthApiException('อีเมลนี้สมัครสมาชิกแล้ว กรุณาเข้าสู่ระบบ');
    }
    if (status == 429 || value.contains('rate limit')) {
      return const AuthApiException(
        'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่',
      );
    }
    return AuthApiException(
      message.isEmpty ? 'API ขัดข้องชั่วคราว กรุณาลองใหม่' : message,
    );
  }
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileRequiredException extends AuthFlowException {
  const ProfileRequiredException() : super('กรุณาตั้งค่าโปรไฟล์ก่อนใช้งาน');
}

class SessionExpiredException extends AuthFlowException {
  const SessionExpiredException(super.message);
}

class ApprovalPendingException extends AuthFlowException {
  const ApprovalPendingException(super.message);
}

class ApiUnavailableException extends AuthFlowException {
  const ApiUnavailableException(super.message);
}
