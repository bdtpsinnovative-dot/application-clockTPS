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

      debugPrint('[FCM LOG] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM LOG] User granted notification permission');
        
        // 2. Fetch token
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint('[FCM LOG] Checking iOS APNS Token...');
          final apnsToken = await _messaging.getAPNSToken();
          debugPrint('[FCM LOG] iOS APNS Token status: ${apnsToken != null ? "Set" : "Not Set (null)"}');
          if (apnsToken == null) {
            debugPrint('[FCM LOG] WARNING: iOS APNS token is null! Fetching FCM token will fail with apns-token-not-set.');
            debugPrint('[FCM LOG] Please ensure you are testing on a real iOS device (not simulator) and have enabled Push Notifications and Background Modes (Remote notifications) capabilities in Xcode.');
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
        } else {
          debugPrint('[FCM LOG] FCM Token is null!');
        }

        // 3. Setup token refresh listener
        _messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('[FCM LOG] FCM Token Refreshed: $newToken');
          debugPrint('[FCM LOG] Sending refreshed FCM token to backend...');
          await authService.updateFcmToken(newToken);
          debugPrint('[FCM LOG] Refreshed FCM token successfully updated on backend');
        }).onError((err) {
          debugPrint('[FCM LOG] Failed to refresh FCM Token: $err');
        });
      } else {
        debugPrint('[FCM LOG] User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint('[FCM LOG] Failed to register device for FCM: $e');
    }
  }
}
