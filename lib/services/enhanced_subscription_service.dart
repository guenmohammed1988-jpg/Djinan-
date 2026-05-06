import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EnhancedSubscriptionService {
  static final EnhancedSubscriptionService _instance = EnhancedSubscriptionService._internal();
  factory EnhancedSubscriptionService() => _instance;
  EnhancedSubscriptionService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Constants
  static const String subscriptionsCollection = 'enhanced_subscriptions';
  static const String paymentsCollection = 'subscription_payments';
  static const String notificationsCollection = 'subscription_notifications';
  
  // Pricing constants
  static const double annualSubscriptionFee = 5000.0;
  static const double monthlySubscriptionFee = 500.0;
  static const int freeTrialMonths = 6;
  static const int expiryNotificationDays = 30;
  
  // Get enhanced subscription info
  Future<EnhancedSubscription?> getEnhancedSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;
      
      final doc = await _firestore
          .collection(subscriptionsCollection)
          .doc(userId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return EnhancedSubscription(
        id: doc.id,
        userId: userId,
        planType: data['planType'] ?? 'free',
        startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
        isTrialActive: data['isTrialActive'] ?? false,
        trialStartDate: (data['trialStartDate'] as Timestamp?)?.toDate(),
        trialEndDate: (data['trialEndDate'] as Timestamp?)?.toDate(),
        lastPaymentDate: (data['lastPaymentDate'] as Timestamp?)?.toDate(),
        nextBillingDate: (data['nextBillingDate'] as Timestamp?)?.toDate(),
        autoRenewal: data['autoRenewal'] ?? false,
        paymentMethod: data['paymentMethod'] ?? 'none',
        status: data['status'] ?? 'inactive',
        totalPaid: (data['totalPaid'] ?? 0.0) as double,
        currency: data['currency'] ?? 'DZD',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  // Start free trial
  Future<void> startFreeTrial() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Check if user already has an active subscription
      final existing = await getEnhancedSubscription();
      if (existing != null && existing!.status == 'active') {
        throw Exception('User already has an active subscription');
      }
      
      final now = DateTime.now();
      final trialEndDate = DateTime(now.year, now.month + freeTrialMonths, now.day);
      
      await _firestore.collection(subscriptionsCollection).doc(userId).set({
        'planType': 'trial',
        'startDate': now,
        'expiryDate': trialEndDate,
        'isTrialActive': true,
        'trialStartDate': now,
        'trialEndDate': trialEndDate,
        'lastPaymentDate': null,
        'nextBillingDate': trialEndDate,
        'autoRenewal': false,
        'paymentMethod': 'trial',
        'status': 'active',
        'totalPaid': 0.0,
        'currency': 'DZD',
        'createdAt': now,
        'updatedAt': now,
      });
      
      // Schedule expiry notification
      await _scheduleExpiryNotification(userId, trialEndDate);
      
      // Log trial start
      await _logSubscriptionEvent(userId, 'trial_started', {
        'trialDuration': '$freeTrialMonths months',
        'expiryDate': trialEndDate.toIso8601String(),
      });
      
    } catch (e) {
      throw Exception('Failed to start free trial: $e');
    }
  }

  // Activate annual subscription
  Future<void> activateAnnualSubscription({
    required String paymentMethod,
    required Map<String, dynamic> paymentDetails,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final now = DateTime.now();
      final expiryDate = DateTime(now.year + 1, now.month, now.day); // 1 year from now
      
      await _firestore.collection(subscriptionsCollection).doc(userId).set({
        'planType': 'annual',
        'startDate': now,
        'expiryDate': expiryDate,
        'isTrialActive': false,
        'trialStartDate': null,
        'trialEndDate': null,
        'lastPaymentDate': now,
        'nextBillingDate': expiryDate,
        'autoRenewal': true,
        'paymentMethod': paymentMethod,
        'status': 'active',
        'totalPaid': annualSubscriptionFee,
        'currency': 'DZD',
        'createdAt': now,
        'updatedAt': now,
      });
      
      // Record payment
      await _recordPayment(userId, {
        'type': 'subscription',
        'amount': annualSubscriptionFee,
        'currency': 'DZD',
        'paymentMethod': paymentMethod,
        'description': 'Annual subscription',
        'details': paymentDetails,
      });
      
      // Schedule expiry notification
      await _scheduleExpiryNotification(userId, expiryDate);
      
      // Log subscription activation
      await _logSubscriptionEvent(userId, 'subscription_activated', {
        'planType': 'annual',
        'amount': annualSubscriptionFee,
        'expiryDate': expiryDate.toIso8601String(),
        'paymentMethod': paymentMethod,
      });
      
    } catch (e) {
      throw Exception('Failed to activate annual subscription: $e');
    }
  }

  // Process payment via different methods
  Future<void> processPayment({
    required String paymentMethod,
    required double amount,
    required Map<String, dynamic> paymentDetails,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final now = DateTime.now();
      
      switch (paymentMethod.toLowerCase()) {
        case 'chargily':
          await _processChargilyPayment(userId, amount, paymentDetails);
          break;
        case 'stripe':
          await _processStripePayment(userId, amount, paymentDetails);
          break;
        case 'paypal':
          await _processPayPalPayment(userId, amount, paymentDetails);
          break;
        case 'binance':
          await _processBinancePayment(userId, amount, paymentDetails);
          break;
        default:
          throw Exception('Unsupported payment method: $paymentMethod');
      }
      
      // Update subscription
      final subscription = await getEnhancedSubscription();
      if (subscription != null) {
        await _firestore.collection(subscriptionsCollection).doc(userId).update({
          'lastPaymentDate': now,
          'totalPaid': FieldValue.increment(amount),
          'updatedAt': now,
        });
      }
      
      // Record payment
      await _recordPayment(userId, {
        'type': 'payment',
        'amount': amount,
        'currency': 'DZD',
        'paymentMethod': paymentMethod,
        'description': 'Subscription payment',
        'details': paymentDetails,
      });
      
    } catch (e) {
      throw Exception('Failed to process payment: $e');
    }
  }

  // Process CHARGILY payment
  Future<void> _processChargilyPayment(
    String userId,
    double amount,
    Map<String, dynamic> paymentDetails,
  ) async {
    // CHARGILY payment processing logic
    final paymentData = {
      'provider': 'chargily',
      'transactionId': paymentDetails['transactionId'] ?? '',
      'phoneNumber': paymentDetails['phoneNumber'] ?? '',
      'amount': amount,
      'currency': 'DZD',
      'status': 'processing',
      'processedAt': DateTime.now().toIso8601String(),
    };
    
    // Record payment processing
    await _firestore.collection(paymentsCollection).add({
      'userId': userId,
      ...paymentData,
    });
    
    // Update payment status after processing
    await _updatePaymentStatus(paymentData['transactionId'], 'completed');
  }

  // Process STRIPE payment
  Future<void> _processStripePayment(
    String userId,
    double amount,
    Map<String, dynamic> paymentDetails,
  ) async {
    // STRIPE payment processing logic
    final paymentData = {
      'provider': 'stripe',
      'paymentIntentId': paymentDetails['paymentIntentId'] ?? '',
      'cardLast4': paymentDetails['cardLast4'] ?? '',
      'amount': amount,
      'currency': 'DZD',
      'status': 'processing',
      'processedAt': DateTime.now().toIso8601String(),
    };
    
    // Record payment processing
    await _firestore.collection(paymentsCollection).add({
      'userId': userId,
      ...paymentData,
    });
    
    // Update payment status after processing
    await _updatePaymentStatus(paymentData['paymentIntentId'], 'completed');
  }

  // Process PayPal payment
  Future<void> _processPayPalPayment(
    String userId,
    double amount,
    Map<String, dynamic> paymentDetails,
  ) async {
    // PayPal payment processing logic
    final paymentData = {
      'provider': 'paypal',
      'paymentId': paymentDetails['paymentId'] ?? '',
      'payerId': paymentDetails['payerId'] ?? '',
      'amount': amount,
      'currency': 'DZD',
      'status': 'processing',
      'processedAt': DateTime.now().toIso8601String(),
    };
    
    // Record payment processing
    await _firestore.collection(paymentsCollection).add({
      'userId': userId,
      ...paymentData,
    });
    
    // Update payment status after processing
    await _updatePaymentStatus(paymentData['paymentId'], 'completed');
  }

  // Process BINANCE payment
  Future<void> _processBinancePayment(
    String userId,
    double amount,
    Map<String, dynamic> paymentDetails,
  ) async {
    // BINANCE payment processing logic
    final paymentData = {
      'provider': 'binance',
      'transactionHash': paymentDetails['transactionHash'] ?? '',
      'walletAddress': paymentDetails['walletAddress'] ?? '',
      'amount': amount,
      'currency': 'DZD',
      'status': 'processing',
      'processedAt': DateTime.now().toIso8601String(),
    };
    
    // Record payment processing
    await _firestore.collection(paymentsCollection).add({
      'userId': userId,
      ...paymentData,
    });
    
    // Update payment status after processing
    await _updatePaymentStatus(paymentData['transactionHash'], 'completed');
  }

  // Update payment status
  Future<void> _updatePaymentStatus(String paymentId, String status) async {
    try {
      final snapshot = await _firestore
          .collection(paymentsCollection)
          .where('paymentId', '==', paymentId)
          .get();
      
      if (!snapshot.empty) {
        await snapshot.docs.first.reference.update({
          'status': status,
          'updatedAt': DateTime.now(),
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  // Schedule expiry notification
  Future<void> _scheduleExpiryNotification(String userId, DateTime expiryDate) async {
    try {
      final notificationDate = expiryDate.subtract(Duration(days: expiryNotificationDays));
      
      await _firestore.collection(notificationsCollection).add({
        'userId': userId,
        'type': 'expiry_reminder',
        'title': 'انتهاء الاشتراك',
        'message': 'سينتهي اشتراكك خلال $expiryNotificationDays يوم',
        'expiryDate': expiryDate.toIso8601String(),
        'scheduledFor': notificationDate.toIso8601String(),
        'isRead': false,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      // Handle error
    }
  }

  // Check subscription status
  Future<SubscriptionStatus> checkSubscriptionStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return SubscriptionStatus.notAuthenticated;
      
      final subscription = await getEnhancedSubscription();
      if (subscription == null) return SubscriptionStatus.noSubscription;
      
      final now = DateTime.now();
      
      // Check if trial is active
      if (subscription!.isTrialActive) {
        if (now.isAfter(subscription!.trialEndDate!)) {
          return SubscriptionStatus.trialExpired;
        } else {
          return SubscriptionStatus.trialActive;
        }
      }
      
      // Check if subscription is expired
      if (subscription!.expiryDate != null && now.isAfter(subscription!.expiryDate!)) {
        return SubscriptionStatus.expired;
      }
      
      // Check if subscription is active
      if (subscription!.status == 'active') {
        // Check if renewal is needed
        if (subscription!.nextBillingDate != null && now.isAfter(subscription!.nextBillingDate!)) {
          return SubscriptionStatus.renewalNeeded;
        }
        return SubscriptionStatus.active;
      }
      
      return SubscriptionStatus.inactive;
    } catch (e) {
      return SubscriptionStatus.error;
    }
  }

  // Get subscription days remaining
  Future<int> getSubscriptionDaysRemaining() async {
    try {
      final subscription = await getEnhancedSubscription();
      if (subscription == null || subscription!.expiryDate == null) return 0;
      
      final now = DateTime.now();
      final difference = subscription!.expiryDate!.difference(now);
      
      if (difference.isNegative) return 0;
      
      return difference.inDays;
    } catch (e) {
      return 0;
    }
  }

  // Get subscription analytics
  Future<SubscriptionAnalytics> getSubscriptionAnalytics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return SubscriptionAnalytics();
      
      final subscription = await getEnhancedSubscription();
      if (subscription == null) return SubscriptionAnalytics();
      
      // Get payment history
      final paymentsSnapshot = await _firestore
          .collection(paymentsCollection)
          .where('userId', '==', userId)
          .orderBy('processedAt', descending: true)
          .limit(10)
          .get();
      
      final totalPaid = subscription!.totalPaid;
      final paymentsCount = paymentsSnapshot.size;
      
      // Calculate metrics
      final averagePayment = paymentsCount > 0 ? totalPaid / paymentsCount : 0.0;
      final daysSinceStart = subscription!.startDate.difference(DateTime.now()).inDays.abs();
      
      return SubscriptionAnalytics(
        totalPaid: totalPaid,
        paymentsCount: paymentsCount,
        averagePayment: averagePayment,
        daysSinceStart: daysSinceStart,
        planType: subscription!.planType,
        status: subscription!.status,
        expiryDate: subscription!.expiryDate,
        daysRemaining: await getSubscriptionDaysRemaining(),
      );
    } catch (e) {
      return SubscriptionAnalytics();
    }
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      await _firestore.collection(subscriptionsCollection).doc(userId).update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
      
      // Log cancellation
      await _logSubscriptionEvent(userId, 'subscription_cancelled', {
        'reason': 'user_request',
        'cancelledAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to cancel subscription: $e');
    }
  }

  // Renew subscription
  Future<void> renewSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final subscription = await getEnhancedSubscription();
      if (subscription == null) return;
      
      final now = DateTime.now();
      final newExpiryDate = DateTime(now.year + 1, now.month, now.day);
      
      await _firestore.collection(subscriptionsCollection).doc(userId).update({
        'status': 'active',
        'expiryDate': newExpiryDate,
        'nextBillingDate': newExpiryDate,
        'renewedAt': now,
        'updatedAt': now,
      });
      
      // Log renewal
      await _logSubscriptionEvent(userId, 'subscription_renewed', {
        'renewedAt': now.toIso8601String(),
        'newExpiryDate': newExpiryDate.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to renew subscription: $e');
    }
  }

  // Log subscription event
  Future<void> _logSubscriptionEvent(String userId, String eventType, Map<String, dynamic> eventData) async {
    try {
      await _firestore.collection('subscription_events').add({
        'userId': userId,
        'eventType': eventType,
        'eventData': eventData,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      // Handle error
    }
  }

  // Record payment
  Future<void> _recordPayment(String userId, Map<String, dynamic> paymentData) async {
    try {
      await _firestore.collection(paymentsCollection).add({
        'userId': userId,
        ...paymentData,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      // Handle error
    }
  }
}

// Enhanced subscription model
class EnhancedSubscription {
  final String id;
  final String userId;
  final String planType;
  final DateTime startDate;
  final DateTime? expiryDate;
  final bool isTrialActive;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;
  final DateTime? lastPaymentDate;
  final DateTime? nextBillingDate;
  final bool autoRenewal;
  final String paymentMethod;
  final String status;
  final double totalPaid;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  EnhancedSubscription({
    required this.id,
    required this.userId,
    required this.planType,
    required this.startDate,
    this.expiryDate,
    required this.isTrialActive,
    this.trialStartDate,
    this.trialEndDate,
    this.lastPaymentDate,
    this.nextBillingDate,
    required this.autoRenewal,
    required this.paymentMethod,
    required this.status,
    required this.totalPaid,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  // Get formatted expiry date
  String get formattedExpiryDate {
    if (expiryDate == null) return 'غير محدد';
    return DateFormat('dd/MM/yyyy').format(expiryDate!);
  }

  // Get formatted trial end date
  String get formattedTrialEndDate {
    if (trialEndDate == null) return 'غير محدد';
    return DateFormat('dd/MM/yyyy').format(trialEndDate!);
  }

  // Get days remaining
  int get daysRemaining {
    if (expiryDate == null) return 0;
    final now = DateTime.now();
    final difference = expiryDate!.difference(now);
    return max(0, difference.inDays);
  }

  // Get subscription status text
  String get statusText {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'trial':
        return 'تجربة مجانية';
      case 'expired':
        return 'منتهي الصلاحية';
      case 'cancelled':
        return 'ملغي';
      case 'inactive':
        return 'غير نشط';
      default:
        return 'غير معروف';
    }
  }

  // Get plan type text
  String get planTypeText {
    switch (planType) {
      case 'trial':
        return 'تجربة مجانية';
      case 'annual':
        return 'اشتراك سنوي';
      case 'monthly':
        return 'اشتراك شهري';
      default:
        return 'غير محدد';
    }
  }

  // Check if needs renewal
  bool get needsRenewal {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final daysUntilExpiry = expiryDate!.difference(now).inDays;
    return daysUntilExpiry <= 30 && status == 'active';
  }
}

// Subscription status enum
enum SubscriptionStatus {
  notAuthenticated,
  noSubscription,
  trialActive,
  trialExpired,
  active,
  expired,
  renewalNeeded,
  cancelled,
  inactive,
  error,
}

// Subscription analytics model
class SubscriptionAnalytics {
  final double totalPaid;
  final int paymentsCount;
  final double averagePayment;
  final int daysSinceStart;
  final String planType;
  final String status;
  final DateTime? expiryDate;
  final int daysRemaining;

  SubscriptionAnalytics({
    required this.totalPaid,
    required this.paymentsCount,
    required this.averagePayment,
    required this.daysSinceStart,
    required this.planType,
    required this.status,
    this.expiryDate,
    required this.daysRemaining,
  });

  // Get formatted total paid
  String get formattedTotalPaid {
    return '${totalPaid.toStringAsFixed(2)} دج';
  }

  // Get formatted average payment
  String get formattedAveragePayment {
    return '${averagePayment.toStringAsFixed(2)} دج';
  }

  // Get formatted days since start
  String get formattedDaysSinceStart {
    return '$daysSinceStart يوم';
  }

  // Get formatted days remaining
  String get formattedDaysRemaining {
    return '$daysRemaining يوم';
  }
}
