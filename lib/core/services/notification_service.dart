import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';

// Global navigator key for navigation from notification handlers
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // Callback for token updates (to send to backend)
  Function(String token)? onTokenRefresh;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('User granted provisional notification permission');
      } else {
        print('User declined notification permission');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $_fcmToken');

      // Send token to backend
      if (_fcmToken != null) {
        await _sendTokenToBackend(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('FCM Token refreshed: $newToken');
        _sendTokenToBackend(newToken);
      });

      // Setup notification handlers
      setupForegroundNotificationHandler();
      setupBackgroundNotificationHandler();

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _isInitialized = true;
      print('NotificationService initialized successfully');
    } catch (e) {
      print('Failed to initialize NotificationService: $e');
    }
  }

  // Send FCM token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      // Call the callback if provided
      if (onTokenRefresh != null) {
        onTokenRefresh!(token);
      }

      // You can also directly call your API here
      // Example:
      // await dio.post('/api/devices/register-token', data: {
      //   'fcmToken': token,
      //   'platform': Platform.isIOS ? 'ios' : 'android',
      // });

      print('FCM token sent to backend: $token');
    } catch (e) {
      print('Failed to send token to backend: $e');
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'orbvpn_channel',
        'OrbVPN Notifications',
        description: 'Notifications for OrbVPN connection status',
        importance: Importance.high,
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    _navigateBasedOnPayload(response.payload);
  }

  // Navigate to appropriate screen based on payload
  void _navigateBasedOnPayload(String? payload) {
    if (payload == null) return;

    final context = notificationNavigatorKey.currentContext;
    if (context == null) {
      print('Navigation context not available');
      return;
    }

    // Parse payload and navigate
    switch (payload) {
      case 'connection_status':
        Navigator.pushNamed(context, '/home');
        break;
      case 'server_update':
        Navigator.pushNamed(context, '/servers');
        break;
      case 'subscription':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      default:
        // Try to parse as route
        if (payload.startsWith('/')) {
          Navigator.pushNamed(context, payload);
        }
    }
  }

  // Get FCM token
  Future<String?> getToken() async {
    try {
      if (_fcmToken != null) return _fcmToken;
      _fcmToken = await _firebaseMessaging.getToken();
      return _fcmToken;
    } catch (e) {
      print('Failed to get FCM token: $e');
      return null;
    }
  }

  // Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'orbvpn_channel',
        'OrbVPN Notifications',
        channelDescription: 'Notifications for OrbVPN connection status',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }

  // Handle notification when app is in foreground
  void setupForegroundNotificationHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.messageId}');

      final notification = message.notification;
      if (notification != null) {
        showNotification(
          title: notification.title ?? 'OrbVPN',
          body: notification.body ?? '',
          payload: message.data['route'] ?? message.data['type'],
        );
      }
    });
  }

  // Handle notification tap when app is in background
  void setupBackgroundNotificationHandler() {
    // Handle notification opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened: ${message.messageId}');
      _handleNotificationTap(message);
    });

    // Check if app was opened from terminated state via notification
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from notification: ${message.messageId}');
        _handleNotificationTap(message);
      }
    });
  }

  // Handle notification tap logic
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    print('Notification data: $data');

    final context = notificationNavigatorKey.currentContext;
    if (context == null) {
      print('Navigation context not available');
      return;
    }

    // Check for custom route in data
    if (data.containsKey('route')) {
      Navigator.pushNamed(context, data['route']);
      return;
    }

    // Route based on notification type
    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'connection_status':
          Navigator.pushNamed(context, '/home');
          break;
        case 'server_update':
          Navigator.pushNamed(context, '/servers');
          break;
        case 'subscription':
          Navigator.pushNamed(context, '/profile');
          break;
        case 'alert':
          // Show alert dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(message.notification?.title ?? 'Alert'),
              content: Text(message.notification?.body ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          break;
        default:
          Navigator.pushNamed(context, '/home');
      }
    }
  }

  // Show connection status notification
  Future<void> showConnectionNotification({
    required bool isConnected,
    String? serverName,
  }) async {
    await showNotification(
      title: isConnected ? 'VPN Connected' : 'VPN Disconnected',
      body: isConnected
          ? 'Connected to ${serverName ?? "server"}'
          : 'Your VPN connection has been disconnected',
      payload: 'connection_status',
    );
  }

  // Subscribe to topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Failed to subscribe to topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Failed to unsubscribe from topic: $e');
    }
  }

  // Delete FCM token
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      print('FCM token deleted');
    } catch (e) {
      print('Failed to delete FCM token: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Clear specific notification
  Future<void> clearNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Get badge count (iOS)
  Future<int?> getBadgeCount() async {
    if (Platform.isIOS) {
      // iOS badge count
      return await _firebaseMessaging.getNotificationSettings().then(
            (settings) =>
                settings.badge == AppleNotificationSetting.enabled ? 0 : null,
          );
    }
    return null;
  }

  // Set badge count (iOS)
  Future<void> setBadgeCount(int count) async {
    if (Platform.isIOS) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }
}
