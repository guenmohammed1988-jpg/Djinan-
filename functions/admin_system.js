const functions = require('firebase-functions/v2');
const admin = require('firebase-admin/app');
const { Timestamp } = require('firebase-admin/firestore');

// Initialize Firebase Admin
admin.initializeApp();

// Get all users
exports.getAllUsers = functions.https.onCall(async (data, context) => {
  const { limit = 20 } = data;
  
  console.log(`Getting all users with limit: ${limit}`);
  
  try {
    // Validate input
    if (limit < 1 || limit > 100) {
      throw new functions.https.HttpsError('invalid-argument', 'Limit must be between 1 and 100');
    }

    // Get all users
    const snapshot = await admin.firestore().collection('users').limit(limit).get();
    
    const users = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    })).toArray();

    console.log(`Retrieved ${users.length} users`);
    
    return {
      success: true,
      message: 'Users retrieved successfully',
      users: users,
      count: users.length,
    };
  } catch (error) {
    console.error(`Error getting all users: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get users',
      error: error.message,
    };
  }
});

// Update user role
exports.updateUserRole = functions.https.onCall(async (data, context) => {
  const { userId, role } = data;
  
  console.log(`Updating user role to: ${role} for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !role) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId or role');
    }

    // Validate role
    const validRoles = ['user', 'merchant', 'admin'];
    if (!validRoles.includes(role)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid role. Must be user, merchant, or admin');
    }

    // Update user role
    await admin.firestore().collection('users').doc(userId).update({
      role: role,
      updatedAt: Timestamp.now(),
    });

    console.log(`User role updated to: ${role} for user: ${userId}`);
    
    return {
      success: true,
      message: 'User role updated successfully',
      userId: userId,
      role: role,
    };
  } catch (error) {
    console.error(`Error updating user role: ${error}`);
    
    return {
      success: false,
      message: 'Failed to update user role',
      error: error.message,
    };
  }
});

// Ban user
exports.banUser = functions.https.onCall(async (data, context) => {
  const { userId, reason, banDurationDays = 30 } = data;
  
  console.log(`Banning user: ${userId} for reason: ${reason}`);
  
  try {
    // Validate input
    if (!userId || !reason) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId or reason');
    }

    // Validate ban duration
    if (banDurationDays < 1 || banDurationDays > 365) {
      throw new functions.https.HttpsError('invalid-argument', 'Ban duration must be between 1 and 365 days');
    }

    const banExpiresAt = Timestamp.now().toDate();
    banExpiresAt.setDate(banExpiresAt.getDate() + banDurationDays);

    // Ban user
    await admin.firestore().collection('users').doc(userId).update({
      isBanned: true,
      banReason: reason,
      banExpiresAt: Timestamp.fromDate(banExpiresAt),
      updatedAt: Timestamp.now(),
    });

    // Log ban action
    await admin.firestore().collection('admin_actions').add({
      userId: userId,
      action: 'ban',
      reason: reason,
      banDurationDays: banDurationDays,
      banExpiresAt: Timestamp.fromDate(banExpiresAt),
      performedBy: context.auth?.uid || 'system',
      performedAt: Timestamp.now(),
    });

    console.log(`User banned: ${userId} until ${banExpiresAt.toISOString()}`);
    
    return {
      success: true,
      message: 'User banned successfully',
      userId: userId,
      banExpiresAt: banExpiresAt.toISOString(),
    };
  } catch (error) {
    console.error(`Error banning user: ${error}`);
    
    return {
      success: false,
      message: 'Failed to ban user',
      error: error.message,
    };
  }
});

// Unban user
exports.unbanUser = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Unbanning user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Unban user
    await admin.firestore().collection('users').doc(userId).update({
      isBanned: false,
      banReason: '',
      banExpiresAt: null,
      updatedAt: Timestamp.now(),
    });

    // Log unban action
    await admin.firestore().collection('admin_actions').add({
      userId: userId,
      action: 'unban',
      performedBy: context.auth?.uid || 'system',
      performedAt: Timestamp.now(),
    });

    console.log(`User unbanned: ${userId}`);
    
    return {
      success: true,
      message: 'User unbanned successfully',
      userId: userId,
    };
  } catch (error) {
    console.error(`Error unbanning user: ${error}`);
    
    return {
      success: false,
      message: 'Failed to unban user',
      error: error.message,
    };
  }
});

// Delete user
exports.deleteUser = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Deleting user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Get user document
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        success: false,
        message: 'User not found',
      };
    }

    // Delete all related data
    const batch = admin.firestore.batch();
    
    // Delete user document
    batch.delete(userDoc.ref);
    
    // Delete user activity data
    const activitySnapshot = await admin.firestore()
      .collection('daily_activity')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of activitySnapshot.docs) {
      batch.delete(doc.ref);
    }
    
    // Delete user fraud scores
    const fraudSnapshot = await admin.firestore()
      .collection('fraud_scores')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of fraudSnapshot.docs) {
      batch.delete(doc.ref);
    }
    
    // Delete user reports
    const reportsSnapshot = await admin.firestore()
      .collection('moderation_reports')
      .where('reporterId', '==', userId)
      .get();
    
    for (const doc of reportsSnapshot.docs) {
      batch.delete(doc.ref);
    }
    
    // Delete user content
    const contentSnapshot = await admin.firestore()
      .collection('posts')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of contentSnapshot.docs) {
      batch.delete(doc.ref);
    }
    
    // Execute batch
    await batch.commit();

    // Log deletion action
    await admin.firestore().collection('admin_actions').add({
      userId: userId,
      action: 'delete',
      performedBy: context.auth?.uid || 'system',
      performedAt: Timestamp.now(),
    });

    console.log(`User deleted: ${userId}`);
    
    return {
      success: true,
      message: 'User deleted successfully',
      userId: userId,
    };
  } catch (error) {
    console.error(`Error deleting user: ${error}`);
    
    return {
      success: false,
      message: 'Failed to delete user',
      error: error.message,
    };
  }
});

// Get user statistics
exports.getUserStatistics = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Getting user statistics for: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Get user document
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        success: false,
        message: 'User not found',
        statistics: {},
      };
    }

    const userData = userDoc.data();
    
    // Get all users for statistics
    const allUsersSnapshot = await admin.firestore().collection('users').get();
    const allUsers = allUsersSnapshot.docs.map(doc => doc.data()).toArray();
    
    // Calculate statistics
    let activeCount = 0;
    let bannedCount = 0;
    let highRiskCount = 0;
    let adminCount = 0;
    let merchantCount = 0;
    let userCount = 0;
    
    for (const user of allUsers) {
      const userRole = user.role || 'user';
      const isBanned = user.isBanned || false;
      const fraudScore = user.fraudScore || 100.0;
      
      if (user.isActive === true && userRole === 'user') {
        userCount++;
      }
      
      if (userRole === 'admin') {
        adminCount++;
      }
      
      if (userRole === 'merchant') {
        merchantCount++;
      }
      
      if (isBanned) {
        bannedCount++;
      }
      
      if (fraudScore < 50) {
        highRiskCount++;
      }
    }

    const statistics = {
      totalUsers: allUsers.length,
      activeUsers: userCount,
      bannedUsers: bannedCount,
      highRiskUsers: highRiskCount,
      adminUsers: adminCount,
      merchantUsers: merchantCount,
      regularUsers: userCount,
      userRole: userData.role,
      createdAt: userData.createdAt,
      lastLogin: userData.lastLogin,
      isActive: userData.isActive,
      isBanned: userData.isBanned,
      banReason: userData.banReason,
      banExpiresAt: userData.banExpiresAt,
      fraudScore: userData.fraudScore,
    };

    console.log(`User statistics calculated for: ${userId}`);
    
    return {
      success: true,
      message: 'User statistics retrieved successfully',
      statistics: statistics,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error getting user statistics: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get user statistics',
      error: error.message,
    };
  }
});

// Get content moderation statistics
exports.getContentModerationStatistics = functions.https.onCall(async (data, context) => {
  console.log(`Getting content moderation statistics`);
  
  try {
    // Get flagged content
    const flaggedSnapshot = await admin.firestore().collection('flagged_content').get();
    const flaggedCount = flaggedSnapshot.size;
    
    // Get moderation queue
    const queueSnapshot = await admin.firestore().collection('moderation_queue').get();
    const queueCount = queueSnapshot.size;
    
    // Get moderation reports
    const reportsSnapshot = await admin.firestore().collection('moderation_reports').get();
    const reportsCount = reportsSnapshot.size;
    
    // Get content statistics
    const contentSnapshot = await admin.firestore().collection('posts').get();
    const totalContent = contentSnapshot.size;
    
    // Calculate approval rates
    const approvedCount = contentSnapshot.docs.filter(doc => doc.data().status === 'approved').length;
    const rejectedCount = contentSnapshot.docs.filter(doc => doc.data().status === 'rejected').length;
    const pendingCount = contentSnapshot.docs.filter(doc => doc.data().status === 'pending').length;
    
    const statistics = {
      flaggedContent: flaggedCount,
      moderationQueue: queueCount,
      moderationReports: reportsCount,
      totalContent: totalContent,
      approvedContent: approvedCount,
      rejectedContent: rejectedCount,
      pendingContent: pendingCount,
      approvalRate: totalContent > 0 ? (approvedCount / totalContent * 100).toFixed(2) : 0,
      rejectionRate: totalContent > 0 ? (rejectedCount / totalContent * 100).toFixed(2) : 0,
    };

    console.log(`Content moderation statistics calculated`);
    
    return {
      success: true,
      message: 'Content moderation statistics retrieved successfully',
      statistics: statistics,
    };
  } catch (error) {
    console.error(`Error getting content moderation statistics: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get content moderation statistics',
      error: error.message,
    };
  }
});

// Get fraud scores
exports.getFraudScores = functions.https.onCall(async (data, context) => {
  const { limit = 50 } = data;
  
  console.log(`Getting fraud scores with limit: ${limit}`);
  
  try {
    // Validate input
    if (limit < 1 || limit > 100) {
      throw new functions.https.HttpsError('invalid-argument', 'Limit must be between 1 and 100');
    }

    // Get fraud scores
    const snapshot = await admin.firestore()
      .collection('fraud_scores')
      .orderBy('calculatedAt', 'desc')
      .limit(limit)
      .get();
    
    const fraudScores = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    })).toArray();

    console.log(`Retrieved ${fraudScores.length} fraud scores`);
    
    return {
      success: true,
      message: 'Fraud scores retrieved successfully',
      fraudScores: fraudScores,
      count: fraudScores.length,
    };
  } catch (error) {
    console.error(`Error getting fraud scores: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get fraud scores',
      error: error.message,
    };
  }
});

// Update content moderation status
exports.updateContentStatus = functions.https.onCall(async (data, context) => {
  const { contentId, status, moderatorNote } = data;
  
  console.log(`Updating content status to: ${status} for content: ${contentId}`);
  
  try {
    // Validate input
    if (!contentId || !status) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing contentId or status');
    }

    // Validate status
    const validStatuses = ['approved', 'rejected', 'deleted'];
    if (!validStatuses.includes(status)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid status. Must be approved, rejected, or deleted');
    }

    // Update content status
    await admin.firestore().collection('posts').doc(contentId).update({
      status: status,
      moderatorNote: moderatorNote,
      reviewedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    // Log moderation action
    await admin.firestore().collection('admin_actions').add({
      contentId: contentId,
      action: 'update_status',
      status: status,
      moderatorNote: moderatorNote,
      performedBy: context.auth?.uid || 'system',
      performedAt: Timestamp.now(),
    });

    console.log(`Content status updated: ${contentId} -> ${status}`);
    
    return {
      success: true,
      message: 'Content status updated successfully',
      contentId: contentId,
      status: status,
    };
  } catch (error) {
    console.error(`Error updating content status: ${error}`);
    
    return {
      success: false,
      message: 'Failed to update content status',
      error: error.message,
    };
  }
});

// Search users
exports.searchUsers = functions.https.onCall(async (data, context) => {
  const { query, limit = 20 } = data;
  
  console.log(`Searching users with query: ${query}, limit: ${limit}`);
  
  try {
    // Validate input
    if (!query) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing search query');
    }

    // Validate limit
    if (limit < 1 || limit > 100) {
      throw new functions.https.HttpsError('invalid-argument', 'Limit must be between 1 and 100');
    }

    // Search users
    const snapshot = await admin.firestore()
      .collection('users')
      .where('name', '>=', query)
      .limit(limit)
      .get();
    
    const users = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    })).toArray();

    console.log(`Found ${users.length} users matching query: ${query}`);
    
    return {
      success: true,
      message: 'Users searched successfully',
      users: users,
      count: users.length,
      query: query,
    };
  } catch (error) {
    console.error(`Error searching users: ${error}`);
    
    return {
      success: false,
      message: 'Failed to search users',
      error: error.message,
    };
  }
});

// Get content reports
exports.getContentReports = functions.https.onCall(async (data, context) => {
  const { limit = 50 } = data;
  
  console.log(`Getting content reports with limit: ${limit}`);
  
  try {
    // Validate input
    if (limit < 1 || limit > 100) {
      throw new functions.https.HttpsError('invalid-argument', 'Limit must be between 1 and 100');
    }

    // Get content reports
    const snapshot = await admin.firestore()
      .collection('moderation_reports')
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();
    
    const reports = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    })).toArray();

    console.log(`Retrieved ${reports.length} content reports`);
    
    return {
      success: true,
      message: 'Content reports retrieved successfully',
      reports: reports,
      count: reports.length,
    };
  } catch (error) {
    console.error(`Error getting content reports: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get content reports',
      error: error.message,
    };
  }
});
