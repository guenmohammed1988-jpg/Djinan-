import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_service.dart';
import 'secure_storage_service.dart';

class LogoutService {
  static final LogoutService _instance = LogoutService._internal();
  factory LogoutService() => _instance;
  LogoutService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final AuthTokenService _tokenService = AuthTokenService();
  final SecureStorageService _storageService = SecureStorageService();

  // Complete logout process
  Future<LogoutResult> performLogout({
    bool clearAllData = false,
    bool clearCache = true,
  }) async {
    try {
      // Start logout process
      await _updateUserStatus(isOnline: false, lastSeen: DateTime.now());

      // Clear FCM token
      await _tokenService.clearToken();

      // Sign out from Firebase
      await _auth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Sign out from Apple (if applicable)
      try {
        // Note: Apple doesn't have a direct sign out method
        // The credential is automatically invalidated when Firebase signs out
      } catch (e) {
        // Apple sign out might not be available, continue
      }

      // Clear local data if requested
      if (clearAllData) {
        await _clearAllLocalData();
      } else if (clearCache) {
        await _clearCacheOnly();
      }

      return LogoutResult.success();
    } catch (e) {
      return LogoutResult.error('فشل تسجيل الخروج: ${e.toString()}');
    }
  }

  // Update user status in Firestore
  Future<void> _updateUserStatus({
    required bool isOnline,
    DateTime? lastSeen,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final updateData = <String, dynamic>{
          'isOnline': isOnline,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (lastSeen != null) {
          updateData['lastSeen'] = Timestamp.fromDate(lastSeen);
        }

        await _firestore.collection('users').doc(userId).update(updateData);
      }
    } catch (e) {
      // Continue with logout even if status update fails
      print('Error updating user status: $e');
    }
  }

  // Clear all local data
  Future<void> _clearAllLocalData() async {
    try {
      // Clear secure storage
      await _secureStorage.deleteAll();
      await _storageService.clearAllData();

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Clear any cached data
      await _clearCacheOnly();
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }

  // Clear cache only
  Future<void> _clearCacheOnly() async {
    try {
      await _storageService.clearCacheData();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Check if user is currently logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Get current user info
  Map<String, dynamic>? get currentUserInfo {
    final user = _auth.currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'isAnonymous': user.isAnonymous,
    };
  }

  // Force logout (for security reasons)
  Future<LogoutResult> forceLogout() async {
    try {
      // Log security event
      await _logSecurityEvent('force_logout');

      // Perform complete logout with data clearing
      return await performLogout(clearAllData: true, clearCache: true);
    } catch (e) {
      return LogoutResult.error('فشل تسجيل الخروج الإجباري: ${e.toString()}');
    }
  }

  // Log security events
  Future<void> _logSecurityEvent(String event) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('security_logs').add({
          'userId': userId,
          'event': event,
          'timestamp': FieldValue.serverTimestamp(),
          'deviceInfo': await _getDeviceInfo(),
        });
      }
    } catch (e) {
      print('Error logging security event: $e');
    }
  }

  // Get device info for logging
  Future<String> _getDeviceInfo() async {
    try {
      // This would typically use device_info package
      // For now, return a simple identifier
      return 'Flutter App';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  // Validate logout request
  bool canLogout() {
    // Add any business logic for when logout is allowed
    return true;
  }
}

// Logout result class
class LogoutResult {
  final bool success;
  final String? errorMessage;

  LogoutResult.success() : success = true, errorMessage = null;
  LogoutResult.error(this.errorMessage) : success = false;

  @override
  String toString() {
    if (success) {
      return 'LogoutResult.success()';
    } else {
      return 'LogoutResult.error(errorMessage: $errorMessage)';
    }
  }
}
