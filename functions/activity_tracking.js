const functions = require('firebase-functions/v2');
const admin = require('firebase-admin/app');
const { Timestamp } = require('firebase-admin/firestore');

// Initialize Firebase Admin
admin.initializeApp();

// Start activity tracking
exports.startActivityTracking = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Starting activity tracking for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Initialize activity tracking for user
    await admin.firestore().collection('users').doc(userId).update({
      'activityTracking': {
        'isTracking': true,
        'totalMinutes': 0,
        'dailyMinutes': 0,
        'weeklyMinutes': 0,
        'monthlyMinutes': 0,
        'updatedAt': Timestamp.now(),
      },
      'updatedAt': Timestamp.now(),
    });

    console.log(`Activity tracking started for user: ${userId}`);
    
    return {
      success: true,
      message: 'Activity tracking started successfully',
      userId: userId,
    };
  } catch (error) {
    console.error(`Error starting activity tracking: ${error}`);
    
    return {
      success: false,
      message: 'Failed to start activity tracking',
      error: error.message,
    };
  }
});

// Stop activity tracking
exports.stopActivityTracking = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Stopping activity tracking for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Stop activity tracking for user
    await admin.firestore().collection('users').doc(userId).update({
      'activityTracking.isTracking': false,
      'updatedAt': Timestamp.now(),
    });

    console.log(`Activity tracking stopped for user: ${userId}`);
    
    return {
      success: true,
      message: 'Activity tracking stopped successfully',
      userId: userId,
    };
  } catch (error) {
    console.error(`Error stopping activity tracking: ${error}`);
    
    return {
      success: false,
      message: 'Failed to stop activity tracking',
      error: error.message,
    };
  }
});

// Update activity data (called every minute by timer)
exports.updateActivityData = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Updating activity data for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Get current user data
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        success: false,
        message: 'User not found',
      };
    }

    const userData = userDoc.data();
    const activityTracking = userData.activityTracking || {};

    // Get current date info
    const now = Timestamp.now().toDate();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const weekStart = new Date(today);
    weekStart.setDate(today.getDate() - today.getDay() + 1);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    // Calculate time periods
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterdayEnd = new Date(yesterday.getFullYear(), yesterday.getMonth(), yesterday.getDate(), 23, 59, 59);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 6);
    const monthEnd = new Date(monthStart);
    monthEnd.setMonth(monthStart.getMonth() + 1);

    // Update counters
    const totalMinutes = (activityTracking.totalMinutes || 0) + 1;
    const dailyMinutes = (activityTracking.dailyMinutes || 0) + 1;

    // Check if we need to reset weekly/monthly counters
    let weeklyMinutes = activityTracking.weeklyMinutes || 0;
    let monthlyMinutes = activityTracking.monthlyMinutes || 0;

    if (now.getTime() >= weekEnd.getTime() || now.getTime() >= monthEnd.getTime()) {
      weeklyMinutes = 0;
      monthlyMinutes = 0;
    }

    // Store activity data
    await admin.firestore().collection('users').doc(userId).update({
      'activityTracking': {
        'isTracking': true,
        'totalMinutes': totalMinutes,
        'dailyMinutes': dailyMinutes,
        'weeklyMinutes': weeklyMinutes,
        'monthlyMinutes': monthlyMinutes,
        'lastActivity': Timestamp.now(),
      },
      'updatedAt': Timestamp.now(),
    });

    // Store daily activity log
    await admin.firestore().collection('daily_activity').add({
      'userId': userId,
      'date': todayStart.toISOString().split('T')[0],
      'minutes': dailyMinutes,
      'type': 'daily',
      'createdAt': Timestamp.now(),
    });

    console.log(`Activity data updated for user: ${userId}, total minutes: ${totalMinutes}`);
    
    return {
      success: true,
      message: 'Activity data updated successfully',
      totalMinutes: totalMinutes,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error updating activity data: ${error}`);
    
    return {
      success: false,
      message: 'Failed to update activity data',
      error: error.message,
    };
  }
});

// Get activity statistics
exports.getActivityStats = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Getting activity stats for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        success: true,
        message: 'No activity stats found',
        stats: {},
      };
    }

    const userData = userDoc.data();
    const activityTracking = userData.activityTracking || {};

    return {
      success: true,
      message: 'Activity stats retrieved successfully',
      stats: {
        totalMinutes: activityTracking.totalMinutes || 0,
        dailyMinutes: activityTracking.dailyMinutes || 0,
        weeklyMinutes: activityTracking.weeklyMinutes || 0,
        monthlyMinutes: activityTracking.monthlyMinutes || 0,
        isTracking: activityTracking.isTracking || false,
        lastActivity: activityTracking.lastActivity ? 
          new Date(activityTracking.lastActivity._seconds * 1000) : null,
      },
      userId: userId,
    };
  } catch (error) {
    console.error(`Error getting activity stats: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get activity stats',
      error: error.message,
    };
  }
});

// Check if user is active (anti-bot detection)
exports.isUserActive = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Checking if user is active for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    // Get recent activity
    const now = Timestamp.now().toDate();
    const oneHourAgo = new Date(now.getTime() - (60 * 60 * 1000));
    
    const snapshot = await admin.firestore()
      .collection('daily_activity')
      .where('userId', '==', userId)
      .where('date', '>=', oneHourAgo)
      .orderBy('date', 'desc')
      .limit(10)
      .get();

    // Check if there's Activity in the last hour
    const hasRecentActivity = snapshot.docs.length > 0;
    
    // Check for bot-like patterns
    if (hasRecentActivity) {
      // Additional bot detection logic would go here
      // For now, we'll just check basic Activity
    }

    return {
      success: true,
      message: 'User activity check completed',
      hasRecentActivity: hasRecentActivity,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error checking user activity: ${error}`);
    
    return {
      success: false,
      message: 'Failed to check user Activity',
      error: error.message,
    };
  }
});

// Calculate FRAUD score with AI analysis
exports.calculateFraudScore = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Calculating fraud score for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        success: true,
        message: 'No user data found',
        score: 100.0,
        isHighRisk: false,
      };
    }

    const userData = userDoc.data();
    
    // Get activity patterns
    const activitySnapshot = await admin.firestore()
      .collection('daily_activity')
      .where('userId', '==', userId)
      .orderBy('date', 'desc')
      .limit(100)
      .get();

    // Analyze activity patterns
    const activities = activitySnapshot.docs.map(doc => doc.data()).toList();
    
    let fraudScore = 100.0; // Start with perfect score
    const activityCount = activities.length;
    
    if (activityCount > 0) {
      // Check for consistent timing patterns (bot-like behavior)
      const timeIntervals = [];
      for (let i = 1; i < activities.length; i++) {
        if (i > 0) {
          const currentActivity = new Date(activities[i].date);
          const previousActivity = new Date(activities[i - 1].date);
          const interval = (currentActivity.getTime() - previousActivity.getTime()) / (1000 * 60);
          timeIntervals.push(interval);
        }
      }
      
      // Calculate variance
      if (timeIntervals.length > 0) {
        const mean = timeIntervals.reduce((a, b) => a + b) / timeIntervals.length);
        const variance = timeIntervals.reduce((sum, interval) => {
          const diff = interval - mean;
          return sum + (diff * diff);
        }, 0) / timeIntervals.length;
        const stdDev = variance > 0 ? Math.sqrt(variance) : 0;
          
        // High variance indicates potential bot behavior
        if (stdDev < 5) {
          fraudScore -= 10; // Slight variance is normal
        } else if (stdDev < 15) {
          fraudScore -= 20; // Moderate variance is suspicious
        } else if (stdDev < 30) {
          fraudScore -= 35; // High variance is very suspicious
        } else {
          fraudScore -= 50; // Very high variance indicates bot
        }
      }
      
      // Check for 24/7 Activity (potential bot)
      const last24Hours = activities.filter(activity => {
        const activityTime = new Date(activity.date);
        const now = new Date();
        return (now.getTime() - activityTime.getTime()) / (1000 * 60 * 60) <= 24;
      }).length;
      
      if (last24Hours > 20) {
        fraudScore -= 15; // Too much Activity
      }
      
      // Check for weekend vs weekday pattern
      const weekendActivities = activities.filter(activity => {
        const activityTime = new Date(activity.date);
        const weekday = activityTime.getDay();
        return weekday >= 6 || weekday <= 0; // 6=Saturday, 0=Sunday
      }).length;
      
      const weekdayActivities = activities.filter(activity => {
        const activityTime = new Date(activity.date);
        const weekday = activityTime.getDay();
        return weekday >= 1 && weekday <= 5; // 1=Monday, 5=Friday
      }).length;
      
      if (weekendActivities > weekdayActivities * 2) {
        fraudScore -= 10; // Unusual weekend pattern
      }
      
      // Check for exact same timestamps (duplicate actions)
      const timestamps = activities.map(activity => new Date(activity.date)).sort((a, b) => a.getTime() - b.getTime());
      
      let duplicateCount = 0;
      for (let i = 1; i < timestamps.length; i++) {
        if (Math.abs(timestamps[i].getTime() - timestamps[i-1].getTime()) < 1000) { // Within 1 second
          duplicateCount++;
        }
      }
      
      if (duplicateCount > 5) {
        fraudScore -= 25; // Many duplicate actions
      }
      
      // Bonus points for consistent activity
      if (activityCount >= 20 && fraudScore > 50) {
        fraudScore += 10; // Reward consistent human-like behavior
      }
    }

    // Store fraud score
    await admin.firestore().collection('fraud_scores').add({
      'userId': userId,
      'score': fraudScore,
      'activityCount': activityCount,
      'analysis': {
        'variance': variance,
        'stdDev': stdDev,
        'duplicateCount': duplicateCount,
        'weekendPattern': weekendActivities > weekdayActivities * 2,
        'last24Hours': last24Hours,
      },
      'calculatedAt': Timestamp.now(),
    });

    console.log(`Fraud score calculated for user: ${userId}, score: ${fraudScore}`);
    
    return {
      success: true,
      message: 'Fraud score calculated successfully',
      score: fraudScore,
      isHighRisk: fraudScore < 50,
      userId: userId,
    };
  } catch (error) {
    console.error(`Error calculating fraud score: ${error}`);
    
    return {
      success: false,
      message: 'Failed to calculate fraud score',
      error: error.message,
    };
  }
});

// Get activity insights
exports.getActivityInsights = functions.https.onCall(async (data, context) => {
  const { userId } = data;
  
  console.log(`Getting activity insights for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing userId');
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        success: true,
        message: 'No activity insights found',
        insights: {},
      };
    }

    const userData = userDoc.data();
    const activityTracking = userData.activityTracking || {};

    // Get activity patterns
    const activitySnapshot = await admin.firestore()
      .collection('daily_activity')
      .where('userId', '==', userId)
      .orderBy('date', 'desc')
      .limit(50)
      .get();

    const activities = activitySnapshot.docs.map(doc => doc.data()).toList();
    
    // Analyze patterns
    const peakHours = [];
    const activeDays = [];
    
    for (const activity of activities) {
      const activityTime = new Date(activity.date);
      const hour = activityTime.getHours();
      
      if (!peakHours.includes(hour)) {
        peakHours.push(hour);
      }
      
      if (!activeDays.includes(activityTime.getDate())) {
        activeDays.push(activityTime.getDate());
      }
    }

    // Determine user type
    let userType = 'normal';
    if (peakHours.length >= 6) {
      userType = 'power_user';
    } else if (activeDays.length >= 25) {
      userType = 'dedicated_user';
    }

    // Calculate streak days
    let streak = 1;
    if (activities.length > 1) {
      const sortedActivities = activities.slice().sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
      
      for (let i = 1; i < sortedActivities.length; i++) {
        if (i > 0) {
          const current = new Date(sortedActivities[i].date);
          const previous = new Date(sortedActivities[i - 1].date);
          
          // Check if consecutive day
          if (Math.abs(current.getTime() - previous.getTime()) <= 24 * 60 * 60 * 1000) {
            streak++;
          } else {
            break;
          }
        }
      }
    }

    return {
      success: true,
      message: 'Activity insights retrieved successfully',
      insights: {
        totalMinutes: activityTracking.totalMinutes || 0,
        dailyAverage: activities.length > 0 ? (activityTracking.dailyMinutes || 0) / 7 : 0,
        peakHours: peakHours,
        activeDays: activeDays.length,
        userType: userType,
        streakDays: streak,
        mostActiveDay: getMostActiveDay(activities),
      },
      userId: userId,
    };
  } catch (error) {
    console.error(`Error getting activity insights: ${error}`);
    
    return {
      success: false,
      message: 'Failed to get activity insights',
      error: error.message,
    };
  }
});

// Helper function to get most active day
function getMostActiveDay(activities) {
  if (activities.length === 0) return 'غير محدد';
  
  const dayCounts = {};
  
  for (const activity of activities) {
    const day = new Date(activity.date).getDay();
    dayCounts[day] = (dayCounts[day] || 0) + 1;
  }
  
  // Find the day with highest count
  let maxCount = 0;
  let mostActiveDay = 'الأحد';
  
  Object.keys(dayCounts).forEach(day => {
    const count = dayCounts[day];
    if (count > maxCount) {
      maxCount = count;
      switch (day) {
        case 1:
          mostActiveDay = 'الإثنين';
          break;
        case 2:
          mostActiveDay = 'الثلاثاء';
          break;
        case 3:
          mostActiveDay = 'الأربعاء';
          break;
        case 4:
          mostActiveDay = 'الخميس';
          break;
        case 5:
          mostActiveDay = 'الجمعة';
          break;
        case 6:
          mostActiveDay = 'السبت';
          break;
        case 0:
          mostActiveDay = 'الأحد';
          break;
      }
    }
  });
  
  return mostActiveDay;
}
