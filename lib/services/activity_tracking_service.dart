import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityTrackingService {
  static final ActivityTrackingService _instance = ActivityTrackingService._internal();
  factory ActivityTrackingService() => _instance;
  ActivityTrackingService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _activityTimer;
  DateTime? _lastActivity;
  int _totalMinutes = 0;
  int _dailyMinutes = 0;
  int _weeklyMinutes = 0;
  int _monthlyMinutes = 0;
  bool _isTracking = false;

  // Start activity tracking
  Future<void> startTracking() async {
    try {
      _isTracking = true;
      _activityTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
        await _updateActivityData();
      });
      
      print('Activity tracking started');
    } catch (e) {
      print('Error starting activity tracking: $e');
    }
  }

  // Stop activity tracking
  Future<void> stopTracking() async {
    try {
      _isTracking = false;
      _activityTimer?.cancel();
      _activityTimer = null;
      
      await _updateActivityData();
      
      print('Activity tracking stopped');
    } catch (e) {
      print('Error stopping activity tracking: $e');
    }
  }

  // Update activity data (called every minute)
  Future<void> _updateActivityData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get current date info
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final weekStart = today.subtract(Duration(days: today.weekday - DateTime.monday));
      final monthStart = DateTime(now.year, now.month, 1);

      // Calculate time periods
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayEnd = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      final weekEnd = weekStart.add(const Duration(days: 7));
      final monthEnd = monthStart.add(const Duration(days: 30));

      // Update counters
      _totalMinutes++;
      _dailyMinutes++;

      // Check if we need to reset weekly/monthly counters
      if (now.isAtSameMomentAs(weekEnd) || now.isAtSameMomentAs(monthEnd)) {
        _weeklyMinutes = 0;
        _monthlyMinutes = 0;
      }

      // Store activity data
      await _firestore.collection('users').doc(userId).update({
        'activityTracking': {
          'isTracking': _isTracking,
          'totalMinutes': _totalMinutes,
          'dailyMinutes': _dailyMinutes,
          'weeklyMinutes': _weeklyMinutes,
          'monthlyMinutes': _monthlyMinutes,
          'lastActivity': _lastActivity?.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Store daily activity log
      await _firestore.collection('daily_activity').add({
        'userId': userId,
        'date': todayStart.toIso8601String(),
        'minutes': _dailyMinutes,
        'type': 'daily',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Activity data updated: $_totalMinutes total minutes');
    } catch (e) {
      print('Error updating activity data: $e');
    }
  }

  // Get activity statistics
  Future<ActivityStats> getActivityStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return ActivityStats();

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return ActivityStats();

      final userData = userDoc.data() as Map<String, dynamic>;
      final activityTracking = userData['activityTracking'] as Map<String, dynamic>? ?? {};

      return ActivityStats(
        totalMinutes: activityTracking['totalMinutes'] ?? 0,
        dailyMinutes: activityTracking['dailyMinutes'] ?? 0,
        weeklyMinutes: activityTracking['weeklyMinutes'] ?? 0,
        monthlyMinutes: activityTracking['monthlyMinutes'] ?? 0,
        isTracking: _isTracking,
        lastActivity: activityTracking['lastActivity'] != null 
            ? DateTime.parse(activityTracking['lastActivity']) 
            : null,
      );
    } catch (e) {
      print('Error getting activity stats: $e');
      return ActivityStats();
    }
  }

  // Check if user is active (anti-bot detection)
  Future<bool> isUserActive() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Get recent activity
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      final snapshot = await _firestore
          .collection('daily_activity')
          .where('userId', '==', userId)
          .where('date', '>=', oneHourAgo)
          .orderBy('date', descending: true)
          .limit(10)
          .get();

      // Check if there's activity in the last hour
      bool hasRecentActivity = snapshot.docs.isNotEmpty;
      
      // Check for bot-like patterns
      if (hasRecentActivity) {
        // Additional bot detection logic would go here
        // For now, we'll just check basic activity
      }

      return hasRecentActivity;
    } catch (e) {
      print('Error checking user activity: $e');
      return false;
    }
  }

  // Calculate FRAUD score with AI analysis
  Future<FraudScore> calculateFraudScore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return FraudScore();

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return FraudScore();

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Get activity patterns
      final activitySnapshot = await _firestore
          .collection('daily_activity')
          .where('userId', '==', userId)
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      // Analyze activity patterns
      final activities = activitySnapshot.docs.map((doc) => doc.data()).toList();
      
      double fraudScore = 100.0; // Start with perfect score
      int activityCount = activities.length;
      
      if (activityCount > 0) {
        // Check for consistent timing patterns (bot-like behavior)
        final timeIntervals = <double>[];
        for (int i = 1; i < activities.length; i++) {
          if (i > 0) {
            final currentActivity = DateTime.parse(activities[i]['date']);
            final previousActivity = DateTime.parse(activities[i-1]['date']);
            final interval = currentActivity.difference(previousActivity).inMinutes;
            timeIntervals.add(interval);
          }
        }
        
        // Calculate variance
        if (timeIntervals.isNotEmpty) {
          final mean = timeIntervals.reduce((a, b) => a + b) / timeIntervals.length;
          final variance = timeIntervals.map((interval) => (interval - mean) * (interval - mean)).reduce((a, b) => a + b) / timeIntervals.length);
          final stdDev = variance > 0 ? variance.sqrt() : 0;
          
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
        
        // Check for 24/7 activity (potential bot)
        final last24Hours = activities.where((activity) {
          final activityTime = DateTime.parse(activity['date']);
          final now = DateTime.now();
          return now.difference(activityTime).inHours <= 24;
        }).length;
        
        if (last24Hours > 20) {
          fraudScore -= 15; // Too much activity
        }
        
        // Check for weekend vs weekday pattern
        final weekendActivities = activities.where((activity) {
          final activityTime = DateTime.parse(activity['date']);
          final weekday = activityTime.weekday;
          return weekday >= DateTime.saturday || weekday <= DateTime.sunday;
        }).length;
        
        final weekdayActivities = activities.where((activity) {
          final activityTime = DateTime.parse(activity['date']);
          final weekday = activityTime.weekday;
          return weekday >= DateTime.monday && weekday <= DateTime.friday;
        }).length;
        
        if (weekendActivities > weekdayActivities * 2) {
          fraudScore -= 10; // Unusual weekend pattern
        }
        
        // Check for exact same timestamps (duplicate actions)
        final timestamps = activities.map((activity) => DateTime.parse(activity['date'])).toList();
        timestamps.sort();
        
        int duplicateCount = 0;
        for (int i = 1; i < timestamps.length; i++) {
          if (timestamps[i].isAtSameMomentAs(timestamps[i-1])) {
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
      await _firestore.collection('fraud_scores').add({
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
        'calculatedAt': FieldValue.serverTimestamp(),
      });

      return FraudScore(score: fraudScore, isHighRisk: fraudScore < 50);
    } catch (e) {
      print('Error calculating fraud score: $e');
      return FraudScore();
    }
  }

  // Get activity insights
  Future<ActivityInsights> getActivityInsights() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return ActivityInsights();

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return ActivityInsights();

      final userData = userDoc.data() as Map<String, dynamic>;
      final activityTracking = userData['activityTracking'] as Map<String, dynamic>? ?? {};

      // Get activity patterns
      final activitySnapshot = await _firestore
          .collection('daily_activity')
          .where('userId', '==', userId)
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      final activities = activitySnapshot.docs.map((doc) => doc.data()).toList();
      
      // Analyze patterns
      final peakHours = <int>[];
      final activeDays = <int>[];
      
      for (final activity in activities) {
        final activityTime = DateTime.parse(activity['date']);
        final hour = activityTime.hour;
        
        if (!peakHours.contains(hour)) {
          peakHours.add(hour);
        }
        
        if (!activeDays.contains(activityTime.day)) {
          activeDays.add(activityTime.day);
        }
      }

      // Determine user type
      String userType = 'normal';
      if (peakHours.length >= 6) {
        userType = 'power_user';
      } else if (activeDays.length >= 25) {
        userType = 'dedicated_user';
      }

      return ActivityInsights(
        totalMinutes: activityTracking['totalMinutes'] ?? 0,
        dailyAverage: activities.isNotEmpty ? (activityTracking['dailyMinutes'] ?? 0) / 7 : 0,
        peakHours: peakHours,
        activeDays: activeDays.length,
        userType: userType,
        streakDays: _calculateStreakDays(activities),
        mostActiveDay: _getMostActiveDay(activities),
      );
    } catch (e) {
      print('Error getting activity insights: $e');
      return ActivityInsights();
    }
  }

  // Calculate streak days
  int _calculateStreakDays(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) return 0;
    
    final sortedActivities = List<Map<String, dynamic>>.from(activities);
    sortedActivities.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    int streak = 1;
    for (int i = 1; i < sortedActivities.length; i++) {
      if (i > 0) {
        final current = DateTime.parse(sortedActivities[i]['date']);
        final previous = DateTime.parse(sortedActivities[i-1]['date']);
        
        // Check if consecutive day
        if (current.difference(previous).inDays == 1) {
          streak++;
        } else {
          break;
        }
      }
    }
    
    return streak;
  }

  // Get most active day
  String _getMostActiveDay(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) return 'غير محدد';
    
    final dayCounts = <int, int>{};
    
    for (final activity in activities) {
      final day = DateTime.parse(activity['date']).weekday;
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }
    
    // Find the day with highest count
    int maxCount = 0;
    String mostActiveDay = 'الأحد';
    
    dayCounts.forEach((day, count) {
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
          case 7:
            mostActiveDay = 'الأحد';
            break;
        }
      }
    });
    
    return mostActiveDay;
  }
}

// Activity statistics model
class ActivityStats {
  final int totalMinutes;
  final int dailyMinutes;
  final int weeklyMinutes;
  final int monthlyMinutes;
  final bool isTracking;
  final DateTime? lastActivity;

  ActivityStats({
    required this.totalMinutes,
    required this.dailyMinutes,
    required this.weeklyMinutes,
    required this.monthlyMinutes,
    required this.isTracking,
    this.lastActivity,
  });
}

// Fraud score model
class FraudScore {
  final double score;
  final bool isHighRisk;

  FraudScore({
    required this.score,
    required this.isHighRisk,
  });
}

// Activity insights model
class ActivityInsights {
  final int totalMinutes;
  final double dailyAverage;
  final List<int> peakHours;
  final int activeDays;
  final String userType;
  final int streakDays;
  final String mostActiveDay;

  ActivityInsights({
    required this.totalMinutes,
    required this.dailyAverage,
    required this.peakHours,
    required this.activeDays,
    required this.userType,
    required this.streakDays,
    required this.mostActiveDay,
  });
}
