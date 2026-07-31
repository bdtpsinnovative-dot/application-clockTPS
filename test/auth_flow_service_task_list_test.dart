import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/services/auth_flow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'status update tolerates a legacy success response without data',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'clock_in_tps_access_token': 'test-token',
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _LegacyTaskListUpdateAdapter();
      final service = AuthFlowService(
        dio: dio,
        storage: const FlutterSecureStorage(),
      );
      await service.restoreSession();

      final updated = await service.updateTaskList(
        'list-1',
        status: 'completed',
      );

      expect(updated, isNull);
    },
  );
}

class _LegacyTaskListUpdateAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.method, 'PATCH');
    expect(options.path, '/api/tasks/lists/list-1');
    expect(options.data, containsPair('status', 'completed'));
    return ResponseBody.fromString(
      jsonEncode({'ok': true, 'message': 'อัปเดตสถานะสำเร็จ'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
