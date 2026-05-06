import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final SharedPreferences _prefs = SharedPreferences.getInstance();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Settings keys
  static const String _languageKey = 'app_language';
  static const String _themeKey = 'app_theme';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _locationKey = 'location_enabled';
  static const String _autoPlayKey = 'auto_play_videos';
  static const String _dataUsageKey = 'data_saver_mode';

  // Language settings
  Future<void> setLanguage(String language) async {
    await _prefs.setString(_languageKey, language);
    await _updateUserSetting('language', language);
  }

  Future<String> getLanguage() async {
    return _prefs.getString(_languageKey) ?? 'ar';
  }

  // Theme settings
  Future<void> setTheme(String theme) async {
    await _prefs.setString(_themeKey, theme);
    await _updateUserSetting('theme', theme);
  }

  Future<String> getTheme() async {
    return _prefs.getString(_themeKey) ?? 'light';
  }

  // Notification settings
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsKey, enabled);
    await _updateUserSetting('notificationsEnabled', enabled);
  }

  Future<bool> getNotificationsEnabled() async {
    return _prefs.getBool(_notificationsKey) ?? true;
  }

  // Location settings
  Future<void> setLocationEnabled(bool enabled) async {
    await _prefs.setBool(_locationKey, enabled);
    await _updateUserSetting('locationEnabled', enabled);
  }

  Future<bool> getLocationEnabled() async {
    return _prefs.getBool(_locationKey) ?? true;
  }

  // Auto-play settings
  Future<void> setAutoPlayVideos(bool enabled) async {
    await _prefs.setBool(_autoPlayKey, enabled);
    await _updateUserSetting('autoPlayVideos', enabled);
  }

  Future<bool> getAutoPlayVideos() async {
    return _prefs.getBool(_autoPlayKey) ?? true;
  }

  // Data usage settings
  Future<void> setDataUsageMode(String mode) async {
    await _prefs.setString(_dataUsageKey, mode);
    await _updateUserSetting('dataUsageMode', mode);
  }

  Future<String> getDataUsageMode() async {
    return _prefs.getString(_dataUsageKey) ?? 'standard';
  }

  // Update user setting in Firestore
  Future<void> _updateUserSetting(String key, dynamic value) async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'settings.$key': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get user settings from Firestore
  Future<Map<String, dynamic>> getUserSettings() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return {};

    final data = userDoc.data() as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['settings'] ?? {});
  }

  // Sync settings from Firestore to local
  Future<void> syncSettingsFromFirestore() async {
    final firestoreSettings = await getUserSettings();
    
    // Sync each setting
    await setLanguage(firestoreSettings['language'] ?? await getLanguage());
    await setTheme(firestoreSettings['theme'] ?? await getTheme());
    await setNotificationsEnabled(firestoreSettings['notificationsEnabled'] ?? await getNotificationsEnabled());
    await setLocationEnabled(firestoreSettings['locationEnabled'] ?? await getLocationEnabled());
    await setAutoPlayVideos(firestoreSettings['autoPlayVideos'] ?? await getAutoPlayVideos());
    await setDataUsageMode(firestoreSettings['dataUsageMode'] ?? await getDataUsageMode());
  }

  // Get localized text
  String getLocalizedText(String key, Map<String, String> translations) {
    final language = _prefs.getString(_languageKey) ?? 'ar';
    return translations['$language.$key'] ?? key;
  }

  // Clear all settings
  Future<void> clearAllSettings() async {
    await _prefs.clear();
  }

  // Export settings for backup
  Future<Map<String, dynamic>> exportSettings() async {
    return {
      'language': await getLanguage(),
      'theme': await getTheme(),
      'notificationsEnabled': await getNotificationsEnabled(),
      'locationEnabled': await getLocationEnabled(),
      'autoPlayVideos': await getAutoPlayVideos(),
      'dataUsageMode': await getDataUsageMode(),
    };
  }

  // Import settings from backup
  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings['language'] != null) {
      await setLanguage(settings['language']);
    }
    if (settings['theme'] != null) {
      await setTheme(settings['theme']);
    }
    if (settings['notificationsEnabled'] != null) {
      await setNotificationsEnabled(settings['notificationsEnabled']);
    }
    if (settings['locationEnabled'] != null) {
      await setLocationEnabled(settings['locationEnabled']);
    }
    if (settings['autoPlayVideos'] != null) {
      await setAutoPlayVideos(settings['autoPlayVideos']);
    }
    if (settings['dataUsageMode'] != null) {
      await setDataUsageMode(settings['dataUsageMode']);
    }
  }
}

// Localization class
class AppLocalizations {
  static final Map<String, Map<String, String>> _translations = {
    'ar': {
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'theme': 'المظهر',
      'dark_mode': 'الوضع الليلي',
      'light_mode': 'الوضع النهاري',
      'notifications': 'الإشعارات',
      'privacy': 'الخصوصية',
      'account': 'الحساب',
      'delete_account': 'حذف الحساب',
      'change_password': 'تغيير كلمة المرور',
      'edit_profile': 'تعديل الملف الشخصي',
      'data_usage': 'استخدام البيانات',
      'auto_play': 'التشغيل التلقائي',
      'location': 'الموقع',
      'about': 'حول التطبيق',
      'version': 'الإصدار',
      'logout': 'تسجيل الخروج',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'save': 'حفظ',
      'yes': 'نعم',
      'no': 'لا',
      'ok': 'حسنًا',
      'error': 'خطأ',
      'loading': 'جاري التحميل...',
      'success': 'نجح',
      'profile_updated': 'تم تحديث الملف الشخصي',
      'settings_saved': 'تم حفظ الإعدادات',
      'account_deleted': 'تم حذف الحساب',
    },
    'en': {
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'notifications': 'Notifications',
      'privacy': 'Privacy',
      'account': 'Account',
      'delete_account': 'Delete Account',
      'change_password': 'Change Password',
      'edit_profile': 'Edit Profile',
      'data_usage': 'Data Usage',
      'auto_play': 'Auto Play',
      'location': 'Location',
      'about': 'About',
      'version': 'Version',
      'logout': 'Logout',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',
      'error': 'Error',
      'loading': 'Loading...',
      'success': 'Success',
      'profile_updated': 'Profile Updated',
      'settings_saved': 'Settings Saved',
      'account_deleted': 'Account Deleted',
    },
  };

  static String getText(String key, {String? language}) {
    final lang = language ?? _getLanguage();
    return _translations[lang]?[key] ?? _translations['ar']![key] ?? key;
  }

  static Future<String> _getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_language') ?? 'ar';
  }

  static bool isRTL(String language) {
    return ['ar', 'he', 'fa', 'ur'].contains(language);
  }
}
