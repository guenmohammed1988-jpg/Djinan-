# Dhinan Flutter App

تطبيق Flutter مع شاشة splash والتحقق من حالة المصادقة Firebase.

## المميزات

- شاشة Splash بخلفية لون fffdf0
- عرض شعار التطبيق ونص "Djinan" بخط Tajawal Bold
- مدة عرض 3 ثواني
- التحقق من حالة المستخدم باستخدام Firebase Auth
- الانتقال التلقائي للصفحة الرئيسية أو صفحة تسجيل الدخول

## الاعتماديات

- Flutter SDK
- Firebase Auth
- Google Fonts (Tajawal)

## التثبيت

1. قم بتثبيت Flutter SDK
2. قم بإعداد مشروع Firebase
3. أضف ملف `google-services.json` (Android) و `GoogleService-Info.plist` (iOS)
4. قم بتشغيل `flutter pub get`
5. قم بتشغيل `flutter run`

## هيكل المشروع

```
lib/
├── main.dart
└── screens/
    ├── splash_screen.dart
    ├── home_screen.dart
    └── login_screen.dart
```
