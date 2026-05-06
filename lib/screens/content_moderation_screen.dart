import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/content_moderation_service.dart';

class ContentModerationScreen extends StatefulWidget {
  const ContentModerationScreen({super.key});

  @override
  State<ContentModerationScreen> createState() => _ContentModerationScreenState();
}

class _ContentModerationScreenState extends State<ContentModerationScreen> {
  final ContentModerationService _moderationService = ContentModerationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<FlaggedContent> _flaggedContent = [];
  List<ModerationQueueItem> _queueItems = [];
  ModerationStats? _stats;
  bool _isLoading = false;
  bool _showFlagged = true;
  bool _showQueue = false;
  bool _showStats = false;
  String _reportContentId = '';
  String _reportReason = '';
  String _reportDescription = '';

  @override
  void initState() {
    super.initState();
    _loadModerationData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إدارة المحتوى',
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
            onPressed: _refreshAll,
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
                // Statistics Cards
                _buildStatisticsCards(),
                
                const SizedBox(height: 24),
                
                // Tab Navigation
                _buildTabNavigation(),
                
                const SizedBox(height: 24),
                
                // Content Sections
                if (_showFlagged) _buildFlaggedContentSection(),
                if (_showQueue) _buildModerationQueueSection(),
                if (_showStats) _buildStatisticsSection(),
                
                const SizedBox(height: 24),
                
                // Report Content Section
                _buildReportContentSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.flag,
                    color: Color(0xFFd4af37),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'المحتوى المحدد',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _stats?.totalFlagged.toString() ?? '0',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'عنصر',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.queue,
                    color: Color(0xFFd4af37),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'طابور الانتظار',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _stats?.queueSize.toString() ?? '0',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'عنصر',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.flag, color: Color(0xFFd4af37)),
              label: Text(
                'المحتوى المحدد',
                style: GoogleFonts.tajawal(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showFlagged ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.2),
                foregroundColor: _showFlagged ? Colors.white : const Color(0xFFd4af37),
              ),
              onPressed: () => setState(() {
                _showFlagged = true;
                _showQueue = false;
                _showStats = false;
              }),
            ),
          ),
        
          const SizedBox(width: 8),
          
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.queue, color: Color(0xFFd4af37)),
              label: Text(
                'طابور الانتظار',
                style: GoogleFonts.tajawal(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showQueue ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.2),
                foregroundColor: _showQueue ? Colors.white : const Color(0xFFd4af37),
              ),
              onPressed: () => setState(() {
                _showFlagged = false;
                _showQueue = true;
                _showStats = false;
              }),
            ),
          ),
        
          const SizedBox(width: 8),
          
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.analytics, color: Color(0xFFd4af37)),
              label: Text(
                'الإحصائيات',
                style: GoogleFonts.tajawal(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showStats ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.2),
                foregroundColor: _showStats ? Colors.white : const Color(0xFFd4af37),
              ),
              onPressed: () => setState(() {
                _showFlagged = false;
                _showQueue = false;
                _showStats = true;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedContentSection() {
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
                'المحتوى المحدد',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFd4af37),
                ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, color: Color(0xFFd4af37)),
                label: Text(
                  'تحديث',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFFd4af37),
                  ),
                ),
                onPressed: _loadFlaggedContent,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Flagged Content List
          if (_flaggedContent.isEmpty) ...[
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
                    'لا يوجد محتوى محدد حالياً',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                ],
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _flaggedContent.length,
              itemBuilder: (context, index) {
                final flaggedItem = _flaggedContent[index];
                return _buildFlaggedContentCard(flaggedItem);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlaggedContentCard(FlaggedContent flaggedItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getFlagColor(flaggedItem.reason),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getFlagIcon(flaggedItem.reason),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flaggedItem.reasonText,
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFFd4af37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flaggedItem.flaggedAt.toString().substring(0, 10),
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
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
                      color: const Color(0xFFd4af37),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    flaggedItem.description.isNotEmpty 
                        ? flaggedItem.description
                        : 'لا يوجد وصف',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, color: Color(0xFFd4af37)),
                    label: Text(
                      'موافقة',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _reviewFlaggedContent(flaggedItem.id, 'approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: Text(
                      'رفض',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _reviewFlaggedContent(flaggedItem.id, 'reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.orange),
                    label: Text(
                      'حذف',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _deleteFlaggedContent(flaggedItem.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationQueueSection() {
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
                'طابور الانتظار',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFd4af37),
                ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, color: Color(0xFFd4af37)),
                label: Text(
                  'تحديث',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFFd4af37),
                  ),
                ),
                onPressed: _loadModerationQueue,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Queue Items
          if (_queueItems.isEmpty) ...[
            const Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    color: Color(0xFFd4af37),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد عناصر في الطابور',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                ],
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _queueItems.length,
              itemBuilder: (context, index) {
                final queueItem = _queueItems[index];
                return _buildQueueItemCard(queueItem);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueItemCard(ModerationQueueItem queueItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getQueueActionColor(queueItem.action),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getQueueActionIcon(queueItem.action),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        queueItem.actionText,
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFFd4af37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        queueItem.queuedAt.toString().substring(0, 10),
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
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
                      color: const Color(0xFFd4af37),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    queueItem.description.isNotEmpty 
                        ? queueItem.description
                        : 'لا يوجد وصف',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, color: Color(0xFFd4af37)),
                    label: Text(
                      'معالجة',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _processQueueItem(queueItem.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.skip_next, color: Colors.orange),
                    label: Text(
                      'تخطي',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _skipQueueItem(queueItem.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_stats == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'إحصائيات التعديل',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            
            const SizedBox(height: 16),
            
            // Statistics Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              children: [
                _buildStatCard(
                  'إجمالي المحدد',
                  '${_stats!.totalFlagged}',
                  Icons.flag,
                  Colors.red,
                ),
                _buildStatCard(
                  'طابور الانتظار',
                  '${_stats!.queueSize}',
                  Icons.queue,
                  Colors.orange,
                ),
                _buildStatCard(
                  'التقارير',
                  '${_stats!.totalReports}',
                  Icons.report,
                  Colors.blue,
                ),
                _buildStatCard(
                  'تحديد تلقائي',
                  '${_stats!.autoFlagged}',
                  Icons.auto_flag,
                  Colors.purple,
                ),
                _buildStatCard(
                  'تحديد يدوي',
                  '${_stats!.manuallyFlagged}',
                  Icons.flag,
                  Colors.green,
                ),
                _buildStatCard(
                  'المعالجة اليوم',
                  '${_stats!.processedToday}',
                  Icons.today,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContentSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
            
            const SizedBox(height: 16),
            
            // Report Form
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
            
            // Description
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
    bool isSelected = _reportReason == value;
    
    return FilterChip(
      label: label,
      selected: isSelected,
      onSelected: () => setState(() => _reportReason = value),
      backgroundColor: isSelected ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.2),
      labelStyle: GoogleFonts.tajawal(
        color: isSelected ? Colors.white : const Color(0xFFd4af37),
        fontSize: 12,
      ),
    );
  }

  Color _getFlagColor(String reason) {
    switch (reason) {
      case 'explicit_content':
        return Colors.red;
      case 'violence':
        return Colors.red;
      case 'adult_content':
        return Colors.orange;
      case 'inappropriate':
        return Colors.orange;
      case 'copyright':
        return Colors.blue;
      case 'hate_speech':
        return Colors.red;
      case 'spam':
        return Colors.yellow;
      case 'misinformation':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getFlagIcon(String reason) {
    switch (reason) {
      case 'explicit_content':
        return Icons.block;
      case 'violence':
        return Icons.warning;
      case 'adult_content':
        return Icons.no_adult_content;
      case 'inappropriate':
        return Icons.thumb_down;
      case 'copyright':
        return Icons.copyright;
      case 'hate_speech':
        return Icons.mood_bad;
      case 'spam':
        return Icons.spam;
      case 'misinformation':
        return Icons.info;
      default:
        return Icons.flag;
    }
  }

  Color _getQueueActionColor(String action) {
    switch (action) {
      case 'flag_content':
        return Colors.red;
      case 'delete_content':
        return Colors.orange;
      case 'approve_content':
        return Colors.green;
      case 'reject_content':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getQueueActionIcon(String action) {
    switch (action) {
      case 'flag_content':
        return Icons.flag;
      case 'delete_content':
        return Icons.delete;
      case 'approve_content':
        return Icons.check_circle;
      case 'reject_content':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<void> _loadModerationData() async {
    setState(() => _isLoading = true);
    try {
      final flaggedContent = await _moderationService.getFlaggedContent();
      final queueItems = await _moderationService.getModerationQueue();
      final stats = await _moderationService.getModerationStats();
      
      setState(() {
        _flaggedContent = flaggedContent;
        _queueItems = queueItems;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadModerationData();
  }

  Future<void> _reviewFlaggedContent(String contentId, String action, {String? reviewNotes}) async {
    try {
      await _moderationService.reviewFlaggedContent(
        contentId: contentId,
        reviewAction: action,
        reviewNotes: reviewNotes,
      );
      await _loadModerationData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _processQueueItem(String queueId) async {
    try {
      // Process queue item logic here
      await _moderationService.processModerationQueue();
      await _loadModerationData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _skipQueueItem(String queueId) async {
    try {
      // Skip queue item logic here
      await _moderationService.processModerationQueue();
      await _loadModerationData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _deleteFlaggedContent(String contentId) async {
    try {
      await _moderationService.deleteContent(contentId);
      await _loadModerationData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _submitReport() async {
    if (_reportContentId.isEmpty || _reportReason.isEmpty) {
      // Show error message
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
    
    try {
      setState(() => _isLoading = true);
      
      // Submit report logic here
      await _moderationService.flagContent(
        contentId: _reportContentId,
        reason: _reportReason,
        description: _reportDescription,
      );
      
      setState(() => _isLoading = false);
      _reportContentId = '';
      _reportReason = '';
      _reportDescription = '';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال البلاغ بنجاح',
            style: GoogleFonts.tajawal(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
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
