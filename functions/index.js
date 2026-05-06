const functions = require('firebase-functions/v2');
const admin = require('firebase-admin/app');
const { Storage } = require('@google-cloud/storage');

// Data processing function
exports.processUserData = functions.https.onCall(async (data, context) => {
  const { uid, collection, document, operation, data: { userId, collection, document, operation, data } } = data;
  const { collection, document } = data;
  
  console.log(`Processing user data: ${userId} in ${collection}/${document}`);
  
  try {
    // Validate user data
    const userData = data.data;
    if (!userData || typeof userData !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid user data provided');
    }
    
    // Process different operations
    let result;
    
    switch (operation) {
      case 'updateProfile':
        result = await processProfileUpdate(userData);
        break;
      case 'updateSettings':
        result = await processSettingsUpdate(userData);
        break;
      case 'updatePreferences':
        result = await processPreferencesUpdate(userData);
        break;
      case 'validateEmail':
        result = await processEmailValidation(userData);
        break;
      case 'validatePhone':
        result = await processPhoneValidation(userData);
        break;
      case 'updateLocation':
        result = await processLocationUpdate(userData);
        break;
      case 'cleanupOldData':
        result = await processOldDataCleanup(userData);
        break;
      default:
        throw new functions.https.HttpsError('invalid-operation', `Unknown operation: ${operation}`);
    }
    
    // Log the operation
    await logDataOperation(userId, operation, userData, result);
    
    return {
      success: true,
      message: 'Data processed successfully',
      result: result,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    console.error(`Error processing user data: ${error}`);
    await logDataOperation(userId, operation, data, { success: false, error: error.message });
    
    throw new functions.https.HttpsError('processing-error', error.message);
  }
});

// Profile update processing
async function processProfileUpdate(userData) {
  const { displayName, email, phoneNumber, photoURL, bio } = userData;
  
  // Validate required fields
  if (!displayName || displayName.trim().length < 2) {
    throw new Error('Display name must be at least 2 characters');
  }
  
  if (!email || !isValidEmail(email)) {
    throw new Error('Invalid email format');
  }
  
  // Update user profile in Firestore
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userData.userId);
  
  await userRef.update({
    displayName: displayName.trim(),
    email: email.toLowerCase().trim(),
    phoneNumber: phoneNumber,
    photoURL: photoURL,
    bio: bio,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    profileCompleted: calculateProfileCompletion({ displayName, email, phoneNumber, photoURL, bio }),
  });
  
  return {
    operation: 'profileUpdate',
    fieldsUpdated: { displayName, email, phoneNumber, photoURL, bio },
  };
}

// Settings update processing
async function processSettingsUpdate(userData) {
  const { notifications, darkMode, language, privacy } = userData;
  
  // Validate settings
  if (typeof notifications !== 'boolean' || 
      typeof darkMode !== 'boolean' || 
      typeof language !== 'string' || 
      typeof privacy !== 'string') {
    throw new Error('Invalid settings data types');
  }
  
  // Update user settings in Firestore
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userData.userId);
  
  await userRef.update({
    settings: {
      notifications: notifications,
      darkMode: darkMode,
      language: language,
      privacy: privacy,
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return {
    operation: 'settingsUpdate',
    settingsUpdated: { notifications, darkMode, language, privacy },
  };
}

// Preferences update processing
async function processPreferencesUpdate(userData) {
  const { preferences } = userData;
  
  // Validate preferences
  if (!preferences || typeof preferences !== 'object') {
    throw new Error('Invalid preferences data');
  }
  
  // Update user preferences in Firestore
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userData.userId);
  
  await userRef.update({
    preferences: preferences,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return {
    operation: 'preferencesUpdate',
    preferencesUpdated: preferences,
  };
}

// Email validation processing
async function processEmailValidation(userData) {
  const { email } = userData;
  
  if (!email || !isValidEmail(email)) {
    throw new Error('Invalid email format');
  }
  
  // Check if email is already in use
  const db = admin.firestore();
  const existingUsers = await db.collection('users')
    .where('email', '==', email.toLowerCase().trim())
    .get();
  
  if (!existingUsers.empty) {
    throw new Error('Email already in use');
  }
  
  return {
    operation: 'emailValidation',
    email: email,
    isValid: isValidEmail(email),
    isAvailable: existingUsers.empty,
  };
}

// Phone validation processing
async function processPhoneValidation(userData) {
  const { phoneNumber } = userData;
  
  if (!phoneNumber || !isValidPhone(phoneNumber)) {
    throw new Error('Invalid phone number format');
  }
  
  // Check if phone is already in use
  const db = admin.firestore();
  const existingUsers = await db.collection('users')
    .where('phoneNumber', '==', phoneNumber)
    .get();
  
  if (!existingUsers.empty) {
    throw new Error('Phone number already in use');
  }
  
  return {
    operation: 'phoneValidation',
    phoneNumber: phoneNumber,
    isValid: isValidPhone(phoneNumber),
    isAvailable: existingUsers.empty,
  };
}

// Location update processing
async function processLocationUpdate(userData) {
  const { latitude, longitude, address } = userData;
  
  // Validate coordinates
  if (!isValidCoordinate(latitude) || !isValidCoordinate(longitude)) {
    throw new Error('Invalid coordinates');
  }
  
  // Update user location in Firestore
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userData.userId);
  
  await userRef.update({
    location: {
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      address: address,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  });
  
  return {
    operation: 'locationUpdate',
    locationUpdated: { latitude, longitude, address },
  };
}

// Old data cleanup processing
async function processOldDataCleanup(userData) {
  const { daysToKeep } = userData;
  const days = parseInt(daysToKeep) || 90;
  
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - days);
  
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userData.userId);
  
  // Clean up old activity logs
  const oldActivities = await db.collection('user_activities')
    .where('userId', '==', userData.userId)
    .where('timestamp', '<', cutoffDate)
    .get();
  
  const batch = db.batch();
  oldActivities.forEach(doc => batch.delete(doc.ref));
  
  await batch.commit();
  
  // Clean up old notifications
  const oldNotifications = await db.collection('notifications')
    .where('userId', '==', userData.userId)
    .where('timestamp', '<', cutoffDate)
    .get();
  
  const notificationsBatch = db.batch();
  oldNotifications.forEach(doc => notificationsBatch.delete(doc.ref));
  
  await notificationsBatch.commit();
  
  return {
    operation: 'dataCleanup',
    daysCleaned: days,
    activitiesDeleted: oldActivities.size,
    notificationsDeleted: oldNotifications.size,
  };
}

// Validation helpers
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+@[^\s@]+$/;
  return emailRegex.test(email);
}

function isValidPhone(phone) {
  const phoneRegex = /^\+?[0-9]{1,}?[0-9]{3,14}$/;
  return phoneRegex.test(phone);
}

function isValidCoordinate(coord) {
  const num = parseFloat(coord);
  return !isNaN(num) && num >= -90 && num <= 90;
}

function calculateProfileCompletion({ displayName, email, phoneNumber, photoURL, bio }) {
  let score = 0;
  let totalFields = 0;
  
  if (displayName && displayName.trim().length > 0) {
    score += 20;
    totalFields++;
  }
  
  if (email && isValidEmail(email)) {
    score += 20;
    totalFields++;
  }
  
  if (phoneNumber && isValidPhone(phoneNumber)) {
    score += 20;
    totalFields++;
  }
  
  if (photoURL) {
    score += 20;
    totalFields++;
  }
  
  if (bio && bio.trim().length > 0) {
    score += 20;
    totalFields++;
  }
  
  return Math.round((score / (totalFields * 20)) * 100;
}

// Logging function
async function logDataOperation(userId, operation, data, result) {
  const db = admin.firestore();
  
  await db.collection('data_operations').add({
    userId: userId,
    operation: operation,
    data: data,
    result: result,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    processedAt: new Date().toISOString(),
  });
}

// Automated data management function
exports.automatedDataManagement = functions.pubsub.schedule('0 2 * * * *')
  .onRun(async (context) => {
    console.log('Running automated data management...');
    
    try {
      const db = admin.firestore();
      
      // Clean up inactive user accounts
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      const inactiveUsers = await db.collection('users')
        .where('lastLoginAt', '<', thirtyDaysAgo)
        .get();
      
      const batch = db.batch();
      inactiveUsers.forEach(doc => {
        batch.delete(doc.ref);
        batch.set(doc.ref, {
          status: 'deleted',
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason: 'inactive_account_cleanup'
        });
      });
      
      await batch.commit();
      
      // Update user statistics
      const stats = await db.collection('user_statistics').doc('daily').get();
      const statsData = stats.exists ? stats.data() : {};
      
      await db.collection('user_statistics').doc('daily').set({
        totalUsers: admin.firestore.FieldValue.increment(-inactiveUsers.size),
        activeUsers: statsData.activeUsers || 0,
        deletedUsers: admin.firestore.FieldValue.increment(inactiveUsers.size),
        lastCleanup: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Archive old data
      const archiveDate = new Date();
      archiveDate.setDate(archiveDate.getDate() - 90);
      
      const oldDataToArchive = await db.collection('user_activities')
        .where('timestamp', '<', archiveDate)
        .limit(1000)
        .get();
      
      if (!oldDataToArchive.empty) {
        const archiveBatch = db.batch();
        oldDataToArchive.forEach(doc => {
          archiveBatch.set(doc.ref, {
            ...doc.data(),
            archived: true,
            archivedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        
        await archiveBatch.commit();
      }
      
      console.log(`Automated management completed. Processed ${inactiveUsers.size} inactive accounts and archived ${oldDataToArchive.size} old records.`);
      
      return {
        success: true,
        message: 'Automated data management completed successfully',
        inactiveAccountsProcessed: inactiveUsers.size,
        oldRecordsArchived: oldDataToArchive.size,
      };
    } catch (error) {
      console.error(`Automated management error: ${error}`);
      return {
        success: false,
        message: error.message,
      };
    }
  }
);

// Data export function
exports.exportUserData = functions.https.onCall(async (data, context) => {
  const { userId, format, collections } = data;
  
  console.log(`Exporting data for user: ${userId} in format: ${format}`);
  
  try {
    const db = admin.firestore();
    let exportData = {};
    
    // Export specified collections
    for (const collectionName of collections) {
      const collection = db.collection(collectionName);
      const snapshot = await collection.where('userId', '==', userId).get();
      
      exportData[collectionName] = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));
    }
    
    // Store export in Cloud Storage
    const timestamp = new Date().toISOString();
    const fileName = `user_data_${userId}_${timestamp}.json`;
    
    await Storage.bucket('djinan-exports').file(fileName).save(
      JSON.stringify(exportData),
      {
        metadata: {
          contentType: 'application/json',
          userId: userId,
          exportDate: timestamp,
        },
      }
    );
    
    // Generate download URL
    const [url] = await Storage.bucket('djinan-exports').file(fileName).getSignedUrl({
      action: 'read',
      expires: '03-01-2025', // 1 year expiry
    });
    
    return {
      success: true,
      message: 'Data exported successfully',
      downloadUrl: url[0],
      fileName: fileName,
      collections: collections,
      recordCount: Object.values(exportData).reduce((sum, collection) => sum + collection.length, 0),
    };
  } catch (error) {
    console.error(`Export error: ${error}`);
    throw new functions.https.HttpsError('export-error', error.message);
  }
});

// Data analytics function
exports.generateUserAnalytics = functions.https.onCall(async (data, context) => {
  const { userId, period } = data;
  
  console.log(`Generating analytics for user: ${userId} over period: ${period}`);
  
  try {
    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('user-not-found', 'User not found');
    }
    
    const userData = userDoc.data();
    const createdAt = userData.createdAt?.toDate();
    
    if (!createdAt) {
      throw new Error('User creation date not found');
    }
    
    // Calculate analytics data
    const now = new Date();
    const startDate = new Date(createdAt);
    startDate.setDate(startDate.getDate() - (period === '30days' ? 30 : period === '7days' ? 7 : 1));
    
    const activities = await db.collection('user_activities')
      .where('userId', '==', userId)
      .where('timestamp', '>=', startDate)
      .where('timestamp', '<=', now)
      .orderBy('timestamp', 'desc')
      .get();
    
    // Process activities
    const analytics = {
      totalActivities: activities.size,
      activeDays: calculateActiveDays(activities.docs, createdAt, now),
      mostActiveDay: findMostActiveDay(activities.docs),
      averageActivitiesPerDay: activities.size / Math.ceil((now - startDate) / (1000 * 60 * 60 * 24)), // days difference
      profileCompletion: calculateProfileCompletion(userData),
      accountAge: Math.floor((now - createdAt) / (1000 * 60 * 60 * 24)), // days
    };
    
    // Store analytics
    await db.collection('user_analytics').add({
      userId: userId,
      period: period,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      analytics: analytics,
      createdAt: createdAt,
    });
    
    return {
      success: true,
      message: 'Analytics generated successfully',
      analytics: analytics,
      period: period,
    };
  } catch (error) {
    console.error(`Analytics error: ${error}`);
    throw new functions.https.HttpsError('analytics-error', error.message);
  }
});

// Helper functions
function calculateActiveDays(activities, createdAt, now) {
  const activeDays = new Set();
  
  activities.forEach(activity => {
    const activityDate = activity.data().timestamp.toDate();
    const daysDiff = Math.floor((now - activityDate) / (1000 * 60 * 60 * 24));
    
    if (daysDiff < 30) {
      activeDays.add(daysDiff);
    }
  });
  
  return activeDays.size;
}

function findMostActiveDay(activities) {
  const dayCounts = {};
  
  activities.forEach(activity => {
    const day = activity.data().timestamp.toDate().getDay();
    dayCounts[day] = (dayCounts[day] || 0) + 1;
  });
  
  let mostActiveDay = 0;
  let maxCount = 0;
  
  for (const [day, count] of Object.entries(dayCounts)) {
    if (count > maxCount) {
      maxCount = count;
      mostActiveDay = parseInt(day);
    }
  }
  
  return mostActiveDay;
}
