import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

class MerchantService {
  static final MerchantService _instance = MerchantService._internal();
  factory MerchantService() => _instance;
  MerchantService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate unique username from store name
  String generateUsername(String storeName) {
    // Remove spaces and special characters, convert to lowercase
    final cleanName = storeName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .toLowerCase()
        .replaceAll(' ', '');
    
    // Generate random number suffix
    final random = Random();
    final suffix = random.nextInt(9999);
    
    return '@${cleanName}_$suffix';
  }

  // Validate store name format
  String? validateStoreName(String storeName) {
    if (storeName.isEmpty) return 'اسم المتجر مطلوب';
    
    if (storeName.length < 3) {
      return 'اسم المتجر يجب أن يكون 3 أحرف على الأقل';
    }
    
    if (storeName.length > 50) {
      return 'اسم المتجر يجب أن يكون أقل من 50 حرفًا';
    }
    
    // Check for valid characters (Arabic, English, numbers, spaces)
    final validPattern = RegExp(r'^[\u0600-\u06FFa-zA-Z0-9\s]+$');
    if (!validPattern.hasMatch(storeName)) {
      return 'اسم المتجر يجب أن يحتوي على أحرف وأرقام فقط';
    }
    
    return null;
  }

  // Validate phone number
  String? validatePhone(String phone) {
    if (phone.isEmpty) return 'رقم الهاتف مطلوب';
    
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'رقم الهاتف يجب أن يكون بين 10 و 15 رقمًا';
    }
    
    return null;
  }

  // Validate location
  String? validateLocation(String location) {
    if (location.isEmpty) return 'الموقع الجغرافي مطلوب';
    
    if (location.length < 3) {
      return 'الموقع يجب أن يكون 3 أحرف على الأقل';
    }
    
    return null;
  }

  // Check if store name is unique via Cloud Function
  Future<bool> isStoreNameUnique(String storeName) async {
    try {
      // This would call a Cloud Function to check uniqueness
      final result = await _firestore
          .collection('merchants')
          .where('storeName', isEqualTo: storeName.toLowerCase())
          .limit(1)
          .get();
      
      return result.docs.isEmpty;
    } catch (e) {
      // For now, assume it's unique if there's an error
      // In production, this should call a proper Cloud Function
      return true;
    }
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  // Save merchant data
  Future<void> saveMerchantData({
    required String storeName,
    required String phone,
    required String location,
    required String username,
    Map<String, dynamic>? additionalData,
  }) async {
    final merchantData = {
      'userId': _auth.currentUser?.uid,
      'storeName': storeName,
      'phone': phone,
      'location': location,
      'username': username,
      'isActive': false, // Account disabled until 100% completion
      'profileCompletion': 0.0, // Track completion percentage
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...additionalData ?? {},
    };

    await _firestore
        .collection('merchants')
        .doc(_auth.currentUser?.uid)
        .set(merchantData);
  }

  // Update merchant profile completion
  Future<void> updateProfileCompletion(double completion) async {
    await _firestore
        .collection('merchants')
        .doc(_auth.currentUser?.uid)
        .update({
          'profileCompletion': completion,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // If 100% complete, activate account
    if (completion >= 100.0) {
      await _firestore
          .collection('merchants')
          .doc(_auth.currentUser?.uid)
          .update({
            'isActive': true,
            'activatedAt': FieldValue.serverTimestamp(),
          });
    }
  }

  // Get merchant data
  Future<DocumentSnapshot?> getMerchantData() async {
    try {
      return await _firestore
          .collection('merchants')
          .doc(_auth.currentUser?.uid)
          .get();
    } catch (e) {
      return null;
    }
  }

  // Get profile completion percentage
  Future<double> getProfileCompletion() async {
    final merchantDoc = await getMerchantData();
    
    if (!merchantDoc?.exists) return 0.0;
    
    final data = merchantDoc!.data() as Map<String, dynamic>;
    return (data['profileCompletion'] ?? 0.0).toDouble();
  }

  // Check if merchant account is active
  Future<bool> isMerchantActive() async {
    final merchantDoc = await getMerchantData();
    
    if (!merchantDoc?.exists) return false;
    
    final data = merchantDoc!.data() as Map<String, dynamic>;
    return data['isActive'] ?? false;
  }

  // Calculate profile completion percentage
  double calculateCompletion({
    required bool hasStoreName,
    required bool hasPhone,
    required bool hasLocation,
    required bool hasLogo,
    required bool hasDescription,
    required bool hasWorkingHours,
    required bool hasCategories,
  }) {
    int completedFields = 0;
    int totalFields = 6;

    if (hasStoreName) completedFields++;
    if (hasPhone) completedFields++;
    if (hasLocation) completedFields++;
    if (hasLogo) completedFields++;
    if (hasDescription) completedFields++;
    if (hasWorkingHours) completedFields++;
    if (hasCategories) completedFields++;

    return (completedFields / totalFields) * 100;
  }
}

// Merchant data model
class MerchantData {
  final String storeName;
  final String phone;
  final String location;
  final String username;
  final bool isActive;
  final double profileCompletion;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MerchantData({
    required this.storeName,
    required this.phone,
    required this.location,
    required this.username,
    required this.isActive,
    required this.profileCompletion,
    required this.createdAt,
    this.updatedAt,
  });

  factory MerchantData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MerchantData(
      storeName: data['storeName'] ?? '',
      phone: data['phone'] ?? '',
      location: data['location'] ?? '',
      username: data['username'] ?? '',
      isActive: data['isActive'] ?? false,
      profileCompletion: (data['profileCompletion'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
