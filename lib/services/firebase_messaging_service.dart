import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Initialize FCM
  Future<void> initialize() async {
    try {
      // Request notification permissions
      await _localNotifications.resolvePlatformSpecificImplementation()?.requestPermissions(
        const IosNotificationSettings(
          alert: true,
          badge: true,
          sound: true,
        ),
        const AndroidNotificationSettings(
          channelDescription: 'high_importance_channel',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );

      // Initialize FCM
      await _messaging.requestPermission();
      
      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token!);
      }

      // Configure notification channels
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        id: 'high_importance_channel',
        name: 'High Importance Notifications',
        description: 'Used for important notifications',
        importance: Importance.high,
      );

      await _localNotifications.createNotificationChannel(channel);

      // Handle initial message
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleMessage(initialMessage);
      }

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage.listen(_handleBackgroundMessage);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      print('Firebase Messaging initialized successfully');
    } catch (e) {
      print('Error initializing Firebase Messaging: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFcmToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      await _handleMessage(message);
    } catch (e) {
      print('Error handling foreground message: $e');
    }
  }

  // Handle background messages
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    try {
      await _handleMessage(message);
    } catch (e) {
      print('Error handling background message: $e');
    }
  }

  // Handle message when app is opened from notification
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    try {
      await _handleMessage(message);
    } catch (e) {
      print('Error handling message opened app: $e');
    }
  }

  // Handle general message
  Future<void> _handleMessage(RemoteMessage message) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final data = message.data;
      final notificationType = data?['type'] ?? 'general';
      final title = data?['title'] ?? 'إشعار جديد';
      final body = data?['body'] ?? '';
      final imageUrl = data?['imageUrl'];
      final actionUrl = data?['actionUrl'];

      // Save notification to Firestore
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': notificationType,
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'actionUrl': actionUrl,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Show in-app notification
      await _showInAppNotification(title, body, imageUrl, actionUrl);

      // Update notification counts
      await _updateNotificationCounts(userId, notificationType);

      print('Message handled successfully: $notificationType');
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  // Show in-app notification
  Future<void> _showInAppNotification(
    String title,
    String body,
    String? imageUrl,
    String? actionUrl,
  ) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelID: 'high_importance_channel',
        icon: 'ic_notification',
        largeIcon: 'ic_notification_large',
        styleInformation: AndroidStyleInformation(
          color: const Color(0xFFd4af37),
        ),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: actionUrl,
        bigPicture: imageUrl,
        android: androidDetails,
        iOS: iosDetails,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  // Update notification counts
  Future<void> _updateNotificationCounts(String userId, String notificationType) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final currentCounts = userData['notificationCounts'] ?? {};

      // Increment count for specific notification type
      currentCounts[notificationType] = (currentCounts[notificationType] ?? 0) + 1;

      await _firestore.collection('users').doc(userId).update({
        'notificationCounts': currentCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating notification counts: $e');
    }
  }

  // Get notification counts
  Future<Map<String, int>> getNotificationCounts() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return {};

      final userData = userDoc.data() as Map<String, dynamic>;
      return Map<String, int>.from(userData['notificationCounts'] ?? {});
    } catch (e) {
      print('Error getting notification counts: $e');
      return {};
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      // Update unread count
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', '==', userId)
          .where('isRead', '==', false)
          .get();

      int unreadCount = snapshot.size;
      
      await _firestore.collection('users').doc(userId).update({
        'unreadCount': unreadCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Get notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 20,
    String? type,
    bool unreadOnly = false,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      Query query = _firestore.collection('notifications').where('userId', '==', userId);

      if (type != null) {
        query = query.where('type', '==', type);
      }

      if (unreadOnly) {
        query = query.where('isRead', '==', false);
      }

      final snapshot = await query.orderBy('createdAt', descending: true).limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  // Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String? imageUrl,
    String? actionUrl,
    String type = 'general',
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'actionUrl': actionUrl,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update notification counts
      await _updateNotificationCounts(userId, type);

      // Send push notification (if user has FCM token)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'];
        
        if (fcmToken != null) {
          // This would typically be handled by a Cloud Function
          // For now, we'll just log it
          print('Would send push notification to user $userId with token $fcmToken');
        }
      }
    } catch (e) {
      print('Error sending notification to user: $e');
    }
  }

  // Send alert notification
  Future<void> sendAlertNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'alert',
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update notification counts
      await _updateNotificationCounts(userId, type);

      print('Alert notification sent to user $userId');
    } catch (e) {
      print('Error sending alert notification: $e');
    }
  }

  // Send notification for new follower
  Future<void> sendFollowerNotification({
    required String userId,
    required String followerName,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'follower',
        'title': 'متابع جديد',
        'body': '$followerName يتابعك الآن',
        'followerName': followerName,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update notification counts
      await _updateNotificationCounts(userId, 'follower');

      print('Follower notification sent to user $userId');
    } catch (e) {
      print('Error sending follower notification: $e');
    }
  }

  // Send notification for new like
  Future<void> sendLikeNotification({
    required String userId,
    required String likerName,
    required String postType,
  }) async {
    try {
      final postTypeText = postType == 'image' ? 'صورة' : 'فيديو';
      
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'like',
        'title': 'إعجاب جديد',
        'body': '$likerName أعجب $postTypeText الخاص بك',
        'likerName': likerName,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update notification counts
      await _updateNotificationCounts(userId, 'like');

      print('Like notification sent to user $userId');
    } catch (e) {
      print('Error sending like notification: $e');
    }
  }

  // Send notification for new comment
  Future<void> sendCommentNotification({
    required String userId,
    required String commenterName,
    required String postType,
  }) async {
    try {
      final postTypeText = postType == 'image' ? 'صورة' : 'فيديو';
      
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'comment',
        'title': 'تعليق جديد',
        'body': '$commenterName علق على $postTypeText الخاص بك',
        'commenterName': commenterName,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update notification counts
      await _updateNotificationCounts(userId, 'comment');

      print('Comment notification sent to user $userId');
    } catch (e) {
      print('Error sending comment notification: $e');
    }
  }

  // Send notification for subscription expiry
  Future<void> sendExpiryNotification({
    required String userId,
    required int daysUntilExpiry,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'expiry',
        'title': 'انتهاء الاشتراك',
        'body': 'سينتهي اشتراكك خلال $daysUntilExpiry يوم',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update notification counts
      await _updateNotificationCounts(userId, 'expiry');

      print('Expiry notification sent to user $userId');
    } catch (e) {
      print('Error sending expiry notification: $e');
    }
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['unreadCount'] ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get all notifications for the user
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', '==', userId)
          .get();

      // Mark all as read
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();

      // Reset unread count
      await _firestore.collection('users').doc(userId).update({
        'unreadCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('All notifications cleared for user $userId');
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }
}
