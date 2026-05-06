import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_messaging_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _notifications = [];
  Map<String, int> _notificationCounts = {};
  bool _isLoading = false;
  String _selectedType = 'all';
  int _unreadOnly = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadNotificationCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الإشعارات',
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
            onPressed: _refreshNotifications,
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
          child: Column(
            children: [
              // Header with stats
              _buildNotificationHeader(),
              
              const SizedBox(height: 16),
              
              // Filter tabs
              _buildFilterTabs(),
              
              const SizedBox(height: 16),
              
              // Notifications list
              Expanded(
                child: _buildNotificationsList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'الإشعارات',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildCountChip('الكل', _notifications.length),
                _buildCountChip('غير مقروء', _unreadOnly),
                _buildCountChip('جديد', _getNewCount()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.tajawal(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab('all', 'الكل'),
          ),
          Expanded(
            child: _buildFilterTab('general', 'عام'),
          ),
          Expanded(
            child: _buildFilterTab('like', 'إعجابات'),
          ),
          Expanded(
            child: _buildFilterTab('comment', 'تعليقات'),
          ),
          Expanded(
            child: _buildFilterTab('follower', 'متابعين'),
          ),
          Expanded(
            child: _buildFilterTab('alert', 'تنبيهات'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String type, String label) {
    bool isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.tajawal(
            color: isSelected ? Colors.white : const Color(0xFFd4af37),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          children: [
            const Icon(
              Icons.inbox,
              color: Color(0xFFd4af37),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد إشعارات',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final type = notification['type'] ?? 'general';
    final title = notification['title'] ?? '';
    final body = notification['body'] ?? '';
    final imageUrl = notification['imageUrl'];
    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isRead = notification['isRead'] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type and time
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(type),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(type),
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
                        _getNotificationTypeText(type),
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatNotificationTime(createdAt),
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Read status indicator
                if (!isRead)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      'جديد',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Content
            if (imageUrl != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            
            if (body.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  body,
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Action buttons
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
                    onPressed: () => _markAsRead(notification['id']),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Color(0xFFd4af37)),
                    label: Text(
                      'حذف',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _deleteNotification(notification['id']),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'general':
        return Colors.blue;
      case 'like':
        return Colors.green;
      case 'comment':
        return Colors.orange;
      case 'follower':
        return Colors.purple;
      case 'alert':
        return Colors.red;
      case 'expiry':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'general':
        return Icons.notifications;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follower':
        return Icons.person_add;
      case 'alert':
        return Icons.warning;
      case 'expiry':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  String _getNotificationTypeText(String type) {
    switch (type) {
      case 'general':
        return 'إشعار عام';
      case 'like':
        return 'إعجاب';
      case 'comment':
        return 'تعليق';
      case 'follower':
        return 'متابع جديد';
      case 'alert':
        return 'تنبيه';
      case 'expiry':
        return 'انتهاء الاشتراك';
      default:
        return 'غير معروف';
    }
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else if (difference.inDays < 30) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inDays < 365) {
      return 'منذ ${difference.inDays ~/ 30} شهر';
    } else {
      return 'منذ ${difference.inDays ~/ 365} سنة';
    }
  }

  int _getNewCount() {
    return _notificationCounts['general'] ?? 0;
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final notifications = await _messagingService.getNotifications(
        type: _selectedType,
        unreadOnly: _unreadOnly,
      );
      
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotificationCounts() async {
    try {
      final counts = await _messagingService.getNotificationCounts();
      
      setState(() {
        _notificationCounts = counts;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
    await _loadNotificationCounts();
  }

  Future<void> _markAsRead(String notificationId) async {
    await _messagingService.markNotificationAsRead(notificationId);
    await _loadNotifications();
    await _loadNotificationCounts();
  }

  Future<void> _deleteNotification(String notificationId) async {
    await _messagingService.deleteNotification(notificationId);
    await _loadNotifications();
    await _loadNotificationCounts();
  }
}
