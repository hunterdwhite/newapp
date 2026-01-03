import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'curator_orders',
      'Curator Orders',
      description: 'Notifications for new curator orders',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Configure Firebase Messaging
    await _configureFirebaseMessaging();

    _initialized = true;
  }

  /// Configure Firebase Messaging handlers
  Future<void> _configureFirebaseMessaging() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleMessage);

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Handle terminated app messages
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  /// Handle incoming FCM messages
  void _handleMessage(RemoteMessage message) {
    print('Received message: ${message.data}');

    // Show local notification if app is in foreground
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: message.data['type'] ?? '',
      );
    }

    // Handle navigation based on message type
    final messageType = message.data['type'];
    if (messageType == 'curator_order') {
      // Navigate to curator screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/curator');
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'curator_orders',
      'Curator Orders',
      channelDescription: 'Notifications for new curator orders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('Notification permission status: ${settings.authorizationStatus}');

      // Check for authorized or provisional (iOS)
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Check current notification permission status
  Future<bool> hasPermissions() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('Error checking notification permissions: $e');
      return false;
    }
  }

  /// Get FCM token and store it in Firestore
  Future<String?> getToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _storeFCMToken(token);
      }
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  /// Store FCM token in user document
  Future<void> _storeFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        print('FCM token stored successfully');
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
    }
  }

  /// Send push notification to a specific curator about a new order
  /// SECURITY: Does NOT include customer name or address - only order ID
  Future<void> notifyCuratorOfNewOrder({
    required String curatorId,
    required String orderId,
  }) async {
    try {
      // Get curator's FCM token from Firestore
      final curatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(curatorId)
          .get();

      if (!curatorDoc.exists) {
        print('Curator document not found: $curatorId');
        return;
      }

      final curatorData = curatorDoc.data() as Map<String, dynamic>;
      final fcmToken = curatorData['fcmToken'] as String?;
      final curatorName = curatorData['username'] ?? 'Curator';

      if (fcmToken == null || fcmToken.isEmpty) {
        print('No FCM token found for curator: $curatorId');
        return;
      }

      // Send notification via Firebase Cloud Functions or your backend
      // For now, we'll store it in Firestore for the backend to pick up
      // SECURITY: Generic message with no customer information
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'curator_order_assigned',
        'recipientId': curatorId,
        'recipientToken': fcmToken,
        'title': '🎵 New Curation Request',
        'body':
            'You have a new order waiting for your curation! Tap to start selecting the perfect album.',
        'data': {
          'type': 'curator_order',
          'orderId': orderId,
          'curatorId': curatorId,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print(
          '✅ Notification queued for curator $curatorName ($curatorId) about order $orderId');
      print('🔒 SECURITY: No customer information included in notification');
    } catch (e) {
      print('❌ Error sending curator notification: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped with payload: ${response.payload}');

    if (response.payload == 'curator_order') {
      // Navigate to curator screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/curator');
      }
    }
  }
}
