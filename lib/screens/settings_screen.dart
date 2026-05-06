import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _selectedLanguage;
  String? _selectedTheme;
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _autoPlayVideos = true;
  String _dataUsageMode = 'standard';
  
  String? _profileImageUrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _selectedLanguage = 'ar'; // Default to Arabic
      _selectedTheme = 'light';
      _notificationsEnabled = true;
      _locationEnabled = true;
      _autoPlayVideos = true;
      _dataUsageMode = 'standard';
    });

    // Load from SharedPreferences
    final language = await _settingsService.getLanguage();
    final theme = await _settingsService.getTheme();
    final notifications = await _settingsService.getNotificationsEnabled();
    final location = await _settingsService.getLocationEnabled();
    final autoPlay = await _settingsService.getAutoPlayVideos();
    final dataUsage = await _settingsService.getDataUsageMode();

    setState(() {
      _selectedLanguage = language;
      _selectedTheme = theme;
      _notificationsEnabled = notifications;
      _locationEnabled = location;
      _autoPlayVideos = autoPlay;
      _dataUsageMode = dataUsage;
    });

    // Sync with Firestore
    await _settingsService.syncSettingsFromFirestore();
  }

  Future<void> _loadUserProfile() async {
    if (_auth.currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _profileImageUrl = data['avatar'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations();
    final isDarkMode = _selectedTheme == 'dark';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations().getText('settings'),
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.grey[900] : const Color(0xFFd4af37),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [const Color(0xFFd4af37), const Color(0xFFf4e5c2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              _buildProfileSection(localizations),
              const SizedBox(height: 24),
              
              // Language Section
              _buildLanguageSection(localizations),
              const SizedBox(height: 24),
              
              // Theme Section
              _buildThemeSection(localizations),
              const SizedBox(height: 24),
              
              // Privacy Section
              _buildPrivacySection(localizations),
              const SizedBox(height: 24),
              
              // Account Management Section
              _buildAccountSection(localizations),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFd4af37),
                  backgroundImage: _profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!)
                      : null,
                  child: _profileImageUrl != null
                      ? null
                      : Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _auth.currentUser?.displayName ?? localizations.getText('account'),
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFd4af37),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _auth.currentUser?.email ?? '',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFFd4af37)),
                  onPressed: _editProfile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection(AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.getText('language'),
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _changeLanguage('ar'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedLanguage == 'ar'
                            ? const Color(0xFFd4af37)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedLanguage == 'ar'
                              ? Colors.transparent
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'العربية',
                            style: GoogleFonts.tajawal(
                              color: _selectedLanguage == 'ar'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedLanguage == 'ar') ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _changeLanguage('en'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedLanguage == 'en'
                            ? const Color(0xFFd4af37)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedLanguage == 'en'
                              ? Colors.transparent
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'English',
                            style: GoogleFonts.tajawal(
                              color: _selectedLanguage == 'en'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedLanguage == 'en') ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.getText('theme'),
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _changeTheme('light'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedTheme == 'light'
                            ? const Color(0xFFd4af37)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedTheme == 'light'
                              ? Colors.transparent
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.light_mode,
                            color: _selectedTheme == 'light'
                                ? Colors.white
                                : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.getText('light_mode'),
                            style: GoogleFonts.tajawal(
                              color: _selectedTheme == 'light'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedTheme == 'light') ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _changeTheme('dark'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedTheme == 'dark'
                            ? const Color(0xFFd4af37)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedTheme == 'dark'
                              ? Colors.transparent
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.dark_mode,
                            color: _selectedTheme == 'dark'
                                ? Colors.white
                                : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            localizations.getText('dark_mode'),
                            style: GoogleFonts.tajawal(
                              color: _selectedTheme == 'dark'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedTheme == 'dark') ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection(AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.getText('privacy'),
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notifications Toggle
            SwitchListTile(
              title: Text(
                        AppLocalizations().getText('notifications'),
                style: GoogleFonts.tajawal(),
              ),
              subtitle: Text(
                        AppLocalizations().getText('notifications'),
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              value: _notificationsEnabled,
              activeColor: const Color(0xFFd4af37),
              onChanged: (value) => _toggleNotifications(value),
            ),
            
            const Divider(),
            
            // Location Toggle
            SwitchListTile(
              title: Text(
                AppLocalizations().getText('notifications'),
                style: GoogleFonts.tajawal(),
              ),
              subtitle: Text(
                'السماح للتطبيق بالوصول إلى موقعك',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              value: _locationEnabled,
              activeColor: const Color(0xFFd4af37),
              onChanged: (value) => _toggleLocation(value),
            ),
            
            const Divider(),
            
            // Auto-play Videos Toggle
            SwitchListTile(
              title: Text(
                localizations.getText('auto_play'),
                style: GoogleFonts.tajawal(),
              ),
              subtitle: Text(
                'تشغيل الفيديوهات تلقائيًا',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              value: _autoPlayVideos,
              activeColor: const Color(0xFFd4af37),
              onChanged: (value) => _toggleAutoPlay(value),
            ),
            
            const Divider(),
            
            // Data Usage Mode
            ListTile(
              title: Text(
                localizations.getText('data_usage'),
                style: GoogleFonts.tajawal(),
              ),
              subtitle: Text(
                'وضع استخدام البيانات',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              trailing: DropdownButton<String>(
                value: _dataUsageMode,
                items: const [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text('عادي'),
                  ),
                  DropdownMenuItem(
                    value: 'saver',
                    child: Text('توفير البيانات'),
                  ),
                ],
                onChanged: (value) => _changeDataUsageMode(value ?? 'standard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.getText('account'),
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            
            // Edit Profile
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFFd4af37)),
              title: Text(
                localizations.getText('edit_profile'),
                style: GoogleFonts.tajawal(),
              ),
              onTap: _editProfile,
            ),
            
            // Change Password
            ListTile(
              leading: const Icon(Icons.lock, color: Color(0xFFd4af37)),
              title: Text(
                localizations.getText('change_password'),
                style: GoogleFonts.tajawal(),
              ),
              onTap: _changePassword,
            ),
            
            // Delete Account
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                localizations.getText('delete_account'),
                style: GoogleFonts.tajawal(
                  color: Colors.red,
                ),
              ),
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeLanguage(String language) async {
    await _settingsService.setLanguage(language);
    setState(() => _selectedLanguage = language);
    _showSuccessSnackBar(localizations.getText('settings_saved'));
  }

  Future<void> _changeTheme(String theme) async {
    await _settingsService.setTheme(theme);
    setState(() => _selectedTheme = theme);
    _showSuccessSnackBar(localizations.getText('settings_saved'));
  }

  Future<void> _toggleNotifications(bool enabled) async {
    await _settingsService.setNotificationsEnabled(enabled);
    setState(() => _notificationsEnabled = enabled);
    _showSuccessSnackBar(localizations.getText('settings_saved'));
  }

  Future<void> _toggleLocation(bool enabled) async {
    await _settingsService.setLocationEnabled(enabled);
    setState(() => _locationEnabled = enabled);
    _showSuccessSnackBar(localizations.getText('settings_saved'));
  }

  Future<void> _toggleAutoPlay(bool enabled) async {
    await _settingsService.setAutoPlayVideos(enabled);
    setState(() => _autoPlayVideos = enabled);
    _showSuccessSnackBar(localizations.getText('settings_saved'));
  }

  Future<void> _changeDataUsageMode(String mode) async {
    await _settingsService.setDataUsageMode(mode);
    setState(() => _dataUsageMode = mode);
    _showSuccessSnackBar(localizations.getText('settings_saved'));
  }

  Future<void> _editProfile() async {
    // Navigate to profile edit screen
    Navigator.pushNamed(context, '/edit_profile');
  }

  Future<void> _changePassword() async {
    // Navigate to change password screen
    Navigator.pushNamed(context, '/change_password');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog(
      title: localizations.getText('delete_account'),
      content: 'هل أنت متأكد من حذف حسابك؟ لا يمكن التراجع عن هذا الإجراء.',
    );

    if (confirmed) {
      try {
        setState(() => _isLoading = true);
        
        await _authService.signOut();
        
        // Delete user data from Firestore
        if (_auth.currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .delete();
        }
        
        // Clear local settings
        await _settingsService.clearAllSettings();
        
        _showSuccessSnackBar(localizations.getText('account_deleted'));
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('حدث خطأ في حذف الحساب');
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.getText('cancel'),
              style: GoogleFonts.tajawal(
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.getText('confirm'),
              style: GoogleFonts.tajawal(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.tajawal(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.tajawal(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
