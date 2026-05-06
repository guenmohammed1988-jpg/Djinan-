import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class HighlightsService {
  static final HighlightsService _instance = HighlightsService._internal();
  factory HighlightsService() => _instance;
  HighlightsService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Constants
  static const String highlightsCollection = 'highlights';
  static const String pricingCollection = 'pricing';
  static const String featuredCollection = 'featured_merchants';
  static const String streaksCollection = 'daily_streaks';
  
  // Pricing constants
  static const double basePrice = 1000.0;
  static const double peakHourMultiplier = 2.0;
  static const double featuredPrice = 5000.0;
  
  // Get user highlights
  Future<UserHighlights> getUserHighlights() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return UserHighlights();
      
      final doc = await _firestore
          .collection(highlightsCollection)
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        return UserHighlights();
      }
      
      final data = doc.data() as Map<String, dynamic>;
      return UserHighlights(
        currentStreak: (data['currentStreak'] ?? 0) as int,
        longestStreak: (data['longestStreak'] ?? 0) as int,
        totalHighlights: (data['totalHighlights'] ?? 0) as int,
        peakHourBoosts: List<String>.from(data['peakHourBoosts'] ?? []),
        featuredUntil: (data['featuredUntil'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      return UserHighlights();
    }
  }

  // Update daily streak
  Future<void> updateDailyStreak({
    required int streakDays,
    required DateTime lastActiveDate,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final now = DateTime.now();
      
      // Check if streak continues
      final daysDiff = now.difference(lastActiveDate).inDays;
      final streakContinues = daysDiff <= 1;
      
      // Update streak data
      await _firestore.collection(streaksCollection).doc(userId).set({
        'currentStreak': streakContinues ? streakDays + 1 : 0,
        'longestStreak': FieldValue.increment(1),
        'lastActiveDate': now,
        'streakDays': streakDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update highlights if streak increases
      if (streakContinues) {
        await _incrementTotalHighlights();
      }
    } catch (e) {
      throw Exception('Failed to update daily streak: $e');
    }
  }

  // Increment total highlights
  Future<void> _incrementTotalHighlights() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      await _firestore.collection(highlightsCollection).doc(userId).update({
        'totalHighlights': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to increment highlights: $e');
    }
  }

  // Get pricing information
  Future<PricingInfo> getPricingInfo() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return PricingInfo();
      
      final doc = await _firestore
          .collection(pricingCollection)
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        return PricingInfo();
      }
      
      final data = doc.data() as Map<String, dynamic>;
      return PricingInfo(
        basePrice: (data['basePrice'] ?? basePrice) as double,
        currentMultiplier: (data['currentMultiplier'] ?? 1.0) as double,
        peakHourMultiplier: (data['peakHourMultiplier'] ?? peakHourMultiplier) as double,
        featuredPrice: (data['featuredPrice'] ?? featuredPrice) as double,
        peakHours: List<int>.from(data['peakHours'] ?? [17, 18, 19, 20]),
        nextResetDate: (data['nextResetDate'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      return PricingInfo();
    }
  }

  // Update pricing multiplier
  Future<void> updatePricingMultiplier(double multiplier) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      await _firestore.collection(pricingCollection).doc(userId).update({
        'currentMultiplier': multiplier,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update pricing multiplier: $e');
    }
  }

  // Check if current time is peak hour
  bool isPeakHour() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 17 && hour <= 20; // 5PM - 8PM
  }

  // Calculate current price
  double calculateCurrentPrice(PricingInfo pricingInfo) {
    double multiplier = pricingInfo.currentMultiplier;
    
    // Apply peak hour boost
    if (isPeakHour()) {
      multiplier *= pricingInfo.peakHourMultiplier;
    }
    
    return pricingInfo.basePrice * multiplier;
  }

  // Get featured merchants
  Future<List<FeaturedMerchant>> getFeaturedMerchants() async {
    try {
      final snapshot = await _firestore
          .collection(featuredCollection)
          .where('isActive', isEqualTo: true)
          .where('featuredUntil', isGreaterThanOrEqualTo: DateTime.now())
          .orderBy('featuredAt', descending: true)
          .limit(10)
          .get();
      
      final merchants = <FeaturedMerchant>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        merchants.add(FeaturedMerchant(
          id: doc.id,
          storeName: data['storeName'] ?? '',
          username: data['username'] ?? '',
          logo: data['logo'],
          rating: (data['rating'] ?? 0.0) as double,
          featuredAt: (data['featuredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          featuredUntil: (data['featuredUntil'] as Timestamp?)?.toDate(),
          description: data['description'] ?? '',
          categories: List<String>.from(data['categories'] ?? []),
        ));
      }
      
      return merchants;
    } catch (e) {
      return [];
    }
  }

  // Add featured merchant
  Future<void> addFeaturedMerchant({
    required String merchantId,
    required Duration duration,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Get merchant data
      final merchantDoc = await _firestore
          .collection('merchants')
          .doc(merchantId)
          .get();
      
      if (!merchantDoc.exists) return;
      
      final merchantData = merchantDoc.data() as Map<String, dynamic>;
      
      // Calculate featured until date
      final featuredUntil = DateTime.now().add(duration);
      
      // Add to featured collection
      await _firestore.collection(featuredCollection).add({
        'merchantId': merchantId,
        'storeName': merchantData['storeName'],
        'username': merchantData['username'],
        'logo': merchantData['logo'],
        'rating': merchantData['rating'],
        'featuredAt': FieldValue.serverTimestamp(),
        'featuredUntil': featuredUntil,
        'description': merchantData['description'],
        'categories': merchantData['categories'],
        'isActive': true,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update merchant with featured status
      await _firestore
          .collection('merchants')
          .doc(merchantId)
          .update({
        'isFeatured': true,
        'featuredUntil': featuredUntil,
        'featuredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add featured merchant: $e');
    }
  }

  // Get daily streaks history
  Future<List<DailyStreak>> getDailyStreaksHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection(streaksCollection)
          .doc(userId)
          .collection('history')
          .orderBy('date', descending: true)
          .limit(30)
          .get();
      
      final streaks = <DailyStreak>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        streaks.add(DailyStreak(
          date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          streakDays: (data['streakDays'] ?? 0) as int,
          isActive: (data['isActive'] ?? false) as bool,
        ));
      }
      
      return streaks;
    } catch (e) {
      return [];
    }
  }

  // Reset pricing multiplier at midnight
  Future<void> resetDailyPricing() async {
    try {
      final snapshot = await _firestore
          .collection(pricingCollection)
          .where('nextResetDate', isLessThanOrEqualTo: DateTime.now())
          .get();
      
      for (final doc in snapshot.docs) {
        await _firestore.collection(pricingCollection).doc(doc.id).update({
          'currentMultiplier': 1.0, // Reset to base multiplier
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Handle error
    }
  }
}

// User highlights model
class UserHighlights {
  final int currentStreak;
  final int longestStreak;
  final int totalHighlights;
  final List<String> peakHourBoosts;
  final DateTime? featuredUntil;

  UserHighlights({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalHighlights,
    required this.peakHourBoosts,
    this.featuredUntil,
  });

  // Get streak emoji
  String get streakEmoji {
    if (currentStreak >= 30) return '🔥';
    if (currentStreak >= 14) return '💪';
    if (currentStreak >= 7) return '⭐';
    if (currentStreak >= 3) return '🎯';
    return '📅';
  }

  // Get streak message
  String get streakMessage {
    if (currentStreak == 0) return 'ابدأ التحدي';
    if (currentStreak == 1) return 'يوم واحد!';
    if (currentStreak <= 3) return '$currentStreak أيام متتالية';
    return '$currentStreak يوم متتالية!';
  }
}

// Pricing information model
class PricingInfo {
  final double basePrice;
  final double currentMultiplier;
  final double peakHourMultiplier;
  final double featuredPrice;
  final List<int> peakHours;
  final DateTime? nextResetDate;

  PricingInfo({
    required this.basePrice,
    required this.currentMultiplier,
    required this.peakHourMultiplier,
    required this.featuredPrice,
    required this.peakHours,
    this.nextResetDate,
  });

  // Check if current time is peak hour
  bool isPeakHour() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 17 && hour <= 20; // 5PM - 8PM
  }

  // Calculate current price
  double calculateCurrentPrice() {
    double multiplier = currentMultiplier;
    
    // Apply peak hour boost
    if (isPeakHour()) {
      multiplier *= peakHourMultiplier;
    }
    
    return basePrice * multiplier;
  }

  // Get formatted price
  String get formattedCurrentPrice {
    return '${calculateCurrentPrice().toStringAsFixed(0)} دج';
  }

  // Get time until reset
  String get timeUntilReset {
    if (nextResetDate == null) return 'غير محدد';
    
    final now = DateTime.now();
    final difference = nextResetDate!.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else {
      return '${difference.inMinutes} دقيقة';
    }
  }
}

// Featured merchant model
class FeaturedMerchant {
  final String id;
  final String storeName;
  final String username;
  final String? logo;
  final double rating;
  final DateTime featuredAt;
  final DateTime featuredUntil;
  final String description;
  final List<String> categories;

  FeaturedMerchant({
    required this.id,
    required this.storeName,
    required this.username,
    required this.featuredAt,
    required this.featuredUntil,
    required this.description,
    required this.categories,
    this.logo,
    required this.rating,
  });
}

// Daily streak model
class DailyStreak {
  final DateTime date;
  final int streakDays;
  final bool isActive;

  DailyStreak({
    required this.date,
    required this.streakDays,
    required this.isActive,
  });
}
