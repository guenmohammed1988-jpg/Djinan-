import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/merchant_service.dart';

class MerchantOnboardingScreen extends StatefulWidget {
  const MerchantOnboardingScreen({super.key});

  @override
  State<MerchantOnboardingScreen> createState() => _MerchantOnboardingScreenState();
}

class _MerchantOnboardingScreenState extends State<MerchantOnboardingScreen> {
  final MerchantService _merchantService = MerchantService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final PageController _pageController = PageController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _twitterController = TextEditingController();
  
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _generatedUsername;
  String? _selectedLogo;
  bool _isLocationLoading = false;
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  List<String> _selectedCategories = [];
  
  final List<String> _categories = [
    'مطاعم',
    'ملابس',
    'إلكترونيات',
    'أثاث',
    'أدوات منزلية',
    'مستلزمات تجميل',
    'ألعاب',
    'كتب',
    'رياضة',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إعداد المتجر',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFd4af37),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              
              // Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentStep = index);
                  },
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return _buildBasicInfoStep();
                      case 1:
                        return _buildLocationStep();
                      case 2:
                        return _buildBrandingStep();
                      case 3:
                        return _buildDescriptionStep();
                      case 4:
                        return _buildCategoriesStep();
                      case 5:
                        return _buildWorkingHoursStep();
                      default:
                        return _buildReviewStep();
                    }
                  },
                ),
              ),
              
              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'اكتمال الملف الشخصي',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 6,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentStep + 1} من 6',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات المتجر الأساسية',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildTextField(
            controller: _storeNameController,
            label: 'اسم المتجر',
            icon: Icons.store,
            validator: (value) {
              final error = _merchantService.validateStoreName(value ?? '');
              if (error != null) return error;
              
              // Check uniqueness (simulate - in production use Cloud Function)
              if (value!.length > 2) {
                return 'اسم المتجر مستخدم بالفعل';
              }
              return null;
            },
            onChanged: (value) {
              if (value.isNotEmpty) {
                _generateUsername(value);
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: _merchantService.validatePhone,
          ),
          
          if (_generatedUsername != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'اسم المستخدم: $_generatedUsername',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الموقع الجغرافي',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildTextField(
            controller: _locationController,
            label: 'العنوان',
            icon: Icons.location_on,
            validator: _merchantService.validateLocation,
            suffixIcon: _isLocationLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    onPressed: _getCurrentLocation,
                  ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.gps_fixed),
            label: Text(
              'تحديد الموقع الحالي',
              style: GoogleFonts.tajawal(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هوية المتجر',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Logo upload
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                if (_selectedLogo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedLogo!),
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                ElevatedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _selectedLogo != null ? 'تغيير الشعار' : 'رفع الشعار',
                    style: GoogleFonts.tajawal(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Social media links
          _buildTextField(
            controller: _websiteController,
            label: 'الموقع الإلكتروني',
            icon: Icons.language,
            keyboardType: TextInputType.url,
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _instagramController,
            label: 'حساب انستغرام',
            icon: Icons.camera_alt,
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _twitterController,
            label: 'حساب تويتر',
            icon: Icons.alternate_email,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'وصف المتجر',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'وصف المتجر',
              labelStyle: GoogleFonts.tajawal(
                color: Colors.white.withOpacity(0.7),
              ),
              hintText: 'اكتب وصفًا مفصلاً لمتجرك...',
              hintStyle: GoogleFonts.tajawal(
                color: Colors.white.withOpacity(0.5),
              ),
              prefixIcon: const Icon(Icons.description, color: Color(0xFFd4af37)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFd4af37)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: GoogleFonts.tajawal(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فئات المنتجات',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(
                  category,
                  style: GoogleFonts.tajawal(
                    color: isSelected ? const Color(0xFFd4af37) : Colors.white,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
                backgroundColor: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                checkmarkColor: const Color(0xFFd4af37),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ساعات العمل',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Color(0xFFd4af37)),
                    title: Text(
                      'وقت الفتح',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => _selectTime('opening'),
                      child: Text(
                        _openingTime?.format(context) ?? '8:00 ص',
                        style: GoogleFonts.tajawal(),
                      ),
                    ),
                  ),
                  
                  const Divider(),
                  
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Color(0xFFd4af37)),
                    title: Text(
                      'وقت الإغلاق',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => _selectTime('closing'),
                      child: Text(
                        _closingTime?.format(context) ?? '10:00 م',
                        style: GoogleFonts.tajawal(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final completion = _calculateProfileCompletion();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مراجعة المعلومات',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile completion
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اكتمال الملف الشخصي',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: completion / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFd4af37)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${completion.toStringAsFixed(0)}%',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Review information
                  _buildReviewItem('اسم المتجر', _storeNameController.text),
                  _buildReviewItem('رقم الهاتف', _phoneController.text),
                  _buildReviewItem('الموقع', _locationController.text),
                  _buildReviewItem('اسم المستخدم', _generatedUsername ?? 'غير متوفر'),
                  if (_selectedCategories.isNotEmpty)
                    _buildReviewItem('الفئات', _selectedCategories.join(', ')),
                  if (_openingTime != null && _closingTime != null)
                    _buildReviewItem('ساعات العمل', 
                        '${_openingTime!.format(context)} - ${_closingTime!.format(context)}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Warning message
          if (completion < 100)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يجب إكمال الملف الشخصي 100% لتفعيل الحساب',
                      style: GoogleFonts.tajawal(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.tajawal(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String)? validator,
    Widget? suffixIcon,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.tajawal(
          color: Colors.white.withOpacity(0.7),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFd4af37)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFd4af37)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: GoogleFonts.tajawal(
        color: Colors.white,
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          if (_currentStep > 0)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: Text(
                'السابق',
                style: GoogleFonts.tajawal(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
            ),
          
          // Next/Submit button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _nextStep,
            icon: _currentStep < 5 
                ? const Icon(Icons.arrow_forward) 
                : const Icon(Icons.check),
            label: Text(
              _currentStep < 5 ? 'التالي' : 'حفظ',
              style: GoogleFonts.tajawal(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFd4af37),
              minimumSize: const Size(120, 45),
            ),
          ),
        ],
      ),
    );
  }

  void _generateUsername(String storeName) {
    final username = _merchantService.generateUsername(storeName);
    setState(() => _generatedUsername = username);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    
    try {
      final position = await _merchantService.getCurrentLocation();
      if (position != null) {
        final location = '${position.latitude}, ${position.longitude}';
        setState(() {
          _locationController.text = location;
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() => _selectedLogo = image.path);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _selectTime(String type) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: type == 'opening' ? _openingTime : _closingTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light(),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        if (type == 'opening') {
          _openingTime = pickedTime;
        } else {
          _closingTime = pickedTime;
        }
      });
    }
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _nextStep() async {
    if (_currentStep == 5) {
      // Save data
      await _saveMerchantData();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveMerchantData() async {
    // Validate current step
    if (!_validateCurrentStep()) return;

    setState(() => _isLoading = true);

    try {
      final completion = _calculateProfileCompletion();
      
      await _merchantService.saveMerchantData(
        storeName: _storeNameController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        username: _generatedUsername ?? '',
        additionalData: {
          'description': _descriptionController.text.trim(),
          'website': _websiteController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'twitter': _twitterController.text.trim(),
          'logo': _selectedLogo,
          'categories': _selectedCategories,
          'openingTime': _openingTime?.format(context),
          'closingTime': _closingTime?.format(context),
          'profileCompletion': completion,
        },
      );

      await _merchantService.updateProfileCompletion(completion);

      if (completion >= 100.0) {
        // Account is complete, navigate to home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Show completion message
        _showCompletionDialog(completion);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في حفظ البيانات';
        _isLoading = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _storeNameController.text.isNotEmpty &&
               _phoneController.text.isNotEmpty &&
               _generatedUsername != null;
      case 1:
        return _locationController.text.isNotEmpty;
      case 2:
        return _selectedLogo != null;
      case 3:
        return _descriptionController.text.isNotEmpty;
      case 4:
        return _selectedCategories.isNotEmpty;
      case 5:
        return _openingTime != null && _closingTime != null;
      default:
        return false;
    }
  }

  double _calculateProfileCompletion() {
    return _merchantService.calculateCompletion(
      hasStoreName: _storeNameController.text.isNotEmpty,
      hasPhone: _phoneController.text.isNotEmpty,
      hasLocation: _locationController.text.isNotEmpty,
      hasLogo: _selectedLogo != null,
      hasDescription: _descriptionController.text.isNotEmpty,
      hasWorkingHours: _openingTime != null && _closingTime != null,
      hasCategories: _selectedCategories.isNotEmpty,
    );
  }

  void _showCompletionDialog(double completion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حفظ البيانات',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'تم حفظ بيانات المتجر بنجاح!\n\nاكتمال الملف الشخصي: ${completion.toStringAsFixed(0)}%\n\nيجب إكمال الملف الشخصي 100% لتفعيل الحساب.',
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
}
