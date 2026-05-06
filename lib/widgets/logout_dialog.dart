import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/logout_service.dart';

class LogoutDialog extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onCancel;

  const LogoutDialog({
    super.key,
    required this.onLogout,
    required this.onCancel,
  });

  @override
  State<LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<LogoutDialog> {
  bool _isClearingData = false;
  bool _clearCacheOption = true;
  final LogoutService _logoutService = LogoutService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFd4af37),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تسجيل الخروج',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Content
            Text(
              'هل أنت متأكد من تسجيل الخروج؟',
              style: GoogleFonts.tajawal(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Data clearing options
            if (_isClearingData)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFd4af37)),
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'جاري تسجيل الخروج ومسح البيانات...',
                      style: GoogleFonts.tajawal(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Cache clearing option
            if (!_isClearingData)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cleaning_services,
                      color: const Color(0xFFd4af37),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مسح البيانات المؤقتة عند الخروج',
                        style: GoogleFonts.tajawal(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Switch(
                      value: _clearCacheOption,
                      onChanged: (value) => setState(() => _clearCacheOption = value),
                      activeColor: const Color(0xFFd4af37),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.tajawal(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isClearingData ? null : () async {
                      setState(() => _isClearingData = true);
                      
                      try {
                        // Perform logout with data clearing
                        final result = await _logoutService.performLogout(
                          clearAllData: true,
                          clearCache: _clearCacheOption,
                        );
                        
                        if (mounted) {
                          setState(() => _isClearingData = false);
                          Navigator.of(context).pop();
                          
                          if (result.success) {
                            widget.onLogout();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تم تسجيل الخروج بنجاح',
                                  style: GoogleFonts.tajawal(),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.errorMessage ?? 'حدث خطأ غير متوقع',
                                  style: GoogleFonts.tajawal(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        setState(() => _isClearingData = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'حدث خطأ أثناء تسجيل الخروج',
                              style: GoogleFonts.tajawal(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isClearingData ? Colors.grey[300] : const Color(0xFFd4af37),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isClearingData
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'جاري المسح...',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'تسجيل الخروج',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
}
