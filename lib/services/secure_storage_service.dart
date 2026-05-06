import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Storage keys
  static const String _userPreferencesKey = 'user_preferences';
  static const String _appSettingsKey = 'app_settings';
  static const String _sessionDataKey = 'session_data';
  static const String _cacheDataKey = 'cache_data';
  static const String _encryptionKey = 'encryption_key';

  // Initialize secure storage
  Future<void> initialize() async {
    try {
      // Generate encryption key if not exists
      final existingKey = await _secureStorage.read(key: _encryptionKey);
      if (existingKey == null) {
        final key = _generateEncryptionKey();
        await _secureStorage.write(key: _encryptionKey, value: key);
      }

      print('Secure Storage initialized');
    } catch (e) {
      print('Error initializing secure storage: $e');
    }
  }

  // Generate encryption key
  String _generateEncryptionKey() {
    final bytes = List<int>.generate(32, (index) => index % 256);
    return base64Encode(bytes);
  }

  // Save user preferences
  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final encryptedData = _encryptData(jsonEncode(preferences));
      await _secureStorage.write(key: _userPreferencesKey, value: encryptedData);
      print('User preferences saved');
    } catch (e) {
      print('Error saving user preferences: $e');
    }
  }

  // Get user preferences
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final encryptedData = await _secureStorage.read(key: _userPreferencesKey);
      if (encryptedData != null) {
        final decryptedData = _decryptData(encryptedData);
        return jsonDecode(decryptedData);
      }
      return {};
    } catch (e) {
      print('Error getting user preferences: $e');
      return {};
    }
  }

  // Save app settings
  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    try {
      final encryptedData = _encryptData(jsonEncode(settings));
      await _secureStorage.write(key: _appSettingsKey, value: encryptedData);
      print('App settings saved');
    } catch (e) {
      print('Error saving app settings: $e');
    }
  }

  // Get app settings
  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final encryptedData = await _secureStorage.read(key: _appSettingsKey);
      if (encryptedData != null) {
        final decryptedData = _decryptData(encryptedData);
        return jsonDecode(decryptedData);
      }
      return {};
    } catch (e) {
      print('Error getting app settings: $e');
      return {};
    }
  }

  // Save session data
  Future<void> saveSessionData(Map<String, dynamic> sessionData) async {
    try {
      final encryptedData = _encryptData(jsonEncode(sessionData));
      await _secureStorage.write(key: _sessionDataKey, value: encryptedData);
      print('Session data saved');
    } catch (e) {
      print('Error saving session data: $e');
    }
  }

  // Get session data
  Future<Map<String, dynamic>> getSessionData() async {
    try {
      final encryptedData = await _secureStorage.read(key: _sessionDataKey);
      if (encryptedData != null) {
        final decryptedData = _decryptData(encryptedData);
        return jsonDecode(decryptedData);
      }
      return {};
    } catch (e) {
      print('Error getting session data: $e');
      return {};
    }
  }

  // Save cache data
  Future<void> saveCacheData(Map<String, dynamic> cacheData) async {
    try {
      final encryptedData = _encryptData(jsonEncode(cacheData));
      await _secureStorage.write(key: _cacheDataKey, value: encryptedData);
      print('Cache data saved');
    } catch (e) {
      print('Error saving cache data: $e');
    }
  }

  // Get cache data
  Future<Map<String, dynamic>> getCacheData() async {
    try {
      final encryptedData = await _secureStorage.read(key: _cacheDataKey);
      if (encryptedData != null) {
        final decryptedData = _decryptData(encryptedData);
        return jsonDecode(decryptedData);
      }
      return {};
    } catch (e) {
      print('Error getting cache data: $e');
      return {};
    }
  }

  // Clear cache data
  Future<void> clearCacheData() async {
    try {
      await _secureStorage.delete(key: _cacheDataKey);
      print('Cache data cleared');
    } catch (e) {
      print('Error clearing cache data: $e');
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      await _secureStorage.deleteAll();
      print('All secure data cleared');
    } catch (e) {
      print('Error clearing all data: $e');
    }
  }

  // Encrypt data
  String _encryptData(String data) {
    try {
      final keyString = _secureStorage.read(key: _encryptionKey) as String? ?? '';
      final key = base64Decode(keyString);
      final bytes = utf8.encode(data);
      
      final encrypter = Encrypter(AES(key));
      final encrypted = encrypter.convert(bytes);
      
      return base64Encode(encrypted);
    } catch (e) {
      print('Error encrypting data: $e');
      return '';
    }
  }

  // Decrypt data
  String _decryptData(String encryptedData) {
    try {
      final keyString = _secureStorage.read(key: _encryptionKey) as String? ?? '';
      final key = base64Decode(keyString);
      final encrypted = base64Decode(encryptedData);
      
      final encrypter = Encrypter(AES(key));
      final decrypted = encrypter.convert(encrypted);
      
      return utf8.decode(decrypted);
    } catch (e) {
      print('Error decrypting data: $e');
      return '';
    }
  }

  // Check if data exists
  Future<bool> hasData(String key) async {
    try {
      final data = await _secureStorage.read(key: key);
      return data != null;
    } catch (e) {
      print('Error checking data existence: $e');
      return false;
    }
  }

  // Delete specific data
  Future<void> deleteData(String key) async {
    try {
      await _secureStorage.delete(key: key);
      print('Data deleted for key: $key');
    } catch (e) {
      print('Error deleting data: $e');
    }
  }

  // Get storage info
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final allKeys = await _secureStorage.readAll();
      return {
        'totalKeys': allKeys.length,
        'keys': allKeys.keys.toList(),
        'hasUserPreferences': allKeys.containsKey(_userPreferencesKey),
        'hasAppSettings': allKeys.containsKey(_appSettingsKey),
        'hasSessionData': allKeys.containsKey(_sessionDataKey),
        'hasCacheData': allKeys.containsKey(_cacheDataKey),
      };
    } catch (e) {
      print('Error getting storage info: $e');
      return {};
    }
  }
}
