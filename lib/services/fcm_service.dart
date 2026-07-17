import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hr_management/services/auth_flow_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling background message: ${message.messageId}");
}

class FcmService {
  FcmService._privateConstructor();
  static final FcmService instance = FcmService._privateConstructor();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Setup local notifications for Foreground banner displays
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        initializationSettings,
      );

      // 3. Create Android notification channel with custom sound
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'custom_sound_channel', // id
        'Custom Sound Notifications', // title
        description: 'This channel is used for custom sound notifications.', // description
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('custom_notification'),
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final RemoteNotification? notification = message.notification;
        final AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
                sound: const RawResourceAndroidNotificationSound('custom_notification'),
                playSound: true,
              ),
            ),
          );
        }
      });

      _initialized = true;
      debugPrint("FCM Service initialized successfully!");
    } catch (e) {
      debugPrint("Failed to initialize FCM Service: $e");
    }
  }

  Future<void> registerDevice(AuthFlowService authService) async {
    try {
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

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
        
        // 2. Fetch token
        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('FCM Token: $token');
          // Send to backend
          await authService.updateFcmToken(token);
        }

        // 3. Setup token refresh listener
        _messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM Token Refreshed: $newToken');
          await authService.updateFcmToken(newToken);
        }).onError((err) {
          debugPrint('Failed to refresh FCM Token: $err');
        });
      } else {
        debugPrint('User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint('Failed to register device for FCM: $e');
    }
  }
}
