import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Constants
  static const String subscriptionsCollection = 'subscriptions';
  static const String merchantsCollection = 'merchants';
  static const String customersCollection = 'customers';
  
  // Pricing constants
  static const double customerPricePerHour = 25.0;
  static const int minActiveHoursPerDay = 15;
  static const double merchantSubscriptionFee = 2000.0;
  static const double payoutThreshold = 6000.0;
  static const int pendingPeriodDays = 7;
  static const int baseCustomerLimit = 30;
  static const int tier1CustomerLimit = 30;
  static const int tier2CustomerLimit = 60;
  static const int tier3CustomerLimit = 90;
  static const double tier1Payout = 1800.0;
  static const double tier2Payout = 2000.0;
  static const double tier3Payout = 3000.0;

  // Get merchant subscription info
  Future<MerchantSubscription?> getMerchantSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;
      
      final doc = await _firestore
          .collection(subscriptionsCollection)
          .where('merchantId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (doc.docs.isEmpty) return null;
      
      final data = doc.docs.first.data() as Map<String, dynamic>;
      return MerchantSubscription(
        id: doc.docs.first.id,
        merchantId: data['merchantId'] ?? '',
        isActive: data['isActive'] ?? false,
        subscriptionDate: (data['subscriptionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
        lastPaymentDate: (data['lastPaymentDate'] as Timestamp?)?.toDate(),
        customerCount: (data['customerCount'] ?? 0) as int,
        totalRevenue: (data['totalRevenue'] ?? 0.0) as double,
        pendingPayout: (data['pendingPayout'] ?? 0.0) as double,
      );
    } catch (e) {
      return null;
    }
  }

  // Create merchant subscription
  Future<void> createMerchantSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Check if merchant already has subscription
      final existing = await getMerchantSubscription();
      if (existing != null) {
        throw Exception('Merchant already has an active subscription');
      }
      
      await _firestore.collection(subscriptionsCollection).add({
        'merchantId': userId,
        'isActive': true,
        'subscriptionDate': FieldValue.serverTimestamp(),
        'expiryDate': null, // No expiry for merchant subscription
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'customerCount': 0,
        'totalRevenue': 0.0,
        'pendingPayout': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create merchant subscription: $e');
    }
  }

  // Get customer subscriptions
  Future<List<CustomerSubscription>> getCustomerSubscriptions() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final doc = await _firestore
          .collection(customersCollection)
          .doc(userId)
          .get();
      
      if (!doc.exists) return [];
      
      final data = doc.data() as Map<String, dynamic>;
      final subscriptions = List<CustomerSubscription>.from(data['subscriptions'] ?? []);
      
      return subscriptions;
    } catch (e) {
      return [];
    }
  }

  // Create customer subscription
  Future<String> createCustomerSubscription({
    required String merchantId,
    required String customerId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      
      final subscriptionId = _firestore.collection(customersCollection).doc().collection('subscriptions').doc().id;
      
      await subscriptionId.set({
        'merchantId': merchantId,
        'customerId': customerId,
        'isActive': true,
        'startDate': FieldValue.serverTimestamp(),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'activeHours': 0,
        'pendingPeriod': pendingPeriodDays,
        'totalPaid': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update merchant customer count
      await _updateMerchantCustomerCount(merchantId);
      
      return subscriptionId.id;
    } catch (e) {
      throw Exception('Failed to create customer subscription: $e');
    }
  }

  // Update customer activity
  Future<void> updateCustomerActivity({
    required String subscriptionId,
    required int additionalHours,
  }) async {
    try {
      await _firestore
          .collection(customersCollection)
          .doc()
          .collection('subscriptions')
          .doc(subscriptionId)
          .update({
        'activeHours': FieldValue.increment(additionalHours),
        'lastActivityDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update customer activity: $e');
    }
  }

  // Check if customer meets activity requirement
  Future<bool> checkCustomerActivityRequirement(String subscriptionId) async {
    try {
      final doc = await _firestore
          .collection(customersCollection)
          .doc()
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      final activeHours = (data['activeHours'] ?? 0) as int;
      final startDate = (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
      
      // Check if customer has been active for required hours within the period
      final daysActive = DateTime.now().difference(startDate).inDays;
      final requiredHoursPerPeriod = minActiveHoursPerDay * daysActive;
      
      return activeHours >= requiredHoursPerPeriod;
    } catch (e) {
      return false;
    }
  }

  // Process customer payment
  Future<void> processCustomerPayment({
    required String subscriptionId,
    required double amount,
  }) async {
    try {
      await _firestore
          .collection(customersCollection)
          .doc()
          .collection('subscriptions')
          .doc(subscriptionId)
          .update({
        'totalPaid': FieldValue.increment(amount),
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update merchant revenue
      final subscription = await _getCustomerSubscription(subscriptionId);
      if (subscription != null) {
        await _updateMerchantRevenue(subscription.merchantId, amount);
      }
    } catch (e) {
      throw Exception('Failed to process payment: $e');
    }
  }

  // Check if merchant can withdraw
  Future<bool> canMerchantWithdraw(String merchantId) async {
    try {
      final subscription = await getMerchantSubscription();
      if (subscription == null) return false;
      
      // Check if pending payout meets threshold
      return subscription.pendingPayout >= payoutThreshold;
    } catch (e) {
      return false;
    }
  }

  // Process merchant withdrawal
  Future<void> processWithdrawal({
    required String merchantId,
    required double amount,
  }) async {
    try {
      if (amount > (await _getMerchantPendingPayout(merchantId))) {
        throw Exception('Withdrawal amount exceeds pending payout');
      }
      
      await _firestore.collection(subscriptionsCollection).doc(merchantId).update({
        'pendingPayout': FieldValue.increment(-amount),
        'lastWithdrawalDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to process withdrawal: $e');
    }
  }

  // Get merchant tier based on customer count
  MerchantTier getMerchantTier(int customerCount) {
    if (customerCount >= tier3CustomerLimit) {
      return MerchantTier.tier3;
    } else if (customerCount >= tier2CustomerLimit) {
      return MerchantTier.tier2;
    } else {
      return MerchantTier.tier1;
    }
  }

  // Get tier payout amount
  double getTierPayoutAmount(int customerCount) {
    final tier = getMerchantTier(customerCount);
    switch (tier) {
      case MerchantTier.tier1:
        return tier1Payout;
      case MerchantTier.tier2:
        return tier2Payout;
      case MerchantTier.tier3:
        return tier3Payout;
      default:
        return tier1Payout;
    }
  }

  // Update merchant customer count
  Future<void> _updateMerchantCustomerCount(String merchantId) async {
    try {
      await _firestore.collection(subscriptionsCollection).doc(merchantId).update({
        'customerCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle error
    }
  }

  // Update merchant revenue
  Future<void> _updateMerchantRevenue(String merchantId, double amount) async {
    try {
      await _firestore.collection(subscriptionsCollection).doc(merchantId).update({
        'totalRevenue': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle error
    }
  }

  // Get merchant pending payout
  Future<double> _getMerchantPendingPayout(String merchantId) async {
    try {
      final doc = await _firestore.collection(subscriptionsCollection).doc(merchantId).get();
      if (!doc.exists) return 0.0;
      
      final data = doc.data() as Map<String, dynamic>;
      return (data['pendingPayout'] ?? 0.0) as double;
    } catch (e) {
      return 0.0;
    }
  }

  // Get customer subscription by ID
  Future<CustomerSubscription?> _getCustomerSubscription(String subscriptionId) async {
    try {
      final doc = await _firestore
          .collection(customersCollection)
          .doc()
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return CustomerSubscription(
        id: doc.id,
        merchantId: data['merchantId'] ?? '',
        customerId: data['customerId'] ?? '',
        isActive: data['isActive'] ?? false,
        startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastActivityDate: (data['lastActivityDate'] as Timestamp?)?.toDate(),
        activeHours: (data['activeHours'] ?? 0) as int,
        pendingPeriod: (data['pendingPeriod'] ?? pendingPeriodDays) as int,
        totalPaid: (data['totalPaid'] ?? 0.0) as double,
        meetsRequirement: await checkCustomerActivityRequirement(subscriptionId),
      );
    } catch (e) {
      return null;
    }
  }

  // Get subscription statistics
  Future<SubscriptionStats> getSubscriptionStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return SubscriptionStats();
      
      final merchantSub = await getMerchantSubscription();
      final customerSubs = await getCustomerSubscriptions();
      
      int totalCustomers = customerSubs.length;
      int activeCustomers = customerSubs.where((sub) => sub.isActive).length;
      int pendingCustomers = customerSubs.where((sub) => !sub.meetsRequirement).length;
      
      return SubscriptionStats(
        totalCustomers: totalCustomers,
        activeCustomers: activeCustomers,
        pendingCustomers: pendingCustomers,
        merchantSubscription: merchantSub,
        currentTier: merchantSub != null 
            ? getMerchantTier(merchantSub.customerCount)
            : MerchantTier.none,
      );
    } catch (e) {
      return SubscriptionStats();
    }
  }
}

// Merchant subscription model
class MerchantSubscription {
  final String id;
  final String merchantId;
  final bool isActive;
  final DateTime subscriptionDate;
  final DateTime? expiryDate;
  final DateTime? lastPaymentDate;
  final int customerCount;
  final double totalRevenue;
  final double pendingPayout;

  MerchantSubscription({
    required this.id,
    required this.merchantId,
    required this.isActive,
    required this.subscriptionDate,
    this.expiryDate,
    this.lastPaymentDate,
    required this.customerCount,
    required this.totalRevenue,
    required this.pendingPayout,
  });

  // Get current tier
  MerchantTier get currentTier => getMerchantTier(customerCount);

  // Check if can withdraw
  bool get canWithdraw => pendingPayout >= 6000.0;

  // Get formatted pending payout
  String get formattedPendingPayout => '${pendingPayout.toStringAsFixed(2)} دج';

  // Get tier name
  String get tierName {
    switch (currentTier) {
      case MerchantTier.tier1:
        return 'المستوى الأول';
      case MerchantTier.tier2:
        return 'المستوى الثاني';
      case MerchantTier.tier3:
        return 'المستوى الثالث';
      default:
        return 'غير مشترك';
    }
  }
}

// Customer subscription model
class CustomerSubscription {
  final String id;
  final String merchantId;
  final String customerId;
  final bool isActive;
  final DateTime startDate;
  final DateTime? lastActivityDate;
  final int activeHours;
  final int pendingPeriod;
  final double totalPaid;
  final bool meetsRequirement;

  CustomerSubscription({
    required this.id,
    required this.merchantId,
    required this.customerId,
    required this.isActive,
    required this.startDate,
    this.lastActivityDate,
    required this.activeHours,
    required this.pendingPeriod,
    required this.totalPaid,
    required this.meetsRequirement,
  });

  // Get formatted total paid
  String get formattedTotalPaid => '${totalPaid.toStringAsFixed(2)} دج';

  // Get remaining hours
  int get remainingHours => max(0, minActiveHoursPerDay * pendingPeriodDays - activeHours);

  // Get formatted remaining hours
  String get formattedRemainingHours => '$remainingHours ساعة';

  // Get progress percentage
  double get progressPercentage => (activeHours / (minActiveHoursPerDay * pendingPeriodDays)) * 100;

  // Get formatted progress
  String get formattedProgress => '${progressPercentage.toStringAsFixed(1)}%';
}

// Merchant tier enum
enum MerchantTier {
  none,
  tier1,
  tier2,
  tier3,
}

// Subscription statistics model
class SubscriptionStats {
  final int totalCustomers;
  final int activeCustomers;
  final int pendingCustomers;
  final MerchantSubscription? merchantSubscription;
  final MerchantTier currentTier;

  SubscriptionStats({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.pendingCustomers,
    this.merchantSubscription,
    required this.currentTier,
  });
}
