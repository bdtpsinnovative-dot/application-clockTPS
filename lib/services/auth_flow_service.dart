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
        'file': await MultipartFile.fromFile(
          file.path,
          contentType: mediaType,
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

  Future<AppUser> updateProfileInfo({
    required String firstName,
    required String lastName,
    required String avatarUrl,
  }) async {
    try {
      final data = {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
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
    return _listData(response)
        .map(LeaveBalanceRecord.fromJson)
        .toList(growable: false);
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
        'medical_cert_url':? medicalCertUrl,
        'swap_date':? swapDate == null ? null : _dateValue(swapDate),
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
        'medical_cert_url':? medicalCertUrl,
        'swap_date':? swapDate == null ? null : _dateValue(swapDate),
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
    await _authorizedPut(
      '/api/users/me/device',
      data: {'device_id': deviceId},
    );
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
    final response = await _authorizedGet('/admin/users');
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
      ...leavesList.whereType<Map<String, dynamic>>().map(WorkRequestRecord.leave),
      ...offsiteList.whereType<Map<String, dynamic>>().map(WorkRequestRecord.offsite),
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
      ...leavesList.whereType<Map<String, dynamic>>().map(WorkRequestRecord.leave),
      ...offsiteList.whereType<Map<String, dynamic>>().map(WorkRequestRecord.offsite),
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
      return const AttendanceSummary(totalEmployees: 0, attendedToday: 0, lateToday: 0);
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

  Future<void> updateLeaveStatusAdmin(String id, String status) async {
    await _authorizedPatch('/admin/leaves/$id/status', data: {'status': status});
  }

  Future<void> updateOffsiteStatusAdmin(String id, String status) async {
    await _authorizedPatch('/admin/offsite/$id/status', data: {'status': status});
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
    await _authorizedPost('/admin/locations', data: {
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'radius_m': radius,
    });
  }

  Future<void> deleteLocation(String id) async {
    await _authorizedDelete('/admin/locations/$id');
  }

  Future<void> createHoliday({
    required String name,
    required DateTime date,
    required int numDays,
  }) async {
    await _authorizedPost('/admin/holidays', data: {
      'name': name,
      'date': _dateValue(date),
      'num_days': numDays,
    });
  }

  Future<void> deleteHoliday(String id) async {
    await _authorizedDelete('/admin/holidays/$id');
  }

  Future<List<TaskRecord>> getAdminTasks() async {
    final response = await _authorizedGet('/admin/tasks');
    final data = response['data'] as List? ?? [];
    return data.map((json) => TaskRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<TaskRecord>> getMyTasks() async {
    final response = await _authorizedGet('/api/tasks');
    final data = response['data'] as List? ?? [];
    return data.map((json) => TaskRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<BrandRecord>> getBrands() async {
    final response = await _authorizedGet('/api/brands');
    final data = response['data'] as List? ?? [];
    return data.map((json) => BrandRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<TaskCategoryRecord>> getTaskCategories() async {
    final response = await _authorizedGet('/api/task-categories');
    final data = response['data'] as List? ?? [];
    return data.map((json) => TaskCategoryRecord.fromJson(json as Map<String, dynamic>)).toList();
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
  }) async {
    final response = await _authorizedPost('/admin/tasks', data: {
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'due_date': _dateValue(dueDate),
      if (brandId != null && brandId.isNotEmpty) 'brand_id': brandId,
      if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
      if (subItems != null && subItems.isNotEmpty) 'sub_items': subItems,
      if (assigneeIds != null && assigneeIds.isNotEmpty) 'assignee_ids': assigneeIds,
    });
    return TaskRecord.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateTaskStatus(String id, String status) async {
    await _authorizedPatch('/api/tasks/$id/status', data: {'status': status});
  }

  Future<List<TaskEvent>> fetchTaskEvents(String taskId) async {
    final response = await _authorizedGet('/api/tasks/$taskId/events');
    final data = response['data'];
    if (data is List) {
      return data.map((e) => TaskEvent.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<TaskEvent> addTaskComment(String taskId, String content) async {
    final response = await _authorizedPost('/api/tasks/$taskId/events', data: {'content': content});
    return TaskEvent.fromJson(response['data'] as Map<String, dynamic>);
  }


  Future<void> toggleTaskSubItem(String id, String status) async {
    await _authorizedPatch('/api/tasks/sub-items/$id/toggle', data: {'status': status});
  }

  Future<TaskSubItem> createTaskSubItem(String taskId, String title) async {
    final response = await _authorizedPost('/api/tasks/$taskId/sub-items', data: {'title': title});
    return TaskSubItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<TaskListRecord>> getTrelloBoard(String taskId) async {
    final response = await _authorizedGet('/api/tasks/$taskId/trello');
    final data = response['data'] as List? ?? [];
    return data.map((json) => TaskListRecord.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<TaskListRecord> createTaskList(String taskId, String name) async {
    final response = await _authorizedPost('/api/tasks/$taskId/lists', data: {'name': name});
    return TaskListRecord.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteTaskList(String listId) async {
    await _authorizedDelete('/api/tasks/lists/$listId');
  }

  Future<void> updateTaskList(
    String listId, {
    String? name,
    String? description,
    int? sortOrder,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    await _authorizedPatch('/api/tasks/lists/$listId', data: {
      'name':? name,
      'description':? description,
      'sort_order':? sortOrder,
      'start_date': startDate?.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
    });
  }

  Future<TaskCardRecord> createTaskCard(
    String listId,
    String title, {
    String description = '',
    String priority = 'medium',
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final response = await _authorizedPost('/api/tasks/lists/$listId/cards', data: {
      'title': title,
      'description': description,
      'priority': priority,
      if (startDate != null) 'start_date': startDate.toUtc().toIso8601String(),
      if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
    });
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
    await _authorizedPatch('/api/tasks/cards/$cardId', data: {
      'title':? title,
      'description':? description,
      'status':? status,
      'list_id':? listId,
      'sort_order':? sortOrder,
      'priority':? priority,
      'start_date': startDate?.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
      'admin_comment':? adminComment,
    });
  }

  Future<void> deleteTaskCard(String cardId) async {
    await _authorizedDelete('/api/tasks/cards/$cardId');
  }

  Future<TaskSubItem> createCardSubItem(String cardId, String title) async {
    final response = await _authorizedPost('/api/tasks/cards/$cardId/sub-items', data: {'title': title});
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
    await _authorizedPatch('/api/tasks/sub-items/$subItemId/detail', data: {
      'title': title,
      'start_date': startDate?.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
      'link_url':? linkUrl,
      'attachment_url':? attachmentUrl,
      'verification_notes':? verificationNotes,
      'admin_comment':? adminComment,
    });
  }

  Future<void> deleteTaskSubItem(String id) async {
    await _authorizedDelete('/api/tasks/sub-items/$id');
  }

  Future<void> createSubItemVerification(String subItemId, {
    required String status,
    required String notes,
  }) async {
    await _authorizedPost('/api/tasks/sub-items/$subItemId/verifications', data: {
      'status': status,
      'notes': notes,
    });
  }

  // ─────────────────── Card Attachments ───────────────────

  Future<CardAttachment> createCardAttachment(String cardId, {
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
    final response = await _authorizedGet('/api/tasks/cards/$cardId/attachments');
    final data = response['data'];
    if (data is! List) return const [];
    return data.map((e) => CardAttachment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteCardAttachment(String attachmentId) async {
    await _authorizedDelete('/api/tasks/cards/attachments/$attachmentId');
  }

  Future<void> deleteTask(String id) async {
    await _authorizedDelete('/api/tasks/$id');
  }

  Future<void> updateFcmToken(String token) async {
    debugPrint('[FCM API LOG] Sending PUT /api/users/me/fcm-token with payload: {"fcm_token": "$token"}');
    try {
      final response = await _authorizedPut('/api/users/me/fcm-token', data: {'fcm_token': token});
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
  }) async {
    final response = await _authorizedPost(
      '/api/attendance/checkin',
      data: {
        'lat': lat,
        'lng': lng,
        'device_id': deviceId,
        'face_vector': faceVector,
        'photo_url':? photoUrl,
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
  }) async {
    final response = await _authorizedPost(
      '/api/attendance/checkout',
      data: {
        'lat':? lat,
        'lng':? lng,
        'photo_url':? photoUrl,
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
