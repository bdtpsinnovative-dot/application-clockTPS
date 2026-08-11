import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hr_management/services/auth_flow_service.dart';

const String _notificationChannelId = 'clock_in_tps_notifications_v2';
const String _notificationChannelName = 'Clock in TPS';
const String _notificationChannelDescription =
    'การแจ้งเตือนจากระบบ Clock in TPS';

String? _readMessageValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

Future<void> _showBackgroundDataNotification(RemoteMessage message) async {
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_clock_in_tps'),
  );
  await notificationPlugin.initialize(initializationSettings);

  const channel = AndroidNotificationChannel(
    _notificationChannelId,
    _notificationChannelName,
    description: _notificationChannelDescription,
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('custom_notification'),
    playSound: true,
  );
  final androidPlugin = notificationPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(channel);

  final title = _readMessageValue(message.data, const [
    'title',
    'notification_title',
  ]);
  final body = _readMessageValue(message.data, const [
    'body',
    'message',
    'content',
    'text',
    'notification_body',
  ]);
  if (title == null && body == null) return;

  await notificationPlugin.show(
    message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title ?? _notificationChannelName,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        icon: 'ic_stat_clock_in_tps',
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
        color: const Color(0xFF0EB7A8),
        category: AndroidNotificationCategory.message,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        onlyAlertOnce: true,
        styleInformation: BigTextStyleInformation(
          body ?? '',
          contentTitle: title ?? _notificationChannelName,
          summaryText: _notificationChannelName,
        ),
        sound: const RawResourceAndroidNotificationSound('custom_notification'),
        playSound: true,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payloads are rendered by Android while the app is in the
  // background. Data-only payloads need an explicit local notification.
  if (message.notification == null) {
    await _showBackgroundDataNotification(message);
  }
  debugPrint("Handling background message: ${message.messageId}");
}

class FcmNotificationTarget {
  const FcmNotificationTarget({this.taskId, this.listId, this.type});

  factory FcmNotificationTarget.fromData(Map<String, dynamic> data) {
    String? value(String snakeCase, String camelCase) {
      final raw = data[snakeCase] ?? data[camelCase];
      final text = raw?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return FcmNotificationTarget(
      taskId: value('task_id', 'taskId'),
      listId: value('list_id', 'listId'),
      type: value('type', 'notificationType'),
    );
  }

  final String? taskId;
  final String? listId;
  final String? type;
}

class FcmService {
  FcmService._privateConstructor();
  static final FcmService instance = FcmService._privateConstructor();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<FcmNotificationTarget> _notificationTapController =
      StreamController<FcmNotificationTarget>.broadcast();

  bool _initialized = false;
  bool _backgroundHandlerRegistered = false;
  bool _registeringDevice = false;
  bool _deviceRegistered = false;
  FcmNotificationTarget? _pendingTarget;
  AuthFlowService? _tokenAuthService;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Stream<FcmNotificationTarget> get notificationTaps =>
      _notificationTapController.stream;

  FcmNotificationTarget? takePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Register background handler
      if (!_backgroundHandlerRegistered) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        _backgroundHandlerRegistered = true;
      }

      // 2. Setup local notifications for foreground banner displays.
      // Use a dedicated monochrome notification icon. Launcher icons contain
      // full-colour/adaptive layers and render as a white box on some devices.
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_stat_clock_in_tps');
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: DarwinInitializationSettings(),
          );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
      );

      // 3. Create Android notification channel with custom sound
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description: _notificationChannelDescription,
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('custom_notification'),
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      // 4. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final RemoteNotification? notification = message.notification;
        final title =
            notification?.title ??
            _readMessageValue(message.data, const [
              'title',
              'notification_title',
            ]);
        final body =
            notification?.body ??
            _readMessageValue(message.data, const [
              'body',
              'message',
              'content',
              'text',
              'notification_body',
            ]);

        if ((notification != null || title != null || body != null) &&
            !kIsWeb) {
          _localNotifications.show(
            message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch,
            title ?? _notificationChannelName,
            body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: 'ic_stat_clock_in_tps',
                largeIcon: const DrawableResourceAndroidBitmap(
                  'ic_notification_large',
                ),
                color: const Color(0xFF0EB7A8),
                category: AndroidNotificationCategory.message,
                priority: Priority.high,
                visibility: NotificationVisibility.public,
                onlyAlertOnce: true,
                styleInformation: BigTextStyleInformation(
                  body ?? '',
                  contentTitle: title ?? _notificationChannelName,
                  summaryText: _notificationChannelName,
                ),
                sound: const RawResourceAndroidNotificationSound(
                  'custom_notification',
                ),
                playSound: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                sound: 'custom_notification.caf',
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteMessageTap(initialMessage);
      }

      _initialized = true;
      debugPrint("FCM Service initialized successfully!");
    } catch (e) {
      debugPrint("Failed to initialize FCM Service: $e");
    }
  }

  Future<void> registerDevice(AuthFlowService authService) async {
    if (_deviceRegistered || _registeringDevice) return;

    _registeringDevice = true;
    try {
      _tokenAuthService = authService;
      debugPrint('[FCM LOG] registerDevice called');
      // 1. Request permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '[FCM LOG] Permission status: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM LOG] User granted notification permission');

        // 2. Fetch token
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint('[FCM LOG] Checking iOS APNS Token...');
          final apnsToken = await _messaging.getAPNSToken();
          debugPrint(
            '[FCM LOG] iOS APNS Token status: ${apnsToken != null ? "Set" : "Not Set (null)"}',
          );
          if (apnsToken == null) {
            debugPrint(
              '[FCM LOG] WARNING: iOS APNS token is null! Fetching FCM token will fail with apns-token-not-set.',
            );
            debugPrint(
              '[FCM LOG] Please ensure you are testing on a real iOS device (not simulator) and have enabled Push Notifications and Background Modes (Remote notifications) capabilities in Xcode.',
            );
          }
        }

        debugPrint('[FCM LOG] Fetching FCM token from Firebase...');
        final token = await _messaging.getToken();
        debugPrint('[FCM LOG] FCM Token retrieved: $token');
        if (token != null) {
          // Send to backend
          debugPrint('[FCM LOG] Sending FCM token to backend...');
          await authService.updateFcmToken(token);
          debugPrint('[FCM LOG] FCM token successfully updated on backend');
          _deviceRegistered = true;
        } else {
          debugPrint('[FCM LOG] FCM Token is null!');
        }

        // 3. Setup token refresh listener
        _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
          (newToken) async {
            debugPrint('[FCM LOG] FCM Token Refreshed: $newToken');
            debugPrint('[FCM LOG] Sending refreshed FCM token to backend...');
            await _tokenAuthService?.updateFcmToken(newToken);
            debugPrint(
              '[FCM LOG] Refreshed FCM token successfully updated on backend',
            );
          },
          onError: (Object err) {
            debugPrint('[FCM LOG] Failed to refresh FCM Token: $err');
          },
        );
      } else {
        debugPrint(
          '[FCM LOG] User declined or has not accepted notification permission',
        );
      }
    } catch (e) {
      debugPrint('[FCM LOG] Failed to register device for FCM: $e');
    } finally {
      _registeringDevice = false;
    }
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    _emitNotificationTarget(FcmNotificationTarget.fromData(message.data));
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _emitNotificationTarget(
          FcmNotificationTarget.fromData(Map<String, dynamic>.from(decoded)),
        );
      }
    } catch (error) {
      debugPrint('[FCM LOG] Invalid notification payload: $error');
    }
  }

  void _emitNotificationTarget(FcmNotificationTarget target) {
    if (_notificationTapController.hasListener) {
      _notificationTapController.add(target);
    } else {
      _pendingTarget = target;
    }
  }
}
