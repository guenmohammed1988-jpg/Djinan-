const functions = require('firebase-functions/v2');
const admin = require('firebase-admin/app');
const { Timestamp } = require('firebase-admin/firestore');

// Initialize Firebase Admin
admin.initializeApp();

exports.initializeFCMToken = functions.https.onCall(async (data, context) => {
  const { userId, token } = data;
  
  console.log(`Initializing FCM token for user: ${userId}`);
  
  try {
    // Save FCM token to user document
    await admin.firestore().collection('users').doc(userId).update({
      fcmToken: token,
      tokenUpdatedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    console.log(`FCM token saved for user: ${userId}`);
    
    return {
      success: true,
      message: 'FCM token initialized successfully',
      userId: userId,
      token: token,
    };
  } catch (error) {
    console.error(`Error saving FCM token: ${error}`);
    
    return {
      success: false,
      message: 'Failed to save FCM token',
      error: error.message,
    };
  }
});

// Send notification to specific user
exports.sendNotification = functions.https.onCall(async (data, context) => {
  const { 
    userId, 
    title, 
    body, 
    imageUrl, 
    actionUrl, 
    type = 'general',
    sendPush = true 
  } = data;
  
  console.log(`Sending notification to user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Create notification document
    const notificationData = {
      userId: userId,
      type: type,
      title: title,
      body: body,
      imageUrl: imageUrl,
      actionUrl: actionUrl,
      isRead: false,
      createdAt: Timestamp.now(),
    };

    const notificationRef = await admin.firestore().collection('notifications').add(notificationData);
    
    // Update notification counts
    await _updateNotificationCounts(userId, type);

    // Send push notification if requested
    if (sendPush) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (fcmToken) {
          // This would typically be handled by FCM
          // For now, we'll just log it
          console.log(`Would send push notification to user ${userId} with token ${fcmToken}`);
        }
      }
    }

    console.log(`Notification sent to user: ${userId}`);
    
    return {
      success: true,
      message: 'Notification sent successfully',
      notificationId: notificationRef.id,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error sending notification: ${error}`);
    
    return {
      success: false,
      message: 'Failed to send notification',
      error: error.message,
    };
  }
});

// Send alert notification
exports.sendAlertNotification = functions.https.onCall(async (data, context) => {
  const { userId, title, body } = data;
  
  console.log(`Sending alert notification to user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Create alert notification
    const notificationData = {
      userId: userId,
      type: 'alert',
      title: title,
      body: body,
      isRead: false,
      createdAt: Timestamp.now(),
    };

    const notificationRef = await admin.firestore().collection('notifications').add(notificationData);
    
    // Update notification counts
    await _updateNotificationCounts(userId, 'alert');

    // Send push notification
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (fcmToken) {
        console.log(`Would send alert notification to user ${userId} with token ${fcmToken}`);
      }
    }

    console.log(`Alert notification sent to user: ${userId}`);
    
    return {
      success: true,
      message: 'Alert notification sent successfully',
      notificationId: notificationRef.id,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error sending alert notification: ${error}`);
    
    return {
      success: false,
      message: 'Failed to send alert notification',
      error: error.message,
    };
  }
});

// Send follower notification
exports.sendFollowerNotification = functions.https.onCall(async (data, context) => {
  const { userId, followerName } = data;
  
  console.log(`Sending follower notification to user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !followerName) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Create follower notification
    const notificationData = {
      userId: userId,
      type: 'follower',
      title: 'متابع جديد',
      body: `${followerName} يتابعك الآن`,
      followerName: followerName,
      isRead: false,
      createdAt: Timestamp.now(),
    };

    const notificationRef = await admin.firestore().collection('notifications').add(notificationData);
    
    // Update notification counts
    await _updateNotificationCounts(userId, 'follower');

    // Send push notification
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (fcmToken) {
        console.log(`Would send follower notification to user ${userId} with token ${fcmToken}`);
      }
    }

    console.log(`Follower notification sent to user: ${userId}`);
    
    return {
      success: true,
      message: 'Follower notification sent successfully',
      notificationId: notificationRef.id,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error sending follower notification: ${error}`);
    
    return {
      success: false,
      message: 'Failed to send follower notification',
      error: error.message,
    };
  }
});

// Send like notification
exports.sendLikeNotification = functions.https.onCall(async (data, context) => {
  const { userId, likerName, postType } = data;
  
  console.log(`Sending like notification to user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !likerName || !postType) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    const postTypeText = postType === 'image' ? 'صورة' : 'فيديو';
    
    // Create like notification
    const notificationData = {
      userId: userId,
      type: 'like',
      title: 'إعجاب جديد',
      body: `${likerName} أعجب ${postTypeText} الخاص بك`,
      likerName: likerName,
      isRead: false,
      createdAt: Timestamp.now(),
    };

    const notificationRef = await admin.firestore().collection('notifications').add(notificationData);
    
    // Update notification counts
    await _updateNotificationCounts(userId, 'like');

    // Send push notification
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (fcmToken) {
        console.log(`Would send like notification to user ${userId} with token ${fcmToken}`);
      }
    }

    console.log(`Like notification sent to user: ${userId}`);
    
    return {
      success: true,
      message: 'Like notification sent successfully',
      notificationId: notificationRef.id,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error sending like notification: ${error}`);
    
    return {
      success: false,
      message: 'Failed to send like notification',
      error: error.message,
    };
  }
});

// Send comment notification
exports.sendCommentNotification = functions.https.onCall(async (data, context) => {
  const { userId, commenterName, postType } = data;
  
  console.log(`Sending comment notification to user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !commenterName || !postType) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    const postTypeText = postType === 'image' ? 'صورة' : 'فيديو';
    
    // Create comment notification
    const notificationData = {
      userId: userId,
      type: 'comment',
      title: 'تعليق جديد',
      body: `${commenterName} علق على ${postTypeText} الخاص بك`,
      commenterName: commenterName,
      isRead: false,
      createdAt: Timestamp.now(),
    };

    const notificationRef = await admin.firestore().collection('notifications').add(notificationData);
    
    // Update notification counts
    await _updateNotificationCounts(userId, 'comment');

    // Send push notification
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (fcmToken) {
        console.log(`Would send comment notification to user ${userId} with token ${fcmToken}`);
      }
    }

    console.log(`Comment notification sent to user: ${userId}`);
    
    return {
      success: true,
      message: 'Comment notification sent successfully',
      notificationId: notificationRef.id,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error sending comment notification: ${error}`);
    
    return {
      success: false,
      message: 'Failed to send comment notification',
      error: error.message,
    };
  }
});

// Send subscription expiry notification
exports.sendExpiryNotification = functions.https.onCall(async (data, context) => {
  const { userId, daysUntilExpiry } = data;
  
  console.log(`Sending expiry notification to user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || daysUntilExpiry === undefined) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Create expiry notification
    const notificationData = {
      userId: userId,
      type: 'expiry',
      title: 'انتهاء الاشتراك',
      body: `سينتهي اشتراكك خلال ${daysUntilExpiry} يوم`,
      isRead: false,
      createdAt: Timestamp.now(),
    };

    const notificationRef = await admin.firestore().collection('notifications').add(notificationData);
    
    // Update notification counts
    await _updateNotificationCounts(userId, 'expiry');

    // Send push notification
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (fcmToken) {
        console.log(`Would send expiry notification to user ${userId} with token ${fcmToken}`);
      }
    }

    console.log(`Expiry notification sent to user: ${userId}`);
    
    return {
      success: true,
      message: 'Expiry notification sent successfully',
      notificationId: notificationRef.id,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error sending expiry notification: ${error}`);
    
    return {
      success: false,
      message: 'Failed to send expiry notification',
      error: error.message,
    };
  }
});

// Get notifications for user
exports.getNotifications = functions.https.onCall(async (data, context) => {
  const { userId, limit = 20, type, unreadOnly = false } = data;
  
  console.log(`Getting notifications for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    let query = admin.firestore().collection('notifications').where('userId', '==', userId);
    
    if (type) {
      query = query.where('type', '==', type);
    }
    
    if (unreadOnly) {
      query = query.where('isRead', '==', false);
    }

    const snapshot = await query.orderBy('createdAt', 'desc').limit(limit).get();
    
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    })).toArray();

    console.log(`Retrieved ${notifications.length} notifications for user: ${userId}`);
    
    return {
      success: true,
      message: 'Notifications retrieved successfully',
      notifications: notifications,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error getting notifications: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get notifications',
      error: error.message,
    };
  }
});

// Mark notification as read
exports.markNotificationAsRead = functions.https.onCall(async (data, context) => {
  const { userId, notificationId } = data;
  
  console.log(`Marking notification as read: ${notificationId}`);
  
  try {
    // Validate input
    if (!userId || !notificationId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Update notification
    await admin.firestore().collection('notifications').doc(notificationId).update({
      isRead: true,
      readAt: Timestamp.now(),
    });

    // Update unread count
    const unreadSnapshot = await admin.firestore()
      .collection('notifications')
      .where('userId', '==', userId)
      .where('isRead', '==', false)
      .get();

    const unreadCount = unreadSnapshot.size;
    
    await admin.firestore().collection('users').doc(userId).update({
      unreadCount: unreadCount,
      updatedAt: Timestamp.now(),
    });

    console.log(`Notification marked as read: ${notificationId}`);
    
    return {
      success: true,
      message: 'Notification marked as read successfully',
      notificationId: notificationId,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error marking notification as read: ${error}`);
    
    return {
      success: false,
      message: 'Failed to mark notification as read',
      error: error.message,
    };
  }
});

// Clear all notifications for user
exports.clearAllNotifications = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Clearing all notifications for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Get all notifications for user
    const snapshot = await admin.firestore()
      .collection('notifications')
      .where('userId', '==', userId)
      .get();

    // Mark all as read
    const batch = admin.firestore().batch();
    
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        isRead: true,
        readAt: Timestamp.now(),
      });
    }
    
    await batch.commit();

    // Reset unread count
    await admin.firestore().collection('users').doc(userId).update({
      unreadCount: 0,
      updatedAt: Timestamp.now(),
    });

    console.log(`All notifications cleared for user: ${userId}`);
    
    return {
      success: true,
      message: 'All notifications cleared successfully',
      userId: userId,
    };
  } catch (error) {
    console.error(`Error clearing notifications: ${error}`);
    
    return {
      success: false,
      message: 'Failed to clear notifications',
      error: error.message,
    };
  }
});

// Get notification counts
exports.getNotificationCounts = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Getting notification counts for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        success: true,
        message: 'No notification counts found',
        counts: {},
      };
    }

    const userData = userDoc.data();
    const counts = userData.notificationCounts || {};

    console.log(`Retrieved notification counts for user: ${userId}`);
    
    return {
      success: true,
      message: 'Notification counts retrieved successfully',
      counts: counts,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error getting notification counts: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get notification counts',
      error: error.message,
    };
  }
});

// Helper function to update notification counts
async function _updateNotificationCounts(userId, notificationType) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log(`User document not found: ${userId}`);
      return;
    }

    const userData = userDoc.data();
    const currentCounts = userData.notificationCounts || {};

    // Increment count for specific notification type
    currentCounts[notificationType] = (currentCounts[notificationType] || 0) + 1;

    await admin.firestore().collection('users').doc(userId).update({
      notificationCounts: currentCounts,
      updatedAt: Timestamp.now(),
    });

    console.log(`Updated notification counts for user: ${userId}, type: ${notificationType}`);
  } catch (error) {
    console.error(`Error updating notification counts: ${error}`);
  }
}
};
