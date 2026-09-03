import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/screens/login_page.dart';
import 'package:hr_management/services/auth_flow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'status update tolerates a legacy success response without data',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'clock_in_tps_access_token': _unexpiredTestJwt(),
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

  test('forget remembered account removes only the selected profile', () async {
    FlutterSecureStorage.setMockInitialValues({
      'clock_in_tps_remembered_accounts_v1': jsonEncode([
        {
          'email': 'first@example.com',
          'password': 'first-password',
          'nickname': 'First',
        },
        {
          'email': 'second@example.com',
          'password': 'second-password',
          'nickname': 'Second',
        },
      ]),
    });
    final service = AuthFlowService(
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test')),
      storage: const FlutterSecureStorage(),
    );

    await service.forgetRememberedAccount('FIRST@example.com');

    final accounts = await service.loadRememberedAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.email, 'second@example.com');
    expect(accounts.single.label, 'Second');
  });

  test('legacy full name is reduced to its nickname', () async {
    FlutterSecureStorage.setMockInitialValues({
      'clock_in_tps_remembered_accounts_v1': jsonEncode([
        {
          'email': 'employee@example.com',
          'password': 'employee-password',
          'display_name': 'สมชาย ใจดี (บอล)',
        },
      ]),
    });
    final service = AuthFlowService(
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test')),
      storage: const FlutterSecureStorage(),
    );

    final accounts = await service.loadRememberedAccounts();

    expect(accounts.single.label, 'บอล');
  });

  testWidgets('remembered account chooser fits a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({
      'clock_in_tps_remembered_accounts_v1': jsonEncode([
        {
          'email': 'employee@example.com',
          'password': 'employee-password',
          'nickname': 'บอล',
        },
      ]),
    });
    final service = AuthFlowService(
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test')),
      storage: const FlutterSecureStorage(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(service: service, onAuthenticated: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('เลือกบัญชี'), findsOneWidget);
    expect(find.text('บอล'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _unexpiredTestJwt() {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': 4102444800})),
  );
  return '$header.$payload.test-signature';
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
