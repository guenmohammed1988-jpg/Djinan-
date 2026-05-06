import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class AuthTokenService {
  static final AuthTokenService _instance = AuthTokenService._internal();
  factory AuthTokenService() => _instance;
  AuthTokenService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _deviceInfoKey = 'device_info';
  static const String _lastTokenRefreshKey = 'last_token_refresh';

  // Initialize service
  Future<void> initialize() async {
    try {
      // Initialize secure storage
      await _secureStorage.write(
        key: _tokenKey,
        value: '',
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      await _secureStorage.write(
        key: _tokenExpiryKey,
        value: '',
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      await _secureStorage.write(
        key: _deviceInfoKey,
        value: '',
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      await _secureStorage.write(
        key: _lastTokenRefreshKey,
        value: '',
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

      print('Auth Token Service initialized');
    } catch (e) {
      print('Error initializing Auth Token Service: $e');
    }
  }

  // Get current FCM token
  Future<String?> getCurrentToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      print('Error getting current token: $e');
      return null;
    }
  }

  // Save FCM token
  Future<void> saveToken({
    required String token,
    required DateTime expiryDate,
  }) async {
    try {
      // Save token to secure storage
      await _secureStorage.write(
        key: _tokenKey,
        value: token,
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
      
      // Save token expiry
      await _secureStorage.write(
        key: _tokenExpiryKey,
        value: expiryDate.toIso8601String(),
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

      // Save device info
      final deviceInfo = await _getDeviceIdentifier();
      await _secureStorage.write(
        key: _deviceInfoKey,
        value: deviceInfo,
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

      // Update last refresh time
      await _secureStorage.write(
        key: _lastTokenRefreshKey,
        value: DateTime.now().toIso8601String(),
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

      // Save to Firestore
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'tokenExpiry': expiryDate,
          'deviceInfo': deviceInfo,
          'lastTokenRefresh': DateTime.now().toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('Token saved successfully');
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  // Check if token is valid and not expired
  Future<bool> isTokenValid() async {
    try {
      final token = await getCurrentToken();
      final expiryString = await _secureStorage.read(key: _tokenExpiryKey);
      
      if (token == null || expiryString == null) {
        return false;
      }
      
      final expiry = DateTime.parse(expiryString);
      final now = DateTime.now();
      
      // Token is valid if it exists and hasn't expired
      return token.isNotEmpty && now.isBefore(expiry);
    } catch (e) {
      print('Error checking token validity: $e');
      return false;
    }
  }

  // Get device identifier
  Future<String> _getDeviceIdentifier() async {
    try {
      // This would typically use device_info package
      // For now, we'll create a simple device fingerprint
      final userId = _auth.currentUser?.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create device fingerprint using user ID and timestamp
      final fingerprint = sha256.convert(utf8.encode('$userId-$timestamp')).toString();
      
      return fingerprint;
    } catch (e) {
      print('Error getting device identifier: $e');
      return '';
    }
  }

  // Refresh token if needed
  Future<void> refreshTokenIfNeeded() async {
    try {
      final isValid = await isTokenValid();
      
      if (!isValid) {
        // Token is invalid or expired, refresh it
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          final newToken = await _auth.currentUser?.getIdToken();
          
          if (newToken != null) {
            await saveToken(
              token: newToken,
              expiryDate: DateTime.now().add(const Duration(days: 60)),
            );
          }
        }
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
  }

  // Clear token
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      await _secureStorage.delete(key: _deviceInfoKey);
      await _secureStorage.delete(key: _lastTokenRefreshKey);

      // Clear from Firestore
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
          'tokenExpiry': FieldValue.delete(),
          'deviceInfo': FieldValue.delete(),
          'lastTokenRefresh': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('Token cleared successfully');
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  // Get token from Firestore
  Future<String?> getTokenFromFirestore() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          return userData['fcmToken'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('Error getting token from Firestore: $e');
      return null;
    }
  }

  // Get cached token
  Future<String?> getCachedToken() async {
    try {
      final cachedToken = await _secureStorage.read(key: _tokenKey);
      final firestoreToken = await getTokenFromFirestore();
      
      // Return cached token if valid, otherwise get from Firestore
      if (await isTokenValid()) {
        return cachedToken ?? firestoreToken;
      } else {
        return firestoreToken;
      }
    } catch (e) {
      print('Error getting cached token: $e');
      return null;
    }
  }

  // Get token expiry
  Future<DateTime?> getTokenExpiry() async {
    try {
      final expiryString = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryString != null) {
        return DateTime.parse(expiryString);
      }
      return null;
    } catch (e) {
      print('Error getting token expiry: $e');
      return null;
    }
  }

  // Get device info
  Future<String?> getDeviceInfo() async {
    try {
      return await _secureStorage.read(key: _deviceInfoKey);
    } catch (e) {
      print('Error getting device info: $e');
      return null;
    }
  }

  // Sync token with Firestore
  Future<void> syncTokenWithFirestore() async {
    try {
      final cachedToken = await getCachedToken();
      final firestoreToken = await getTokenFromFirestore();
      
      if (cachedToken != firestoreToken && cachedToken != null) {
        // Update Firestore with cached token
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': cachedToken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error syncing token with Firestore: $e');
    }
  }

  // Get token status
  Future<Map<String, dynamic>> getTokenStatus() async {
    try {
      final token = await getCachedToken();
      final expiry = await getTokenExpiry();
      final isValid = await isTokenValid();
      final lastRefresh = await _secureStorage.read(key: _lastTokenRefreshKey);
      
      return {
        'token': token,
        'expiry': expiry?.toIso8601String(),
        'isValid': isValid,
        'lastRefresh': lastRefresh,
        'needsRefresh': !isValid,
      };
    } catch (e) {
      print('Error getting token status: $e');
      return {};
    }
  }
}
