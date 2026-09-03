import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/work_models.dart';

class AuthFlowService {
  @visibleForTesting
  static String? mockDeviceId;
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
      _storage = storage ?? const FlutterSecureStorage() {
    _setupInterceptors();
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _accessToken;
  String? _refreshToken;
  String? _authId;
  String? _email;
  AppUser? _currentAppUser;

  static const _tokenKey = 'clock_in_tps_access_token';
  static const _refreshTokenKey = 'clock_in_tps_refresh_token';
  static const _authIdKey = 'clock_in_tps_auth_id';
  static const _emailKey = 'clock_in_tps_email';
  static const _savedPassKey = 'clock_in_tps_credential_p';
  static const _rememberedAvatarKey = 'clock_in_tps_remembered_avatar';
  static const _rememberedNameKey = 'clock_in_tps_remembered_name';
  static const _rememberedNicknameKey = 'clock_in_tps_remembered_nickname';
  static const _rememberedAccountsKey = 'clock_in_tps_remembered_accounts_v1';
  static const _signedOutKey = 'clock_in_tps_explicitly_signed_out';
  static const _authRetryKey = 'clock_in_tps_auth_retry';

  bool get hasSession =>
      (_accessToken?.isNotEmpty ?? false) ||
      (_refreshToken?.isNotEmpty ?? false);
  String get currentUserEmail => _email ?? '';
  String get currentUserId => _authId ?? '';
  String get baseUrl => AppConfig.apiBaseUrl;
  AppUser? get currentUser => _currentAppUser;

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
      await _storage.write(key: _savedPassKey, value: password);
      await _rememberCredential(email: email, password: password);
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
      if (hasSession) {
        await _storage.write(key: _savedPassKey, value: password);
        await _rememberCredential(email: email, password: password);
      }
      return SignUpResult(requiresEmailConfirmation: !hasSession);
    } on DioException catch (error) {
      throw AuthApiException.fromDio(error);
    }
  }

  Future<void> restoreSession() async {
    _accessToken = await _storage.read(key: _tokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
    _authId = await _storage.read(key: _authIdKey);
    _email = await _storage.read(key: _emailKey);

    if (await _storage.read(key: _signedOutKey) == 'true') {
      _accessToken = null;
      _refreshToken = null;
      _authId = null;
      return;
    }

    if (_isJwtExpired(_accessToken)) {
      final result = await _refreshSession();
      if (result == _SessionRefreshResult.invalid) {
        throw const SessionExpiredException(
          'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง',
        );
      }
      if (result == _SessionRefreshResult.unavailable && hasSession) {
        throw const ApiUnavailableException(
          'ไม่สามารถต่ออายุเซสชันได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
        );
      }
    }
  }

  Future<void> signOut({bool forgetAccount = false}) async {
    _accessToken = null;
    _refreshToken = null;
    _authId = null;
    _email = null;
    _currentAppUser = null;
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _authIdKey),
      _storage.write(key: _signedOutKey, value: 'true'),
      if (forgetAccount) _storage.delete(key: _emailKey),
      if (forgetAccount) _storage.delete(key: _savedPassKey),
      if (forgetAccount) _storage.delete(key: _rememberedAvatarKey),
      if (forgetAccount) _storage.delete(key: _rememberedNameKey),
      if (forgetAccount) _storage.delete(key: _rememberedNicknameKey),
      if (forgetAccount) _storage.delete(key: _rememberedAccountsKey),
    ]);
  }

  Future<List<RememberedAccount>> loadRememberedAccounts() async {
    final credentials = await _readRememberedCredentials();
    return credentials.map((value) => value.account).toList(growable: false);
  }

  Future<void> signInRememberedAccount(RememberedAccount account) async {
    final credentials = await _readRememberedCredentials();
    final normalizedEmail = account.email.trim().toLowerCase();
    _RememberedCredential? selected;
    for (final credential in credentials) {
      if (credential.email.toLowerCase() == normalizedEmail) {
        selected = credential;
        break;
      }
    }
    if (selected == null || selected.password.isEmpty) {
      throw const AuthApiException('ไม่พบบัญชีที่บันทึกไว้ในเครื่อง');
    }
    await signIn(email: selected.email, password: selected.password);
  }

  Future<void> forgetRememberedAccount(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credentials = await _readRememberedCredentials();
    final remaining = credentials
        .where((value) => value.email.toLowerCase() != normalizedEmail)
        .toList(growable: false);
    await _writeRememberedCredentials(remaining);

    final currentRememberedEmail = await _storage.read(key: _emailKey);
    if (currentRememberedEmail?.trim().toLowerCase() == normalizedEmail) {
      await Future.wait([
        _storage.delete(key: _emailKey),
        _storage.delete(key: _savedPassKey),
        _storage.delete(key: _rememberedAvatarKey),
        _storage.delete(key: _rememberedNameKey),
        _storage.delete(key: _rememberedNicknameKey),
      ]);
      _email = null;
    }
  }

  Future<AppUser> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/users/me',
        options: Options(headers: _authorizationHeaders()),
      );
      final user = _userFromResponse(response.data);
      _currentAppUser = user;
      await Future.wait([
        _storage.delete(key: _rememberedNameKey),
        _storage.write(
          key: _rememberedNicknameKey,
          value: user.nickname.trim(),
        ),
        if (user.avatarUrl?.trim().isNotEmpty == true)
          _storage.write(
            key: _rememberedAvatarKey,
            value: user.avatarUrl!.trim(),
          ),
      ]);
      await _updateRememberedProfile(
        email: user.email,
        nickname: user.nickname,
        avatarUrl: user.avatarUrl,
      );
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
        if (message.toLowerCase().contains('disabled') ||
            message.toLowerCase().contains('suspended') ||
            message.contains('ระงับ')) {
          throw AccountSuspendedException(message);
        }
        throw ApprovalPendingException(message);
      }
      throw ApiUnavailableException(message);
    }
  }

  Future<String> uploadImage(File file) async {
    try {
      final pathLower = file.path.toLowerCase();
      DioMediaType mediaType = DioMediaType('image', 'webp');
      if (pathLower.endsWith('.pdf')) {
        mediaType = DioMediaType('application', 'pdf');
      } else if (pathLower.endsWith('.png')) {
        mediaType = DioMediaType('image', 'png');
      } else if (pathLower.endsWith('.jpg') || pathLower.endsWith('.jpeg')) {
        mediaType = DioMediaType('image', 'jpeg');
      } else if (pathLower.endsWith('.doc') || pathLower.endsWith('.docx')) {
        mediaType = DioMediaType('application', 'msword');
      } else if (pathLower.endsWith('.xls') || pathLower.endsWith('.xlsx')) {
        mediaType = DioMediaType('application', 'vnd.ms-excel');
      } else if (pathLower.endsWith('.txt')) {
        mediaType = DioMediaType('text', 'plain');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, contentType: mediaType),
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
    String nickname = '',
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
        'nickname': nickname.trim(),
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

  Future<AppUser> updateProfileInfo({
    required String firstName,
    required String lastName,
    String nickname = '',
    required String avatarUrl,
  }) async {
    try {
      final data = {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'nickname': nickname.trim(),
        'avatar_url': avatarUrl.trim(),
      };
      await _dio.put<Map<String, dynamic>>(
        '/api/users/me/profile/info',
        data: data,
        options: Options(headers: _authorizationHeaders()),
      );
      final user = await getMe();
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

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/api/users/me/password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
        options: Options(headers: _authorizationHeaders()),
      );
      await _storage.write(key: _savedPassKey, value: newPassword);
      final email = _email ?? await _storage.read(key: _emailKey);
      if (email != null && email.trim().isNotEmpty) {
        await _rememberCredential(email: email, password: newPassword);
      }
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  Future<String> getCheckInMode() async {
    try {
      final response = await _authorizedGet('/api/settings/checkin-mode');
      return response['checkin_mode'] as String? ?? 'face';
    } catch (_) {
      return 'face'; // fallback default
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

  Future<List<LeaveBalanceRecord>> getLeaveBalances(int year) async {
    final response = await _authorizedGet(
      '/api/leaves/quota',
      queryParameters: {'year': year},
    );
    return _listData(
      response,
    ).map(LeaveBalanceRecord.fromJson).toList(growable: false);
  }

  Future<void> createRequest({
    required String type,
    required DateTime date,
    required String reason,
    required String duration,
    String? medicalCertUrl,
    DateTime? swapDate,
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
        'medical_cert_url': ?medicalCertUrl,
        'swap_date': ?swapDate == null ? null : _dateValue(swapDate),
      },
    );
  }

  Future<void> updateRequest({
    required String id,
    required bool isOffsite,
    required String type,
    required DateTime date,
    required String reason,
    required String duration,
    String? medicalCertUrl,
    DateTime? swapDate,
  }) async {
    if (isOffsite) {
      await _authorizedPut(
        '/api/offsite/$id',
        data: {'date': _dateValue(date), 'reason': reason.trim()},
      );
      return;
    }
    await _authorizedPut(
      '/api/leaves/$id',
      data: {
        'date': _dateValue(date),
        'leave_type': type,
        'duration': duration,
        'reason': reason.trim(),
        'medical_cert_url': ?medicalCertUrl,
        'swap_date': ?swapDate == null ? null : _dateValue(swapDate),
      },
    );
  }

  Future<void> deleteRequest({
    required String id,
    required bool isOffsite,
  }) async {
    if (isOffsite) {
      await _authorizedDelete('/api/offsite/$id');
      return;
    }
    await _authorizedDelete('/api/leaves/$id');
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

  Future<List<Map<String, dynamic>>> getWorkLocations() async {
    final response = await _authorizedGet('/api/locations');
    final data = response['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<void> bindDevice(String deviceId) async {
    await _authorizedPut('/api/users/me/device', data: {'device_id': deviceId});
  }

  // --- Admin API Methods ---

  Future<Map<String, dynamic>> _authorizedPatch(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(headers: _authorizationHeaders()),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  Future<List<AppUser>> getAdminUsers() async {
    final response = await _authorizedGet('/api/users');
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList(growable: false);
  }

  Future<List<WorkRequestRecord>> getAdminPendingRequests() async {
    final response = await _authorizedGet('/admin/requests/pending');
    final data = response['data'];
    if (data is! Map<String, dynamic>) return const [];

    final leavesList = data['leaves'] as List? ?? [];
    final offsiteList = data['offsite'] as List? ?? [];

    final requests = <WorkRequestRecord>[
      ...leavesList.whereType<Map<String, dynamic>>().map(
        WorkRequestRecord.leave,
      ),
      ...offsiteList.whereType<Map<String, dynamic>>().map(
        WorkRequestRecord.offsite,
      ),
    ];
    requests.sort((a, b) => b.date.compareTo(a.date));
    return requests;
  }

  Future<List<WorkRequestRecord>> getAdminAllRequests() async {
    final response = await _authorizedGet('/admin/requests/all');
    final data = response['data'];
    if (data is! Map<String, dynamic>) return const [];

    final leavesList = data['leaves'] as List? ?? [];
    final offsiteList = data['offsite'] as List? ?? [];

    final requests = <WorkRequestRecord>[
      ...leavesList.whereType<Map<String, dynamic>>().map(
        WorkRequestRecord.leave,
      ),
      ...offsiteList.whereType<Map<String, dynamic>>().map(
        WorkRequestRecord.offsite,
      ),
    ];
    requests.sort((a, b) => b.date.compareTo(a.date));
    return requests;
  }

  Future<List<AttendanceRecord>> getAdminAttendance(DateTime date) async {
    final response = await _authorizedGet(
      '/admin/attendance',
      queryParameters: {'date': _dateValue(date)},
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRecord.fromJson)
        .toList(growable: false);
  }

  Future<AttendanceSummary> getAttendanceSummary(DateTime date) async {
    final response = await _authorizedGet(
      '/api/attendance/summary',
      queryParameters: {'date': _dateValue(date)},
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return const AttendanceSummary(
        totalEmployees: 0,
        attendedToday: 0,
        lateToday: 0,
      );
    }
    return AttendanceSummary.fromJson(data);
  }

  Future<List<AdminHistoryRecord>> getAdminMonthlyHistory(String month) async {
    final response = await _authorizedGet(
      '/admin/history/monthly',
      queryParameters: {'month': month},
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AdminHistoryRecord.fromJson)
        .toList(growable: false);
  }

  Future<void> approveUser(String id) async {
    await _authorizedPatch('/admin/users/$id/approve', data: {});
  }

  Future<void> updateUserWorkSchedule({
    required String userId,
    required String workStartTime,
    required String workEndTime,
  }) async {
    await _authorizedPut(
      '/admin/users/$userId/work-schedule',
      data: {'work_start_time': workStartTime, 'work_end_time': workEndTime},
    );
  }

  Future<AttendanceRecord> updateAttendanceAdmin({
    required String attendanceId,
    required DateTime checkInAt,
    DateTime? checkOutAt,
    String? status,
  }) async {
    final response = await _authorizedPatch(
      '/admin/attendance/$attendanceId',
      data: {
        'check_in_at': checkInAt.toUtc().toIso8601String(),
        'check_out_at': checkOutAt?.toUtc().toIso8601String(),
        'status': ?status,
      },
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return AttendanceRecord.fromJson(data);
    }
    throw const AuthFlowException('ข้อมูลตอบกลับจากการแก้ไขเวลาไม่ถูกต้อง');
  }

  Future<void> updateLeaveStatusAdmin(String id, String status) async {
    await _authorizedPatch(
      '/admin/leaves/$id/status',
      data: {'status': status},
    );
  }

  Future<void> updateOffsiteStatusAdmin(String id, String status) async {
    await _authorizedPatch(
      '/admin/offsite/$id/status',
      data: {'status': status},
    );
  }

  Future<void> disableUser(String id) async {
    await _authorizedPatch('/admin/users/$id/disable', data: {});
  }

  Future<void> unbindDevice(String id) async {
    await _authorizedPatch('/admin/users/$id/unbind-device', data: {});
  }

  Future<void> createLocation({
    required String name,
    required double lat,
    required double lng,
    required double radius,
  }) async {
    await _authorizedPost(
      '/admin/locations',
      data: {
        'name': name,
        'latitude': lat,
        'longitude': lng,
        'radius_m': radius,
      },
    );
  }

  Future<void> deleteLocation(String id) async {
    await _authorizedDelete('/admin/locations/$id');
  }

  Future<void> updateLocation({
    required String id,
    required String name,
    required double lat,
    required double lng,
    required double radius,
  }) async {
    await _authorizedPut(
      '/admin/locations/$id',
      data: {
        'name': name,
        'latitude': lat,
        'longitude': lng,
        'radius_m': radius,
      },
    );
  }

  Future<void> createHoliday({
    required String name,
    required DateTime date,
    required int numDays,
  }) async {
    await _authorizedPost(
      '/admin/holidays',
      data: {'name': name, 'date': _dateValue(date), 'num_days': numDays},
    );
  }

  Future<void> deleteHoliday(String id) async {
    await _authorizedDelete('/admin/holidays/$id');
  }

  Future<List<TaskRecord>> getAdminTasks() async {
    final response = await _authorizedGet('/admin/tasks');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => TaskRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaskRecord>> getMyTasks() async {
    final response = await _authorizedGet('/api/tasks');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => TaskRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<TaskRecord> getTask(String id) async {
    final response = await _authorizedGet('/api/tasks/$id');
    return TaskRecord.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<TaskListRecord>> getDailyTaskLists() async {
    final response = await _authorizedGet('/api/tasks/daily-lists');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => TaskListRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<BrandRecord>> getBrands() async {
    final response = await _authorizedGet('/api/brands');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => BrandRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaskCategoryRecord>> getTaskCategories() async {
    final response = await _authorizedGet('/api/task-categories');
    final data = response['data'] as List? ?? [];
    return data
        .map(
          (json) => TaskCategoryRecord.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<TaskRecord> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required DateTime dueDate,
    String? brandId,
    String? categoryId,
    List<String>? subItems,
    List<String>? assigneeIds,
    List<String>? listNames,
    String? priority,
    String? status,
  }) async {
    final response = await _authorizedPost(
      '/api/tasks',
      data: {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'due_date': _dateValue(dueDate),
        if (brandId != null && brandId.isNotEmpty) 'brand_id': brandId,
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
        if (subItems != null && subItems.isNotEmpty) 'sub_items': subItems,
        if (assigneeIds != null && assigneeIds.isNotEmpty)
          'assignee_ids': assigneeIds,
        if (listNames != null && listNames.isNotEmpty) 'list_names': listNames,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return TaskRecord.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateTaskStatus(String id, String status) async {
    await _authorizedPatch('/api/tasks/$id/status', data: {'status': status});
  }

  Future<TaskRecord> updateTask({
    required String id,
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime dueDate,
    String? brandId,
    String? categoryId,
    String? priority,
    String? status,
  }) async {
    final response = await _authorizedPatch(
      '/api/tasks/$id',
      data: {
        'title': title.trim(),
        'description': description.trim(),
        'assignee_ids': assigneeIds,
        'due_date': _dateValue(dueDate),
        'brand_id': brandId ?? '',
        'category_id': categoryId ?? '',
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return TaskRecord.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> toggleTaskSubItem(String id, String status) async {
    await _authorizedPatch(
      '/api/tasks/sub-items/$id/toggle',
      data: {'status': status},
    );
  }

  Future<TaskSubItem> createTaskSubItem(String taskId, String title) async {
    final response = await _authorizedPost(
      '/api/tasks/$taskId/sub-items',
      data: {'title': title},
    );
    return TaskSubItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<TaskListRecord>> getTrelloBoard(String taskId) async {
    final response = await _authorizedGet('/api/tasks/$taskId/trello');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => TaskListRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<TaskListRecord> createTaskList(
    String taskId, {
    required String name,
    String description = '',
    String priority = 'medium',
    String status = 'in_progress',
    DateTime? startDate,
    DateTime? dueDate,
    String adminComment = '',
    List<TaskListAttachment> attachments = const [],
    List<String> assigneeIds = const [],
  }) async {
    final response = await _authorizedPost(
      '/api/tasks/$taskId/lists',
      data: {
        'name': name.trim(),
        'description': description.trim(),
        'priority': priority,
        'status': status,
        if (startDate != null) 'start_date': _dateValue(startDate),
        if (dueDate != null) 'due_date': _dateValue(dueDate),
        'admin_comment': adminComment.trim(),
        'attachments': attachments.map((item) => item.toJson()).toList(),
        'assignee_ids': assigneeIds,
      },
    );
    return TaskListRecord.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteTaskList(String listId) async {
    await _authorizedDelete('/api/tasks/lists/$listId');
  }

  Future<TaskListRecord?> updateTaskList(
    String listId, {
    String? name,
    String? description,
    int? sortOrder,
    DateTime? startDate,
    DateTime? dueDate,
    String? priority,
    String? status,
    String? adminComment,
    List<TaskListAttachment>? attachments,
    List<String>? assigneeIds,
  }) async {
    final response = await _authorizedPatch(
      '/api/tasks/lists/$listId',
      data: {
        'name': ?name,
        'description': ?description,
        'sort_order': ?sortOrder,
        if (startDate != null)
          'start_date': startDate.toUtc().toIso8601String(),
        if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
        'priority': ?priority,
        'status': ?status,
        'admin_comment': ?adminComment,
        if (attachments != null)
          'attachments': attachments.map((item) => item.toJson()).toList(),
        'assignee_ids': ?assigneeIds,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    return TaskListRecord.fromJson(data);
  }

  Future<TaskCardRecord> createTaskCard(
    String listId,
    String title, {
    String description = '',
    String priority = 'medium',
    DateTime? startDate,
    DateTime? dueDate,
    List<String> assigneeIds = const [],
  }) async {
    final response = await _authorizedPost(
      '/api/tasks/lists/$listId/cards',
      data: {
        'title': title,
        'description': description,
        'priority': priority,
        if (startDate != null)
          'start_date': startDate.toUtc().toIso8601String(),
        if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
        'assignee_ids': assigneeIds,
      },
    );
    return TaskCardRecord.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateTaskCard(
    String cardId, {
    String? title,
    String? description,
    String? status,
    String? listId,
    int? sortOrder,
    String? priority,
    DateTime? startDate,
    DateTime? dueDate,
    String? adminComment,
  }) async {
    await _authorizedPatch(
      '/api/tasks/cards/$cardId',
      data: {
        'title': ?title,
        'description': ?description,
        'status': ?status,
        'list_id': ?listId,
        'sort_order': ?sortOrder,
        'priority': ?priority,
        if (startDate != null)
          'start_date': startDate.toUtc().toIso8601String(),
        if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
        'admin_comment': ?adminComment,
      },
    );
  }

  Future<void> deleteTaskCard(String cardId) async {
    await _authorizedDelete('/api/tasks/cards/$cardId');
  }

  Future<TaskSubItem> createCardSubItem(String cardId, String title) async {
    final response = await _authorizedPost(
      '/api/tasks/cards/$cardId/sub-items',
      data: {'title': title},
    );
    return TaskSubItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateTaskSubItemDetail(
    String subItemId, {
    required String title,
    DateTime? startDate,
    DateTime? dueDate,
    String? linkUrl,
    String? attachmentUrl,
    String? verificationNotes,
    String? adminComment,
  }) async {
    await _authorizedPatch(
      '/api/tasks/sub-items/$subItemId/detail',
      data: {
        'title': title,
        'start_date': startDate?.toUtc().toIso8601String(),
        'due_date': dueDate?.toUtc().toIso8601String(),
        'link_url': ?linkUrl,
        'attachment_url': ?attachmentUrl,
        'verification_notes': ?verificationNotes,
        'admin_comment': ?adminComment,
      },
    );
  }

  Future<void> deleteTaskSubItem(String id) async {
    await _authorizedDelete('/api/tasks/sub-items/$id');
  }

  Future<void> createSubItemVerification(
    String subItemId, {
    required String status,
    required String notes,
  }) async {
    await _authorizedPost(
      '/api/tasks/sub-items/$subItemId/verifications',
      data: {'status': status, 'notes': notes},
    );
  }

  // ─────────────────── Card Attachments ───────────────────

  Future<CardAttachment> createCardAttachment(
    String cardId, {
    required String url,
    required String name,
    required String type, // 'image' | 'file' | 'link'
  }) async {
    final response = await _authorizedPost(
      '/api/tasks/cards/$cardId/attachments',
      data: {'url': url, 'name': name, 'type': type},
    );
    return CardAttachment.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<CardAttachment>> listCardAttachments(String cardId) async {
    final response = await _authorizedGet(
      '/api/tasks/cards/$cardId/attachments',
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .map((e) => CardAttachment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteCardAttachment(String attachmentId) async {
    await _authorizedDelete('/api/tasks/cards/attachments/$attachmentId');
  }

  Future<void> deleteTask(String id) async {
    await _authorizedDelete('/admin/tasks/$id');
  }

  Future<List<TaskRecord>> getTrashTasks() async {
    final response = await _authorizedGet('/api/tasks/trash');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => TaskRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> restoreTask(String id) async {
    await _authorizedPost('/api/tasks/$id/restore', data: {});
  }

  Future<void> toggleStarTask(String id, bool isStarred) async {
    await _authorizedPost(
      '/api/tasks/$id/star',
      data: {'is_starred': isStarred},
    );
  }

  Future<void> updateFcmToken(String token) async {
    debugPrint(
      '[FCM API LOG] Sending PUT /api/users/me/fcm-token with payload: {"fcm_token": "$token"}',
    );
    try {
      final response = await _authorizedPut(
        '/api/users/me/fcm-token',
        data: {'fcm_token': token},
      );
      debugPrint('[FCM API LOG] API Success response: $response');
    } on AuthFlowException catch (e) {
      debugPrint('[FCM API LOG] API Error (AuthFlowException): ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[FCM API LOG] API Error (Unknown): $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    final response = await _authorizedGet('/api/notifications');
    final data = response['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<void> markNotificationRead(String id) async {
    await _authorizedPatch('/api/notifications/$id/read', data: {});
  }

  Future<void> markAllNotificationsRead() async {
    await _authorizedPatch('/api/notifications/read-all', data: {});
  }

  Future<AttendanceRecord> checkIn({
    required double lat,
    required double lng,
    required String deviceId,
    required List<double> faceVector,
    String? photoUrl,
    double? accuracyM,
  }) async {
    final response = await _authorizedPost(
      '/api/attendance/checkin',
      data: {
        'lat': lat,
        'lng': lng,
        'device_id': deviceId,
        'face_vector': faceVector,
        'photo_url': ?photoUrl,
        'accuracy_m': ?accuracyM,
      },
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return AttendanceRecord.fromJson(data);
    }
    throw const AuthFlowException('ข้อมูลตอบกลับจากระบบเช็คอินไม่ถูกต้อง');
  }

  Future<AttendanceRecord> checkOut({
    double? lat,
    double? lng,
    String? photoUrl,
    double? accuracyM,
  }) async {
    final response = await _authorizedPost(
      '/api/attendance/checkout',
      data: {
        'lat': ?lat,
        'lng': ?lng,
        'photo_url': ?photoUrl,
        'accuracy_m': ?accuracyM,
      },
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return AttendanceRecord.fromJson(data);
    }
    throw const AuthFlowException('ข้อมูลตอบกลับจากระบบเช็คเอาท์ไม่ถูกต้อง');
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
    _refreshToken =
        data['refresh_token'] as String? ??
        root['refresh_token'] as String? ??
        _refreshToken;
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

    if (tokenRequired && (_accessToken == null || _accessToken!.isEmpty)) {
      throw const AuthFlowException(
        'รูปแบบข้อมูลจาก /auth/login ไม่ถูกต้อง: ไม่พบ access_token',
      );
    }
    if (hasSession) {
      final writes = <Future<void>>[
        if (_accessToken != null && _accessToken!.isNotEmpty)
          _storage.write(key: _tokenKey, value: _accessToken),
        if (_authId != null && _authId!.isNotEmpty)
          _storage.write(key: _authIdKey, value: _authId),
        if (_email != null && _email!.isNotEmpty)
          _storage.write(key: _emailKey, value: _email),
      ];
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        writes.add(_storage.write(key: _refreshTokenKey, value: _refreshToken));
      }
      writes.add(_storage.write(key: _signedOutKey, value: 'false'));
      await Future.wait(writes);
    }
  }

  bool _isRefreshing = false;
  Completer<_SessionRefreshResult>? _refreshCompleter;

  bool _isJwtExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    final claims = _decodeJwtClaims(token);
    final exp = claims['exp'];
    if (exp is int) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // หากเหลือเวลาไม่ถึง 5 วินาที หรือเลยเวลาแล้ว ให้ถือว่าหมดอายุเพื่อรีเฟรชล่วงหน้า
      return DateTime.now().isAfter(
        expiryTime.subtract(const Duration(seconds: 5)),
      );
    }
    return true;
  }

  Future<_SessionRefreshResult> _silentReAuthenticate() async {
    final email = _email ?? await _storage.read(key: _emailKey);
    final pass = await _storage.read(key: _savedPassKey);
    if (email == null || email.isEmpty || pass == null || pass.isEmpty) {
      return _SessionRefreshResult.invalid;
    }
    try {
      debugPrint(
        '[AUTH] Attempting silent background re-authentication for $email...',
      );
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': pass},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      await _captureSession(
        response.data,
        fallbackEmail: email,
        tokenRequired: true,
      );
      debugPrint('[AUTH] Silent re-auth succeeded! Session is active.');
      return hasSession
          ? _SessionRefreshResult.refreshed
          : _SessionRefreshResult.invalid;
    } on DioException catch (error) {
      debugPrint('[AUTH] Silent re-auth failed: $error');
      final status = error.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        return _SessionRefreshResult.invalid;
      }
      return _SessionRefreshResult.unavailable;
    } catch (error) {
      debugPrint('[AUTH] Silent re-auth failed: $error');
      return _SessionRefreshResult.unavailable;
    }
  }

  Future<_SessionRefreshResult> _refreshSession() async {
    if (_isRefreshing && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    final completer = Completer<_SessionRefreshResult>();
    _refreshCompleter = completer;
    var result = _SessionRefreshResult.unavailable;

    try {
      final tokenToRefresh =
          _refreshToken ?? await _storage.read(key: _refreshTokenKey);
      if (tokenToRefresh == null || tokenToRefresh.isEmpty) {
        result = await _silentReAuthenticate();
        return result;
      }

      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await _dio.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refresh_token': tokenToRefresh},
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
          final data = response.data;
          if (data != null &&
              (data['access_token'] != null ||
                  data['data']?['access_token'] != null)) {
            await _captureSession(
              data,
              fallbackEmail: _email ?? '',
              tokenRequired: true,
            );
            result = _SessionRefreshResult.refreshed;
            return result;
          }
        } on DioException catch (e) {
          final statusCode = e.response?.statusCode;
          final errorBody = e.response?.data;
          final isInvalidGrant =
              statusCode == 401 &&
              errorBody is Map &&
              errorBody['is_invalid_grant'] == true;

          if (isInvalidGrant) {
            debugPrint(
              '[AUTH] Refresh token is invalid/expired, triggering silent re-auth...',
            );
            result = await _silentReAuthenticate();
            return result;
          }

          debugPrint(
            '[AUTH] Refresh attempt $attempt failed with network error: $e',
          );
          if (attempt < 3) {
            await Future.delayed(
              Duration(milliseconds: 250 * (1 << (attempt - 1))),
            );
          }
        } catch (e) {
          debugPrint('[AUTH] Refresh unexpected error: $e');
          return result;
        }
      }

      return result;
    } finally {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      _isRefreshing = false;
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;
          if (!path.contains('/auth/login') &&
              !path.contains('/auth/refresh') &&
              !path.contains('/auth/signup')) {
            if (_isJwtExpired(_accessToken) && hasSession) {
              final result = await _refreshSession();
              if (result == _SessionRefreshResult.refreshed &&
                  _accessToken != null) {
                options.headers['Authorization'] = 'Bearer $_accessToken';
              }
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            if (!path.contains('/auth/login') &&
                !path.contains('/auth/refresh') &&
                !path.contains('/auth/signup') &&
                error.requestOptions.extra[_authRetryKey] != true) {
              final result = await _refreshSession();
              if (result == _SessionRefreshResult.refreshed &&
                  _accessToken != null) {
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $_accessToken';
                options.extra[_authRetryKey] = true;
                try {
                  final clonedResponse = await _dio.fetch(options);
                  return handler.resolve(clonedResponse);
                } catch (e) {
                  return handler.next(error);
                }
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
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

  Future<List<_RememberedCredential>> _readRememberedCredentials() async {
    final raw = await _storage.read(key: _rememberedAccountsKey);
    final result = <_RememberedCredential>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final credential = _RememberedCredential.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (credential.email.isNotEmpty &&
                  credential.password.isNotEmpty) {
                result.add(credential);
              }
            }
          }
        }
      } catch (error) {
        debugPrint('[AUTH] Could not decode remembered accounts: $error');
      }
    }

    if (result.isEmpty) {
      final legacyEmail = await _storage.read(key: _emailKey);
      final legacyPassword = await _storage.read(key: _savedPassKey);
      if (legacyEmail != null &&
          legacyEmail.trim().isNotEmpty &&
          legacyPassword != null &&
          legacyPassword.isNotEmpty) {
        result.add(
          _RememberedCredential(
            email: legacyEmail.trim(),
            password: legacyPassword,
            nickname:
                await _storage.read(key: _rememberedNicknameKey) ??
                _nicknameFromLegacyDisplayName(
                  await _storage.read(key: _rememberedNameKey),
                ),
            avatarUrl: await _storage.read(key: _rememberedAvatarKey),
          ),
        );
        await _writeRememberedCredentials(result);
      }
    }
    return result;
  }

  Future<void> _writeRememberedCredentials(
    List<_RememberedCredential> credentials,
  ) async {
    if (credentials.isEmpty) {
      await _storage.delete(key: _rememberedAccountsKey);
      return;
    }
    await _storage.write(
      key: _rememberedAccountsKey,
      value: jsonEncode(
        credentials.map((value) => value.toJson()).toList(growable: false),
      ),
    );
  }

  Future<void> _rememberCredential({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) return;
    final credentials = await _readRememberedCredentials();
    _RememberedCredential? existing;
    for (final credential in credentials) {
      if (credential.email.toLowerCase() == normalizedEmail) {
        existing = credential;
        break;
      }
    }
    final updated = _RememberedCredential(
      email: email.trim(),
      password: password,
      nickname: existing?.nickname,
      avatarUrl: existing?.avatarUrl,
    );
    final values = <_RememberedCredential>[
      updated,
      ...credentials.where(
        (value) => value.email.toLowerCase() != normalizedEmail,
      ),
    ].take(5).toList(growable: false);
    await _writeRememberedCredentials(values);
  }

  Future<void> _updateRememberedProfile({
    required String email,
    required String nickname,
    String? avatarUrl,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;
    final credentials = await _readRememberedCredentials();
    var changed = false;
    final updated = credentials
        .map((credential) {
          if (credential.email.toLowerCase() != normalizedEmail) {
            return credential;
          }
          changed = true;
          return _RememberedCredential(
            email: credential.email,
            password: credential.password,
            nickname: nickname.trim(),
            avatarUrl: avatarUrl?.trim().isNotEmpty == true
                ? avatarUrl!.trim()
                : credential.avatarUrl,
          );
        })
        .toList(growable: false);
    if (changed) await _writeRememberedCredentials(updated);
  }

  Map<String, String> _authorizationHeaders() {
    if (_accessToken == null || _accessToken!.isEmpty) {
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

  Future<Map<String, dynamic>> _authorizedPut(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(headers: _authorizationHeaders()),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw AuthFlowException(_apiMessage(error));
    }
  }

  Future<Map<String, dynamic>> _authorizedDelete(String path) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        path,
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

  // --- Card Assignees ---
  Future<List<UserSummary>> getCardAssignees(String cardId) async {
    final response = await _authorizedGet('/api/tasks/cards/$cardId/assignees');
    final data = response['data'] as List;
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserSummary>> updateCardAssignees(
    String cardId,
    List<String> userIds,
  ) async {
    final response = await _authorizedPut(
      '/api/tasks/cards/$cardId/assignees',
      data: {'assignee_ids': userIds},
    );
    final data = response['data'] as List;
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Task Members (for assignee picker) ---
  Future<List<UserSummary>> getTaskMembers(String taskId) async {
    final response = await _authorizedGet('/api/tasks/$taskId/members');
    final data = response['data'] as List;
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Deliverable Comments / Task Activity ---
  Future<List<TaskEventRecord>> getTaskEvents(
    String taskId, {
    String? listId,
  }) async {
    final query = listId?.trim().isNotEmpty == true
        ? '?list_id=${Uri.encodeQueryComponent(listId!.trim())}'
        : '';
    final response = await _authorizedGet('/api/tasks/$taskId/events$query');
    return _listData(
      response,
    ).map(TaskEventRecord.fromJson).toList(growable: false);
  }

  Future<TaskEventRecord> addTaskComment(
    String taskId,
    String content, {
    String? listId,
  }) async {
    final response = await _authorizedPost(
      '/api/tasks/$taskId/events',
      data: {
        'content': content.trim(),
        if (listId?.trim().isNotEmpty == true) 'list_id': listId!.trim(),
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const AuthFlowException('รูปแบบข้อมูลคอมเมนต์จาก API ไม่ถูกต้อง');
    }
    return TaskEventRecord.fromJson(data);
  }

  // --- Card Comments ---
  Future<List<CardComment>> getCardComments(
    String cardId, {
    DateTime? cursor,
    int limit = 30,
  }) async {
    final query = StringBuffer('?limit=$limit');
    if (cursor != null) {
      query.write('&cursor=${Uri.encodeComponent(cursor.toIso8601String())}');
    }
    final response = await _authorizedGet(
      '/api/tasks/cards/$cardId/comments$query',
    );
    final data = response['data'] as List;
    return data
        .map((e) => CardComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CardComment> createCardComment(
    String cardId,
    dynamic contentDelta,
    String plainText,
    List<String> mentionedUserIds,
    List<Map<String, dynamic>> attachments,
  ) async {
    final response = await _authorizedPost(
      '/api/tasks/cards/$cardId/comments',
      data: {
        'content_delta': contentDelta,
        'plain_text': plainText,
        'mentioned_user_ids': mentionedUserIds,
        'attachments': attachments,
      },
    );
    return CardComment.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateCardComment(
    String cardId,
    String commentId,
    dynamic contentDelta,
    String plainText,
    List<String> mentionedUserIds,
  ) async {
    await _authorizedPatch(
      '/api/tasks/cards/$cardId/comments/$commentId',
      data: {
        'content_delta': contentDelta,
        'plain_text': plainText,
        'mentioned_user_ids': mentionedUserIds,
      },
    );
  }

  Future<void> deleteCardComment(String cardId, String commentId) async {
    await _authorizedDelete('/api/tasks/cards/$cardId/comments/$commentId');
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

enum _SessionRefreshResult { refreshed, invalid, unavailable }

String? _nicknameFromLegacyDisplayName(String? displayName) {
  final value = displayName?.trim() ?? '';
  if (value.isEmpty) return null;
  final match = RegExp(r'\(([^()]*)\)\s*$').firstMatch(value);
  final nickname = match?.group(1)?.trim() ?? '';
  return nickname.isEmpty ? null : nickname;
}

class RememberedAccount {
  const RememberedAccount({required this.email, this.nickname, this.avatarUrl});

  final String email;
  final String? nickname;
  final String? avatarUrl;

  String get label {
    final value = nickname?.trim() ?? '';
    return value.isEmpty ? email.split('@').first : value;
  }

  String get initial {
    final value = label.trim();
    return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
  }
}

class _RememberedCredential {
  const _RememberedCredential({
    required this.email,
    required this.password,
    this.nickname,
    this.avatarUrl,
  });

  factory _RememberedCredential.fromJson(Map<String, dynamic> json) {
    return _RememberedCredential(
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
      nickname:
          json['nickname'] as String? ??
          _nicknameFromLegacyDisplayName(json['display_name'] as String?),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String email;
  final String password;
  final String? nickname;
  final String? avatarUrl;

  RememberedAccount get account =>
      RememberedAccount(email: email, nickname: nickname, avatarUrl: avatarUrl);

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (nickname?.trim().isNotEmpty == true) 'nickname': nickname!.trim(),
    if (avatarUrl?.trim().isNotEmpty == true) 'avatar_url': avatarUrl!.trim(),
  };
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
    if (status == 403 &&
        (value.contains('disabled') ||
            value.contains('suspended') ||
            value.contains('ระงับ'))) {
      return const AuthApiException('บัญชีของคุณถูกระงับการใช้งาน');
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

class AccountSuspendedException extends AuthFlowException {
  const AccountSuspendedException(super.message);
}

class ApiUnavailableException extends AuthFlowException {
  const ApiUnavailableException(super.message);
}
