import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/content_moderation_service.dart';

class ReportContentScreen extends StatefulWidget {
  const ReportContentScreen({super.key});

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final ContentModerationService _moderationService = ContentModerationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  String _reportContentId = '';
  String _reportReason = '';
  String _reportDescription = '';
  List<String> _allContentIds = [];
  List<Map<String, dynamic>> _allContentData = [];

  @override
  void initState() {
    super.initState();
    _loadAllContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الإبلاغ عن المحتوى',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFd4af37),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllContent,
          ),
        ],
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Report Form
                _buildReportForm(),
                
                const SizedBox(height: 24),
                
                // Content List
                _buildContentList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'الإبلاغ عن محتوى',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Content ID Input
            TextField(
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'معرف المحتوى',
                hintStyle: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFd4af37)),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: GoogleFonts.tajawal(
                color: Colors.white,
              ),
              onChanged: (value) => _reportContentId = value,
            ),
            
            const SizedBox(height: 16),
            
            // Reason Selection
            Text(
              'سبب الإبلاغ',
              style: GoogleFonts.tajawal(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            
            // Reason Options
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReasonChip('محتوى صريح', 'explicit_content'),
                _buildReasonChip('عنيف', 'violence'),
                _buildReasonChip('محتوى للبالغين', 'adult_content'),
                _buildReasonChip('انتهاك حقوق الطبع والنشر', 'copyright'),
                _buildReasonChip('خطاب كراه', 'hate_speech'),
                _buildReasonChip('رسائل مزعجة', 'spam'),
                _buildReasonChip('معلومات خاطئة', 'misinformation'),
                _buildReasonChip('محتوى غير لائق', 'inappropriate'),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Description Input
            TextField(
              textAlign: TextAlign.right,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'وصف المشكلة',
                hintStyle: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFd4af37)),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: GoogleFonts.tajawal(
                color: Colors.white,
              ),
              onChanged: (value) => _reportDescription = value,
            ),
            
            const SizedBox(height: 24),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.report, color: Color(0xFFd4af37)),
                label: Text(
                  'إرسال بلاغ',
                  style: GoogleFonts.tajawal(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd4af37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _submitReport,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _reportReason == value,
      onSelected: (bool selected) => setState(() => _reportReason = value),
      backgroundColor: _reportReason == value ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.2),
      labelStyle: GoogleFonts.tajawal(
        color: _reportReason == value ? Colors.white : const Color(0xFFd4af37),
        fontSize: 12,
      ),
    );
  }

  Widget _buildContentList() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'كل المحتوى',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFd4af37),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.search, color: Color(0xFFd4af37)),
                label: Text(
                  'بحث',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFFd4af37),
                  ),
                ),
                onPressed: () => _showSearchDialog(),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Content List
          if (_allContentIds.isEmpty) ...[
            const Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.inbox,
                    color: Color(0xFFd4af37),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد محتوى حالياً',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allContentIds.length,
              itemBuilder: (context, index) {
                final contentId = _allContentIds[index];
                final contentData = _allContentData.firstWhere((item) => item['id'] == contentId);
                
                if (contentData.isEmpty) return const SizedBox.shrink();
                
                return _buildContentItem(contentId, contentData);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentItem(String contentId, Map<String, dynamic> contentData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معرف المحتوى',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contentData['type'] == 'text' ? contentData['text'] ?? 'لا يوجد نص' : 
                           contentData['type'] == 'image' ? 'صورة' : 
                           contentData['type'] == 'video' ? 'فيديو' : 'محتوى',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Content Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معرف المحتوى',
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contentId,
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFFd4af37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contentData['flaggedAt']?.toString().substring(0, 10) ?? 'غير معروف',
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Action Buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flag, color: Color(0xFFd4af37)),
                        label: Text(
                          'إبلاغ',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _showFlagDialog(contentId),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete, color: Color(0xFFd4af37)),
                        label: Text(
                          'حذف',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _showDeleteDialog(contentId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);
    
    try {
      // Get all content from Firestore
      final snapshot = await _moderationService.getFlaggedContent(limit: 100);
      
      setState(() {
        _allContentIds = snapshot.map((item) => item.id).toList();
        _allContentData = snapshot.map((item) => {
            'id': item.id,
            'contentId': item.contentId,
            'userId': item.userId,
            'reason': item.reason,
            'description': item.description,
            'flaggedAt': item.flaggedAt,
            'reviewStatus': item.reviewStatus,
          }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReport() async {
    if (_reportContentId.isEmpty || _reportReason.isEmpty || _reportDescription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الرجاء إدخال معرف المحتوى وسبب الإبلاغ',
            style: GoogleFonts.tajawal(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Find content to report
      final contentToReport = _allContentData.firstWhere(
        (item) => item['id'] == _reportContentId,
      );
      
      if (contentToReport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'المحتوى المحدد غير موجود',
              style: GoogleFonts.tajawal(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Submit report
      await _moderationService.flagContent(
        contentId: _reportContentId,
        reason: _reportReason,
        description: _reportDescription,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
                'تم إرسال البلاغ بنجاح',
                style: GoogleFonts.tajawal(color: Colors.white),
            ),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        _reportContentId = '';
        _reportReason = '';
        _reportDescription = '';
      });
      
      await _loadAllContent();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
                'فشل إرسال البلاغ',
                style: GoogleFonts.tajawal(color: Colors.white),
            ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFlagDialog(String contentId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تأكيد الإبلاغ',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من إبلاغ هذا المحتوى؟',
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'لا',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitFlaggedContent(contentId);
            },
            child: Text(
              'نعم',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(String contentId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حذف المحتوى',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا المحتوى؟ هذا الإجراء لا يمكن التراجع عنه.',
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'لا',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContent(contentId);
            },
            child: Text(
              'نعم',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'البحث عن المحتوى',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'أدخل معرف المحتوى',
            hintStyle: GoogleFonts.tajawal(
              color: Colors.white.withOpacity(0.6),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFd4af37)),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
          ),
          style: GoogleFonts.tajawal(
                color: Colors.white,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Search logic here
              if (controller.text.isNotEmpty) {
                // Filter content list
                final searchResults = _allContentData.where((item) {
                  final contentId = item['id'] as String;
                  final content = item['type'] == 'text' ? item['text'] : 
                                 item['type'] == 'image' ? 'صورة' : 
                                 item['type'] == 'video' ? 'فيديو' : 'محتوى';
                  return contentId.toLowerCase().contains(controller.text.toLowerCase()) || 
                         content.toLowerCase().contains(controller.text.toLowerCase());
                }).toList();
                
                setState(() {
                  _allContentIds = searchResults.map((item) => item['id'] as String).toList();
                  _allContentData = searchResults;
                });
              }
            },
            child: Text(
              'بحث',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContent(String contentId) async {
    setState(() => _isLoading = true);
    
    try {
      // Delete content
      await _moderationService.deleteContent(contentId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
                'تم حذف المحتوى بنجاح',
                style: GoogleFonts.tajawal(color: Colors.white),
            ),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload content list
      await _loadAllContent();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
                'فشل حذف المحتوى',
                style: GoogleFonts.tajawal(color: Colors.white),
            ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitFlaggedContent(String contentId) async {
    setState(() => _isLoading = true);
    
    try {
      // Find content to flag
      final contentToFlag = _allContentData.firstWhere(
        (item) => item['id'] == contentId,
      );
      
      if (contentToFlag.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'المحتوى المحدد غير موجود',
              style: GoogleFonts.tajawal(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Flag content
      await _moderationService.flagContent(
        contentId: contentId,
        reason: 'user_report',
        description: 'تقرير من المستخدم',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
                'تم إرسال بلاغ التقرير',
                style: GoogleFonts.tajawal(color: Colors.white),
            ),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        _reportContentId = '';
        _reportReason = '';
        _reportDescription = '';
      });
      
      await _loadAllContent();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
                'فشل إرسال البلاغ',
                style: GoogleFonts.tajawal(color: Colors.white),
            ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
