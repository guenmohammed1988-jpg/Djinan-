import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppBrandingService {
  static final AppBrandingService _instance = AppBrandingService._internal();
  factory AppBrandingService() => _instance;
  AppBrandingService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final SharedPreferences _prefs = SharedPreferences.getInstance();
  
  static const String _brandingKey = 'app_branding';
  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';
  static const String _customColorsKey = 'custom_colors';

  // App branding configuration
  AppBrandingConfig _config = AppBrandingConfig(
    appName: 'Dhinan',
    appVersion: '1.0.0',
    defaultLanguage: 'ar',
    supportedLanguages: ['ar', 'en'],
    defaultTheme: 'light',
    customColors: {
      'primary': '#d4af37',
      'secondary': '#f4e5c2',
      'accent': '#2c3e50',
      'background': '#ffffff',
      'text': '#000000',
      'success': '#4caf50',
      'warning': '#ff9800',
      'error': '#f44336',
    },
    fonts: {
      'arabic': 'Tajawal',
      'english': 'Roboto',
    },
    logo: {
      'light': 'assets/images/logo_light.png',
      'dark': 'assets/images/logo_dark.png',
    },
    splash: {
      'background': '#d4af37',
      'logo': 'assets/images/splash_logo.png',
      'duration': 3000, // 3 seconds
    },
  );

  // Initialize branding service
  Future<void> initialize() async {
    try {
      // Load saved branding preferences
      final savedBranding = await _getSavedBranding();
      
      // Apply saved branding or use defaults
      _config = savedBranding ?? _config;
      
      print('App branding initialized');
    } catch (e) {
      print('Error initializing app branding: $e');
    }
  }

  // Get current branding configuration
  AppBrandingConfig get currentConfig => _config;

  // Save branding preferences
  Future<void> saveBranding({
    AppBrandingConfig? branding,
    String? language,
    String? theme,
    Map<String, String>? customColors,
  }) async {
    try {
      final config = branding ?? _config;
      
      // Save to secure storage
      await _secureStorage.write(
        key: _brandingKey,
        value: jsonEncode({
          'appName': config.appName,
          'appVersion': config.appVersion,
          'language': language ?? config.defaultLanguage,
          'theme': theme ?? config.defaultTheme,
          'customColors': customColors ?? config.customColors,
        }),
      );
      
      // Save to shared preferences for quick access
      await _prefs.setString(_languageKey, language ?? config.defaultLanguage);
      await _prefs.setString(_themeKey, theme ?? config.defaultTheme);
      await _prefs.setString(_customColorsKey, jsonEncode(customColors ?? config.customColors));
      
      // Update current config
      _config = AppBrandingConfig(
        appName: config.appName,
        appVersion: config.appVersion,
        defaultLanguage: language ?? config.defaultLanguage,
        supportedLanguages: config.supportedLanguages,
        defaultTheme: theme ?? config.defaultTheme,
        customColors: customColors ?? config.customColors,
        fonts: config.fonts,
        logo: config.logo,
        splash: config.splash,
      );

      print('Branding preferences saved');
    } catch (e) {
      print('Error saving branding preferences: $e');
    }
  }

  // Get saved branding
  Future<AppBrandingConfig?> _getSavedBranding() async {
    try {
      final brandingString = await _secureStorage.read(key: _brandingKey);
      
      if (brandingString != null) {
        final brandingData = jsonDecode(brandingString);
        
        return AppBrandingConfig(
          appName: brandingData['appName'] ?? _config.appName,
          appVersion: brandingData['appVersion'] ?? _config.appVersion,
          defaultLanguage: brandingData['language'] ?? _config.defaultLanguage,
          supportedLanguages: List<String>.from(brandingData['supportedLanguages'] ?? [_config.defaultLanguage]),
          defaultTheme: brandingData['theme'] ?? _config.defaultTheme,
          customColors: Map<String, String>.from(brandingData['customColors'] ?? _config.customColors),
          fonts: Map<String, String>.from(brandingData['fonts'] ?? _config.fonts),
          logo: Map<String, String>.from(brandingData['logo'] ?? _config.logo),
          splash: Map<String, String>.from(brandingData['splash'] ?? _config.splash),
        );
      }
      
      return null;
    } catch (e) {
      print('Error getting saved branding: $e');
      return null;
    }
  }

  // Get current language
  String getCurrentLanguage() {
    return _config.defaultLanguage;
  }

  // Get current theme
  String getCurrentTheme() {
    return _config.defaultTheme;
  }

  // Get custom colors
  Map<String, String> getCustomColors() {
    return _config.customColors;
  }

  // Get primary color
  Color getPrimaryColor() {
    try {
      final primaryColor = _config.customColors['primary'];
      if (primaryColor != null) {
        return Color(int.parse(primaryColor.replace('#', '0xff')));
      }
      return const Color(0xFFd4af37);
    } catch (e) {
      return const Color(0xFFd4af37);
    }
  }

  // Get secondary color
  Color getSecondaryColor() {
    try {
      final secondaryColor = _config.customColors['secondary'];
      if (secondaryColor != null) {
        return Color(int.parse(secondaryColor.replace('#', '0xff')));
      }
      return const Color(0xFFf4e5c2);
    } catch (e) {
      return const Color(0xFFf4e5c2);
    }
  }

  // Get accent color
  Color getAccentColor() {
    try {
      final accentColor = _config.customColors['accent'];
      if (accentColor != null) {
        return Color(int.parse(accentColor.replace('#', '0xff')));
      }
      return const Color(0xFF2c3e50);
    } catch (e) {
      return const Color(0xFF2c3e50);
    }
  }

  // Get background color
  Color getBackgroundColor() {
    try {
      final backgroundColor = _config.customColors['background'];
      if (backgroundColor != null) {
        return Color(int.parse(backgroundColor.replace('#', '0xff')));
      }
      return const Color(0xFFffffff);
    } catch (e) {
      return const Color(0xFFffffff);
    }
  }

  // Get text color
  Color getTextColor() {
    try {
      final textColor = _config.customColors['text'];
      if (textColor != null) {
        return Color(int.parse(textColor.replace('#', '0xff')));
      }
      return const Color(0xFF000000);
    } catch (e) {
      return const Color(0xFF000000);
    }
  }

  // Get success color
  Color getSuccessColor() {
    try {
      final successColor = _config.customColors['success'];
      if (successColor != null) {
        return Color(int.parse(successColor.replace('#', '0xff')));
      }
      return const Color(0xFF4caf50);
    } catch (e) {
      return const Color(0xFF4caf50);
    }
  }

  // Get warning color
  Color getWarningColor() {
    try {
      final warningColor = _config.customColors['warning'];
      if (warningColor != null) {
        return Color(int.parse(warningColor.replace('#', '0xff')));
      }
      return const Color(0xFFff9800);
    } catch (e) {
      return const Color(0xFFff9800);
    }
  }

  // Get error color
  Color getErrorColor() {
    try {
      final errorColor = _config.customColors['error'];
      if (errorColor != null) {
        return Color(int.parse(errorColor.replace('#', '0xff')));
      }
      return const Color(0xFFf44336);
    } catch (e) {
      return const Color(0xFFf44336);
    }
  }

  // Get font family
  String getFontFamily() {
    final language = getCurrentLanguage();
    return _config.fonts[language] ?? _config.fonts['arabic'] ?? 'Tajawal';
  }

  // Get logo path
  String getLogoPath() {
    final theme = getCurrentTheme();
    return _config.logo[theme] ?? _config.logo['light'];
  }

  // Get splash configuration
  Map<String, String> getSplashConfig() {
    return _config.splash;
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    try {
      await _secureStorage.delete(key: _brandingKey);
      await _prefs.remove(_languageKey);
      await _prefs.remove(_themeKey);
      await _prefs.remove(_customColorsKey);
      
      _config = _config;
      
      print('Branding reset to defaults');
    } catch (e) {
      print('Error resetting branding to defaults: $e');
    }
  }

  // Apply branding to user profile
  Future<void> applyBrandingToUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'branding': {
            'primaryColor': getPrimaryColor().value,
            'secondaryColor': getSecondaryColor().value,
            'accentColor': getAccentColor().value,
            'backgroundColor': getBackgroundColor().value,
            'textColor': getTextColor().value,
            'fontFamily': getFontFamily(),
            'logo': getLogoPath(),
            'theme': getCurrentTheme(),
            'language': getCurrentLanguage(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error applying branding to user: $e');
    }
  }
}

// App branding configuration model
class AppBrandingConfig {
  final String appName;
  final String appVersion;
  final String defaultLanguage;
  final List<String> supportedLanguages;
  final String defaultTheme;
  final Map<String, String> customColors;
  final Map<String, String> fonts;
  final Map<String, String> logo;
  final Map<String, String> splash;

  AppBrandingConfig({
    required this.appName,
    required this.appVersion,
    required this.defaultLanguage,
    required this.supportedLanguages,
    required this.defaultTheme,
    required this.customColors,
    required this.fonts,
    required this.logo,
    required this.splash,
  });
}
