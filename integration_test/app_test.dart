import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:hr_management/main.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/screens/auth_gate.dart';
import 'package:hr_management/screens/face_scanner_page.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    return Position(
      latitude: 13.7563,
      longitude: 100.5018,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      headingAccuracy: 0.0,
      altitudeAccuracy: 0.0,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Set mock geolocator platform
  GeolocatorPlatform.instance = MockGeolocatorPlatform();

  // Set mock secure storage values
  FlutterSecureStorage.setMockInitialValues({
    'clock_in_tps_access_token': 'mock-jwt-token-xyz',
    'clock_in_tps_auth_id': 'auth-uuid-222',
    'clock_in_tps_email': 'test@tps.co.th',
  });

  group('Clock in TPS Integration Tests', () {
    late Dio mockDio;
    late AuthFlowService authFlowService;
    Map<String, dynamic>? lastBindDeviceBody;
    Map<String, dynamic>? lastCheckInBody;
    Map<String, dynamic>? lastCheckOutBody;
    Map<String, dynamic>? mockAttendanceData;
    bool uploadCalled = false;

    setUp(() {
      mockDio = Dio();
      lastBindDeviceBody = null;
      lastCheckInBody = null;
      lastCheckOutBody = null;
      uploadCalled = false;
      mockAttendanceData = {
        'date': '2026-07-07T00:00:00Z',
        'status': 'no_record',
        'check_in_at': null,
        'check_out_at': null,
      };

      // Register mock method channel for device_info_plus
      const MethodChannel('dev.fluttercommunity.plus/device_info')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        final method = methodCall.method.toLowerCase();
        if (method.contains('ios')) {
          return {
            'name': 'iPhone 17',
            'model': 'iPhone',
            'systemName': 'iOS',
            'systemVersion': '17.0',
            'localizedModel': 'iPhone',
            'identifierForVendor': 'test-ios-device-id-123',
            'isPhysicalDevice': false,
          };
        } else if (method.contains('macos') || method.contains('mac')) {
          return {
            'computerName': 'MacBook Pro',
            'hostName': 'MacBook-Pro.local',
            'arch': 'arm64',
            'model': 'MacBookPro18,1',
            'kernelVersion': 'Darwin Kernel Version 21.0.0',
            'osRelease': '21.0.0',
            'activeCPUs': 10,
            'memorySize': 17179869184,
            'cpuFrequency': 2400000000,
            'systemGUID': 'test-ios-device-id-123',
          };
        }
        return null;
      });

      // Mock ML Kit method channels since they are not supported on macOS desktop
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_face_detector'),
        (MethodCall methodCall) async => null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_commons'),
        (MethodCall methodCall) async => null,
      );

      // Add mock interceptor to intercept all HTTP requests
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          if (path.contains('/api/users/me/device')) {
            lastBindDeviceBody = options.data as Map<String, dynamic>;
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'ok': true, 'message': 'ผูกเครื่องสำเร็จ'},
            ));
          } else if (path.contains('/api/users/me')) {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'data': {
                  'id': 'user-uuid-111',
                  'auth_id': 'auth-uuid-222',
                  'email': 'test@tps.co.th',
                  'first_name': 'สมชาย',
                  'last_name': 'สายตรง',
                  'department': 'ไอที',
                  'position': 'โปรแกรมเมอร์',
                  'role': 'employee',
                  'status': 'active',
                  'avatar_url': 'https://r2.example.com/avatar.jpg',
                  'has_face_embedding': true,
                }
              },
            ));
          } else if (path.contains('/api/upload')) {
            uploadCalled = true;
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'url': 'https://r2.example.com/checkin_photo_xyz.jpg'
              },
            ));
          } else if (path.contains('/api/attendance/checkin')) {
            lastCheckInBody = options.data as Map<String, dynamic>;
            mockAttendanceData = {
              'date': '2026-07-07T00:00:00Z',
              'status': 'on_time',
              'check_in_at': '2026-07-07T09:00:00Z',
              'check_out_at': null,
            };
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'message': 'เช็คอินสำเร็จ',
                'data': mockAttendanceData,
              },
            ));
          } else if (path.contains('/api/attendance/checkout')) {
            lastCheckOutBody = options.data as Map<String, dynamic>;
            mockAttendanceData = {
              'date': '2026-07-07T00:00:00Z',
              'status': 'on_time',
              'check_in_at': '2026-07-07T09:00:00Z',
              'check_out_at': '2026-07-07T18:00:00Z',
            };
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'message': 'เช็คเอาท์สำเร็จ',
                'data': mockAttendanceData,
              },
            ));
          } else if (path.contains('/api/attendance')) {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'data': mockAttendanceData,
              },
            ));
          } else if (path.contains('/api/holidays')) {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'ok': true, 'data': []},
            ));
          } else if (path.contains('/api/leaves/quota')) {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ok': true,
                'data': [
                  {
                    'leave_type': 'ลาป่วย',
                    'quota': 30.0,
                    'used': 2.0,
                    'remaining': 28.0
                  },
                  {
                    'leave_type': 'ลากิจ',
                    'quota': 6.0,
                    'used': 1.0,
                    'remaining': 5.0
                  },
                  {
                    'leave_type': 'ลาพักร้อน',
                    'quota': 6.0,
                    'used': 3.0,
                    'remaining': 3.0
                  }
                ]
              },
            ));
          } else {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'ok': true},
            ));
          }
        },
      ));

      authFlowService = AuthFlowService(dio: mockDio);
    });

    testWidgets('Full Clock-In & Clock-Out End-to-End Flow Test', (WidgetTester tester) async {
      AuthFlowService.mockDeviceId = 'test-ios-device-id-123';

      // 1. Setup mock FaceScannerResult
      final tempDir = await getTemporaryDirectory();
      final mockImageFile = File('${tempDir.path}/test_face.jpg');
      await mockImageFile.parent.create(recursive: true);
      await mockImageFile.writeAsBytes([0, 1, 2, 3]);

      FaceScannerPage.mockResult = FaceScannerResult(
        faceVector: List.generate(128, (i) => i.toDouble() / 128.0),
        imageFile: mockImageFile,
      );

      // 2. Launch the Application with the mocked AuthFlowService
      await tester.pumpWidget(MaterialApp(
        home: AuthGate(service: authFlowService),
      ));

      // Wait for auth gate to restore session and load user profile (active status)
      await tester.pumpAndSettle();

      // Verify Auto Device Binding on load
      expect(lastBindDeviceBody, isNotNull);
      expect(lastBindDeviceBody?['device_id'], equals('test-ios-device-id-123'));

      // Check that we transitioned to the Home/Dashboard shell successfully
      // Expect the Clock In button to be visible on Dashboard
      final clockButton = find.byKey(const ValueKey('clock_in_out_button'));
      expect(clockButton, findsOneWidget);
      expect(find.text('ลงเวลาเข้างาน'), findsOneWidget);

      // 3. Trigger Clock-In
      final clockBtnWidget = tester.widget<FilledButton>(clockButton);
      clockBtnWidget.onPressed!();
      await tester.pump(); // Start navigation to FaceScannerPage

      // FaceScannerPage should open and immediately pop back the mock result
      await tester.pumpAndSettle();

      // Check that checkIn API was successfully triggered
      expect(uploadCalled, isTrue); // Upload image to R2
      expect(lastCheckInBody, isNotNull);
      expect(lastCheckInBody?['lat'], equals(13.7563));
      expect(lastCheckInBody?['lng'], equals(100.5018));
      expect(lastCheckInBody?['device_id'], equals('test-ios-device-id-123'));
      expect(lastCheckInBody?['photo_url'], equals('https://r2.example.com/checkin_photo_xyz.jpg'));
      expect(lastCheckInBody?['face_vector'], isA<List>());

      // Wait for UI to redraw after check-in state update
      await tester.pumpAndSettle();

      // Tap Clock Button again to Clock-Out
      expect(find.text('ลงเวลาออกงาน'), findsOneWidget);
      final clockOutBtnWidget = tester.widget<FilledButton>(clockButton);
      clockOutBtnWidget.onPressed!();
      await tester.pumpAndSettle();

      // Check that checkOut API was successfully triggered
      expect(lastCheckOutBody, isNotNull);
      expect(lastCheckOutBody?['lat'], equals(13.7563));
      expect(lastCheckOutBody?['lng'], equals(100.5018));
    });
  });
}
