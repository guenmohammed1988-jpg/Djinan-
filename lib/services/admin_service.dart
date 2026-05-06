import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      
      return snapshot.docs.map((doc) {
        final userData = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'email': userData['email'] ?? '',
          'name': userData['name'] ?? '',
          'createdAt': userData['createdAt'],
          'lastLogin': userData['lastLogin'],
          'isActive': userData['isActive'] ?? false,
          'role': userData['role'] ?? 'user',
          'fraudScore': userData['fraudScore'] ?? 100.0,
          'isBanned': userData['isBanned'] ?? false,
          'banReason': userData['banReason'] ?? '',
          'banExpiresAt': userData['banExpiresAt'],
        };
      }).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Update user role
  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('User role updated to: $role');
    } catch (e) {
      print('Error updating user role: $e');
    }
  }

  // Ban user
  Future<void> banUser({
    required String userId,
    required String reason,
    int banDurationDays = 30,
  }) async {
    try {
      final banExpiresAt = DateTime.now().add(Duration(days: banDurationDays));
      
      await _firestore.collection('users').doc(userId).update({
        'isBanned': true,
        'banReason': reason,
        'banExpiresAt': banExpiresAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('User banned: $userId, reason: $reason');
    } catch (e) {
      print('Error banning user: $e');
    }
  }

  // Unban user
  Future<void> unbanUser({
    required String userId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': false,
        'banReason': '',
        'banExpiresAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('User unbanned: $userId');
    } catch (e) {
      print('Error unbanning user: $e');
    }
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return {
          'totalUsers': 0,
          'activeUsers': 0,
          'bannedUsers': 0,
          'highRiskUsers': 0,
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Get all users for stats
      final allUsersSnapshot = await _firestore.collection('users').get();
      final allUsers = allUsersSnapshot.docs.map((doc) => doc.data()).toList();
      
      int activeCount = 0;
      int bannedCount = 0;
      int highRiskCount = 0;
      
      for (final user in allUsers) {
        final userRole = user['role'] ?? 'user';
        final isBanned = user['isBanned'] ?? false;
        final fraudScore = user['fraudScore'] ?? 100.0;
        
        if (user['isActive'] == true && userRole == 'user') {
          activeCount++;
        }
        
        if (isBanned) {
          bannedCount++;
        }
        
        if (fraudScore < 50) {
          highRiskCount++;
        }
      }

      return {
        'totalUsers': allUsers.length,
        'activeUsers': activeCount,
        'bannedUsers': bannedCount,
        'highRiskUsers': highRiskCount,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }

  // Get content moderation stats
  Future<Map<String, dynamic>> getContentModerationStats() async {
    try {
      // Get flagged content
      final flaggedSnapshot = await _firestore.collection('flagged_content').get();
      final flaggedCount = flaggedSnapshot.size;
      
      // Get moderation queue
      final queueSnapshot = await _firestore.collection('moderation_queue').get();
      final queueCount = queueSnapshot.size;
      
      // Get moderation reports
      final reportsSnapshot = await _firestore.collection('moderation_reports').get();
      final reportsCount = reportsSnapshot.size;

      return {
        'flaggedContent': flaggedCount,
        'moderationQueue': queueCount,
        'moderationReports': reportsCount,
        'totalContent': flaggedCount + queueCount + reportsCount,
      };
    } catch (e) {
      print('Error getting moderation stats: $e');
      return {};
    }
  }

  // Get fraud scores
  Future<List<Map<String, dynamic>>> getFraudScores() async {
    try {
      final snapshot = await _firestore.collection('fraud_scores').get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'userId': doc.id,
          'score': data['score'] ?? 100.0,
          'isHighRisk': (data['score'] ?? 100.0) < 50,
          'calculatedAt': data['calculatedAt'],
          'analysis': data['analysis'] ?? {},
        };
      }).toList();
    } catch (e) {
      print('Error getting fraud scores: $e');
      return [];
    }
  }

  // Get activity insights
  Future<List<Map<String, dynamic>>> getActivityInsights() async {
    try {
      final snapshot = await _firestore.collection('daily_activity').get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'userId': doc.id,
          'date': data['date'],
          'minutes': data['minutes'] ?? 0,
          'type': data['type'] ?? 'daily',
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
      print('Error getting activity insights: $e');
      return [];
    }
  }

  // Search users
  Future<List<Map<String, dynamic>>> searchUsers({
    String query,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('name', '>=', query)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final userData = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': userData['name'] ?? '',
          'email': userData['email'] ?? '',
          'role': userData['role'] ?? 'user',
          'isActive': userData['isActive'] ?? false,
          'fraudScore': userData['fraudScore'] ?? 100.0,
          'isBanned': userData['isBanned'] ?? false,
        };
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get content reports
  Future<List<Map<String, dynamic>>> getContentReports() async {
    try {
      final snapshot = await _firestore.collection('moderation_reports').get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'contentId': data['contentId'] ?? '',
          'reason': data['reason'] ?? '',
          'reporterId': data['reporterId'] ?? '',
          'status': data['status'] ?? 'pending',
          'createdAt': data['createdAt'],
          'reviewedAt': data['reviewedAt'],
        };
      }).toList();
    } catch (e) {
      print('Error getting content reports: $e');
      return [];
    }
  }

  // Update content moderation status
  Future<void> updateContentStatus({
    required String contentId,
    required String status, // 'approved', 'rejected', 'deleted'
    String? moderatorNote,
  }) async {
    try {
      await _firestore.collection('flagged_content').doc(contentId).update({
        'status': status,
        'moderatorNote': moderatorNote,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Content status updated: $contentId -> $status');
    } catch (e) {
      print('Error updating content status: $e');
    }
  }

  // Get user activity for fraud analysis
  Future<List<Map<String, dynamic>>> getUserActivityForAnalysis(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('daily_activity')
          .where('userId', '==', userId)
          .orderBy('date', 'desc')
          .limit(100)
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting user activity for analysis: $e');
      return [];
    }
  }

  // Delete user
  Future<void> deleteUser({
    required String userId,
  }) async {
    try {
      // Delete user data
      await _firestore.collection('users').doc(userId).delete();
      
      // Delete related data
      final activitySnapshot = await _firestore
          .collection('daily_activity')
          .where('userId', '==', userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in activitySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();

      // Delete fraud scores
      final fraudSnapshot = await _firestore
          .collection('fraud_scores')
          .where('userId', '==', userId)
          .get();
      
      final fraudBatch = _firestore.batch();
      for (final doc in fraudSnapshot.docs) {
        fraudBatch.delete(doc.reference);
      }
      
      await fraudBatch.commit();

      print('User deleted: $userId');
    } catch (e) {
      print('Error deleting user: $e');
    }
  }
}
