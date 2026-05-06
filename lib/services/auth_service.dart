import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Rate limiting
  final Map<String, List<DateTime>> _loginAttempts = {};
  final Map<String, List<DateTime>> _otpAttempts = {};
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const Duration rateLimitWindow = Duration(minutes: 5);

  // Stream for authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is email verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Input validation
  String? validateEmail(String email) {
    if (email.isEmpty) return 'البريد الإلكتروني مطلوب';
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'البريد الإلكتروني غير صالح';
    
    return null;
  }

  String? validatePhone(String phone) {
    if (phone.isEmpty) return 'رقم الهاتف مطلوب';
    
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid phone number (10-15 digits)
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'رقم الهاتف يجب أن يكون بين 10 و 15 رقمًا';
    }
    
    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) return 'كلمة المرور مطلوبة';
    
    if (password.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل';
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'كلمة المرور يجب أن تحتوي على حرف صغير واحد على الأقل';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل';
    }
    
    return null;
  }

  String? validateName(String name) {
    if (name.isEmpty) return 'الاسم مطلوب';
    
    if (name.length < 3) {
      return 'الاسم يجب أن يكون 3 أحرف على الأقل';
    }
    
    if (name.length > 50) {
      return 'الاسم يجب أن يكون أقل من 50 حرفًا';
    }
    
    return null;
  }

  // Rate limiting check
  bool _isRateLimited(String identifier, Map<String, List<DateTime>> attempts) {
    final now = DateTime.now();
    final userAttempts = attempts[identifier] ?? [];
    
    // Remove old attempts outside the rate limit window
    userAttempts.removeWhere((attempt) => 
        now.difference(attempt) > rateLimitWindow);
    
    attempts[identifier] = userAttempts;
    
    // Check if user exceeded max attempts
    if (userAttempts.length >= maxAttempts) {
      final lastAttempt = userAttempts.last;
      if (now.difference(lastAttempt) < lockoutDuration) {
        return true;
      }
    }
    
    return false;
  }

  void _recordAttempt(String identifier, Map<String, List<DateTime>> attempts) {
    final now = DateTime.now();
    final userAttempts = attempts[identifier] ?? [];
    userAttempts.add(now);
    attempts[identifier] = userAttempts;
  }

  Duration _getRemainingLockoutTime(String identifier, Map<String, List<DateTime>> attempts) {
    final now = DateTime.now();
    final userAttempts = attempts[identifier] ?? [];
    
    if (userAttempts.isEmpty) return Duration.zero;
    
    final lastAttempt = userAttempts.last;
    final timeSinceLastAttempt = now.difference(lastAttempt);
    final remainingTime = lockoutDuration - timeSinceLastAttempt;
    
    return remainingTime.isNegative ? Duration.zero : remainingTime;
  }

  // Email/Password Registration
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      // Validate inputs
      final emailError = validateEmail(email);
      if (emailError != null) {
        return AuthResult.error(emailError);
      }

      final passwordError = validatePassword(password);
      if (passwordError != null) {
        return AuthResult.error(passwordError);
      }

      final nameError = validateName(name);
      if (nameError != null) {
        return AuthResult.error(nameError);
      }

      final phoneError = validatePhone(phone);
      if (phoneError != null) {
        return AuthResult.error(phoneError);
      }

      // Check rate limiting
      if (_isRateLimited(email, _loginAttempts)) {
        final remainingTime = _getRemainingLockoutTime(email, _loginAttempts);
        return AuthResult.error(
          'تم حظر تسجيل الدخول مؤقتًا. حاول مرة أخرى بعد ${remainingTime.inMinutes} دقيقة'
        );
      }

      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Store user data in Firestore
      await _storeUserData(
        userId: userCredential.user!.uid,
        email: email,
        name: name,
        phone: phone,
        authMethod: 'email',
      );

      return AuthResult.success(
        user: userCredential.user!,
        requiresEmailVerification: true,
      );
    } on FirebaseAuthException catch (e) {
      _recordAttempt(email, _loginAttempts);
      
      String errorMessage = _getFirebaseErrorMessage(e);
      return AuthResult.error(errorMessage);
    } catch (e) {
      return AuthResult.error('حدث خطأ غير متوقع. حاول مرة أخرى');
    }
  }

  // Email/Password Login
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Validate inputs
      final emailError = validateEmail(email);
      if (emailError != null) {
        return AuthResult.error(emailError);
      }

      // Check rate limiting
      if (_isRateLimited(email, _loginAttempts)) {
        final remainingTime = _getRemainingLockoutTime(email, _loginAttempts);
        return AuthResult.error(
          'تم حظر تسجيل الدخول مؤقتًا. حاول مرة أخرى بعد ${remainingTime.inMinutes} دقيقة'
        );
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        return AuthResult.error(
          'يجب تأكيد البريد الإلكتروني قبل تسجيل الدخول',
          requiresEmailVerification: true,
        );
      }

      // Update last login
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'loginCount': FieldValue.increment(1),
      });

      return AuthResult.success(user: userCredential.user!);
    } on FirebaseAuthException catch (e) {
      _recordAttempt(email, _loginAttempts);
      
      String errorMessage = _getFirebaseErrorMessage(e);
      return AuthResult.error(errorMessage);
    } catch (e) {
      return AuthResult.error('حدث خطأ غير متوقع. حاول مرة أخرى');
    }
  }

  // Phone Authentication
  Future<AuthResult> signInWithPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
  }) async {
    try {
      // Validate phone number
      final phoneError = validatePhone(phoneNumber);
      if (phoneError != null) {
        return AuthResult.error(phoneError);
      }

      // Check rate limiting
      if (_isRateLimited(phoneNumber, _otpAttempts)) {
        final remainingTime = _getRemainingLockoutTime(phoneNumber, _otpAttempts);
        return AuthResult.error(
          'تم حظر إرسال الرمز مؤقتًا. حاول مرة أخرى بعد ${remainingTime.inMinutes} دقيقة'
        );
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            await _updateUserAfterPhoneAuth(userCredential.user!, phoneNumber);
          } catch (e) {
            // Handle auto-verification error
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _recordAttempt(phoneNumber, _otpAttempts);
          onCodeSent(_getFirebaseErrorMessage(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle timeout
        },
      );

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      _recordAttempt(phoneNumber, _otpAttempts);
      return AuthResult.error(_getFirebaseErrorMessage(e));
    } catch (e) {
      return AuthResult.error('حدث خطأ في إرسال رمز التحقق');
    }
  }

  // Verify OTP and complete phone sign in
  Future<AuthResult> verifyOTPAndSignIn({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
    String? name,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      
      if (!userDoc.exists) {
        // New user - require name
        if (name == null || name.isEmpty) {
          return AuthResult.error('الاسم مطلوب للمستخدمين الجدد');
        }

        final nameError = validateName(name);
        if (nameError != null) {
          return AuthResult.error(nameError);
        }

        await _storeUserData(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email,
          name: name,
          phone: phoneNumber,
          authMethod: 'phone',
        );
      } else {
        // Existing user - update last login
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
      }

      return AuthResult.success(user: userCredential.user!);
    } on FirebaseAuthException catch (e) {
      _recordAttempt(phoneNumber, _otpAttempts);
      return AuthResult.error(_getFirebaseErrorMessage(e));
    } catch (e) {
      return AuthResult.error('رمز التحقق غير صالح');
    }
  }

  // Google Sign-In
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('تم إلغاء تسجيل الدخول');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      
      if (!userDoc.exists) {
        await _storeUserData(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          name: userCredential.user!.displayName ?? 'مستخدم جوجل',
          phone: userCredential.user!.phoneNumber ?? '',
          authMethod: 'google',
          avatar: userCredential.user!.photoURL,
        );
      } else {
        // Existing user - update last login
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
      }

      return AuthResult.success(user: userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e));
    } catch (e) {
      return AuthResult.error('حدث خطأ في تسجيل الدخول بحساب جوجل');
    }
  }

  // Apple Sign-In
  Future<AuthResult> signInWithApple() async {
    try {
      if (!Platform.isIOS && !kIsWeb) {
        return AuthResult.error('تسجيل الدخول بحساب Apple متاح فقط على أجهزة iOS');
      }

      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Extract name from Apple credential (only provided on first sign-in)
      String name = credential.givenName != null && credential.familyName != null
          ? '${credential.givenName} ${credential.familyName}'
          : 'مستخدم Apple';

      // Check if this is a new user
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      
      if (!userDoc.exists) {
        await _storeUserData(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          name: name,
          phone: userCredential.user!.phoneNumber ?? '',
          authMethod: 'apple',
        );
      } else {
        // Existing user - update last login
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
      }

      return AuthResult.success(user: userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e));
    } catch (e) {
      return AuthResult.error('حدث خطأ في تسجيل الدخول بحساب Apple');
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw Exception('حدث خطأ في إرسال رسالة التحقق');
    }
  }

  // Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      final emailError = validateEmail(email);
      if (emailError != null) {
        return AuthResult.error(emailError);
      }

      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e));
    } catch (e) {
      return AuthResult.error('حدث خطأ في إرسال رابط إعادة تعيين كلمة المرور');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('حدث خطأ في تسجيل الخروج');
    }
  }

  // Store user data in Firestore
  Future<void> _storeUserData({
    required String userId,
    String? email,
    required String name,
    required String phone,
    required String authMethod,
    String? avatar,
  }) async {
    final userData = {
      'userId': userId,
      'email': email,
      'name': name,
      'phone': phone,
      'authMethod': authMethod,
      'avatar': avatar,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'loginCount': 1,
      'isEmailVerified': email != null ? false : null, // Only track for email users
      'isActive': true,
      'preferences': {
        'notifications': true,
        'theme': 'light',
        'language': 'ar',
      },
    };

    await _firestore.collection('users').doc(userId).set(userData);
  }

  // Update user after phone authentication
  Future<void> _updateUserAfterPhoneAuth(User user, String phoneNumber) async {
    await _firestore.collection('users').doc(user.uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'loginCount': FieldValue.increment(1),
      'phone': phoneNumber,
    });
  }

  // Generate nonce for Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (_) => charset[(random + _) % charset.length])
        .join();
  }

  // Get user-friendly error messages
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'كلمة المرور ضعيفة جدًا';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'user-not-found':
        return 'المستخدم غير موجود';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'تم تعطيل حساب المستخدم';
      case 'too-many-requests':
        return 'محاولات كثيرة جدًا. حاول مرة أخرى لاحقًا';
      case 'operation-not-allowed':
        return 'هذه العملية غير مسموح بها';
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صالح';
      case 'quota-exceeded':
        return 'تم تجاوز الحصة المسموح بها. حاول مرة أخرى لاحقًا';
      case 'session-expired':
        return 'انتهت الجلسة. حاول مرة أخرى';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صالح';
      case 'invalid-verification-id':
        return 'معرف التحقق غير صالح';
      default:
        return 'حدث خطأ: ${e.message}';
    }
  }
}

// Auth result class
class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;
  final bool requiresEmailVerification;

  AuthResult.success({
    this.user,
    this.requiresEmailVerification = false,
  }) : success = true, errorMessage = null;

  AuthResult.error(this.errorMessage, {this.requiresEmailVerification = false})
      : success = false, user = null;

  @override
  String toString() {
    if (success) {
      return 'AuthResult.success(user: ${user?.uid})';
    } else {
      return 'AuthResult.error(errorMessage: $errorMessage)';
    }
  }
}
