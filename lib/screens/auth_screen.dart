import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  
  String _authMethod = 'email'; // email, phone, google, apple
  String? _verificationId;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFd4af37),
              const Color(0xFFf4e5c2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildLogo(),
                const SizedBox(height: 30),
                _buildAuthMethodSelector(),
                const SizedBox(height: 20),
                _buildAuthForm(),
                const SizedBox(height: 20),
                if (_errorMessage != null) _buildErrorMessage(),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 20),
                _buildSocialButtons(),
                const SizedBox(height: 20),
                _buildToggleAuth(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_circle,
            size: 40,
            color: Color(0xFFd4af37),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'DJINAN',
          style: GoogleFonts.tajawal(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          _isLogin ? 'مرحباً بعودتك' : 'إنشاء حساب جديد',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthMethodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _authMethod = 'email'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _authMethod == 'email' 
                      ? Colors.white 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'البريد',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    color: _authMethod == 'email' 
                        ? const Color(0xFFd4af37) 
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _authMethod = 'phone'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _authMethod == 'phone' 
                      ? Colors.white 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'الهاتف',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    color: _authMethod == 'phone' 
                        ? const Color(0xFFd4af37) 
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    switch (_authMethod) {
      case 'email':
        return _buildEmailForm();
      case 'phone':
        return _buildPhoneForm();
      default:
        return _buildEmailForm();
    }
  }

  Widget _buildEmailForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!_isLogin) ...[
            _buildTextField(
              controller: _nameController,
              label: 'الاسم الكامل',
              icon: Icons.person,
              validator: _authService.validateName,
            ),
            const SizedBox(height: 16),
          ],
          _buildTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: _authService.validateEmail,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            label: 'كلمة المرور',
            icon: Icons.lock,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[600],
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: _authService.validatePassword,
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'رقم الهاتف',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: _authService.validatePhone,
            ),
          ],
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildTermsCheckbox(),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    if (_verificationId == null) {
      // Phone number input
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTextField(
              controller: _phoneController,
              label: 'رقم الهاتف',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: _authService.validatePhone,
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'الاسم الكامل',
                icon: Icons.person,
                validator: _authService.validateName,
              ),
              const SizedBox(height: 16),
              _buildTermsCheckbox(),
            ],
          ],
        ),
      );
    } else {
      // OTP input
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'أدخل رمز التحقق',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تم إرسال رمز التحقق إلى ${_phoneController.text}',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _otpController,
              label: 'رمز التحقق',
              icon: Icons.security,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String)? validator,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.tajawal(
          color: Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFd4af37)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFd4af37)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: GoogleFonts.tajawal(),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) => setState(() => _acceptTerms = value ?? false),
          activeColor: const Color(0xFFd4af37),
        ),
        Expanded(
          child: Text(
            'أوافق على الشروط والأحكام وسياسة الخصوصية',
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.tajawal(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_verificationId != null) {
      // OTP verification buttons
      return Column(
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFd4af37),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    'تحقق',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resendOTP,
            child: Text(
              'إعادة إرسال الرمز',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAuth,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd4af37),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
        if (_isLogin && _authMethod == 'email') ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _forgotPassword,
            child: Text(
              'نسيت كلمة المرور؟',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'أو',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_translate, size: 20),
                label: Text(
                  'Google',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithApple,
                icon: const Icon(Icons.apple, size: 20),
                label: Text(
                  'Apple',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleAuth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟',
          style: GoogleFonts.tajawal(
            color: Colors.white,
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _isLogin = !_isLogin;
            _errorMessage = null;
            _clearControllers();
          }),
          child: Text(
            _isLogin ? 'إنشاء حساب' : 'تسجيل الدخول',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  void _clearControllers() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _phoneController.clear();
    _otpController.clear();
    _verificationId = null;
  }

  Future<void> _handleAuth() async {
    if (!_isLogin && !_acceptTerms) {
      setState(() => _errorMessage = 'يجب الموافقة على الشروط والأحكام');
      return;
    }

    setState(() => _isLoading = true);
    setState(() => _errorMessage = null);

    try {
      AuthResult result;

      if (_authMethod == 'email') {
        if (_isLogin) {
          result = await _authService.signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        } else {
          result = await _authService.registerWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
        }
      } else {
        // Phone authentication
        result = await _authService.signInWithPhone(
          phoneNumber: _phoneController.text.trim(),
          onCodeSent: (verificationId) {
            setState(() {
              _verificationId = verificationId;
              _isLoading = false;
            });
          },
        );
      }

      if (result.success) {
        if (result.requiresEmailVerification) {
          setState(() => _isLoading = false);
          _showEmailVerificationDialog();
        } else {
          _navigateToHome();
        }
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    setState(() => _isLoading = true);
    setState(() => _errorMessage = null);

    try {
      final result = await _authService.verifyOTPAndSignIn(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (result.success) {
        _navigateToHome();
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في التحقق من الرمز';
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);
    setState(() => _errorMessage = null);

    try {
      final result = await _authService.signInWithPhone(
        phoneNumber: _phoneController.text.trim(),
        onCodeSent: (verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
      );

      if (!result.success) {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في إعادة إرسال الرمز';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    setState(() => _errorMessage = null);

    try {
      final result = await _authService.signInWithGoogle();

      if (result.success) {
        _navigateToHome();
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في تسجيل الدخول بحساب جوجل';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    setState(() => _errorMessage = null);

    try {
      final result = await _authService.signInWithApple();

      if (result.success) {
        _navigateToHome();
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في تسجيل الدخول بحساب Apple';
        _isLoading = false;
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال البريد الإلكتروني');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.resetPassword(email);

      if (result.success) {
        _showPasswordResetDialog();
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في إرسال رابط إعادة تعيين كلمة المرور';
        _isLoading = false;
      });
    }
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تأكيد البريد الإلكتروني',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'تم إرسال رسالة تأكيد إلى بريدك الإلكتروني. يرجى فتح الرابط وتأكيد بريدك الإلكتروني قبل تسجيل الدخول.',
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'حسنًا',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إعادة تعيين كلمة المرور',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.',
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLoading = false);
            },
            child: Text(
              'حسنًا',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
