import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _moderationStats = {};
  List<Map<String, dynamic>> _fraudScores = [];
  List<Map<String, dynamic>> _contentReports = [];
  bool _isLoading = false;
  String _selectedTab = 'users';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة التحكم',
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
            onPressed: _refreshDashboard,
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
              // Tab Selector
              _buildTabSelector(),
              
              const SizedBox(height: 16),
              
              // Stats Cards
              _buildStatsCards(),
              
              const SizedBox(height: 16),
              
              // Content based on selected tab
              Expanded(
                child: _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildTabChip('المستخدمين', 'users'),
          ),
          Expanded(
            child: _buildTabChip('الإحصائيات', 'stats'),
          ),
          Expanded(
            child: _buildTabChip('النزاع', 'moderation'),
          ),
          Expanded(
            child: _buildTabChip('التقارير', 'reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String tab) {
    bool isSelected = _selectedTab == tab;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
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
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'إجمالي المستخدمين',
            '${_userStats['totalUsers'] ?? 0}',
            const Icon(Icons.people, color: Color(0xFFd4af37)),
            Colors.white,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'المستخدمين النشطين',
            '${_userStats['activeUsers'] ?? 0}',
            const Icon(Icons.person, color: Color(0xFFd4af37)),
            Colors.white,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'المحظورين',
            '${_userStats['bannedUsers'] ?? 0}',
            const Icon(Icons.block, color: Colors.red),
            Colors.white,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'عالي المخاطرة',
            '${_userStats['highRiskUsers'] ?? 0}',
            const Icon(Icons.warning, color: Colors.orange),
            Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon: icon,
                color: const Color(0xFFd4af37),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          const Spacer(),
          Text(
                value,
                style: GoogleFonts.tajawal(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'users':
        return _buildUsersTab();
      case 'stats':
        return _buildStatsTab();
      case 'moderation':
        return _buildModerationTab();
      case 'reports':
        return _buildReportsTab();
      default:
        return _buildUsersTab();
    }
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'البحث عن مستخدم...',
              hintStyle: GoogleFonts.tajawal(
                color: Colors.white.withOpacity(0.6),
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFd4af37)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFd4af37)),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
            ),
            style: GoogleFonts.tajawal(
              color: Colors.white,
            ),
            onChanged: (value) {
              // Search users
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Users List
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return _buildUserCard(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isBanned = user['isBanned'] ?? false;
    final isHighRisk = (user['fraudScore'] ?? 100.0) < 50;
    final role = user['role'] ?? 'user';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // User Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isBanned ? Colors.red : const Color(0xFFd4af37),
                  child: Text(
                    user['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'غير معروف',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user['email'] ?? '',
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: role == 'admin' ? Colors.green : Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role == 'admin' ? 'مدير' : 'مستخدم',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isHighRisk)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'عالي المخاطرة',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isBanned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'محظور',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                Column(
                  children: [
                    if (isBanned)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.lock_open, color: Color(0xFFd4af37)),
                        label: Text(
                          'إلغاء الحظر',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _unbanUser(user['id']),
                      ),
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.block, color: Color(0xFFd4af37)),
                        label: Text(
                          'حظر',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _banUser(user['id']),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return Column(
      children: [
        // User Statistics
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إحصائيات المستخدمين',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              const SizedBox(height: 16),
              
              // Fraud Score Distribution
              _buildFraudScoreChart(),
              
              const SizedBox(height: 24),
              
              // Activity Patterns
              _buildActivityPatterns(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFraudScoreChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع درجة الاحتيال',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          const SizedBox(height: 16),
          
          // Simple score distribution
          Row(
            children: [
              Expanded(
                child: _buildScoreRange('0-50', 'منخفض', Colors.green),
              ),
              Expanded(
                child: _buildScoreRange('50-75', 'متوسط', Colors.orange),
              ),
              Expanded(
                child: _buildScoreRange('75-100', 'مرتفع', Colors.red),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Score list
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _fraudScores.length,
              itemBuilder: (context, index) {
                final score = _fraudScores[index];
                return _buildFraudScoreCard(score);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRange(String range, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            range,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFraudScoreCard(Map<String, dynamic> score) {
    final scoreValue = score['score'] ?? 100.0;
    final isHighRisk = score['isHighRisk'] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // User Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: isHighRisk ? Colors.red : Colors.green,
              child: Text(
                score['userId']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Score Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'درجة الاحتيال: ${scoreValue.toStringAsFixed(1)}',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHighRisk ? 'عالي المخاطرة' : 'منخفض المخاطرة',
                    style: GoogleFonts.tajawal(
                      color: isHighRisk ? Colors.red : Colors.green,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'آخر تحليل: ${score['calculatedAt'] ?? 'غير معروف'}',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityPatterns() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أنماط النشاط',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          const SizedBox(height: 16),
          
          // Activity pattern indicators
          Row(
            children: [
              Expanded(
                child: _buildPatternCard('نشاط عادي', '70%', Colors.green),
              ),
              Expanded(
                child: _buildPatternCard('نشاط متكرر', '20%', Colors.orange),
              ),
              Expanded(
                child: _buildPatternCard('نشاط مشبوه', '10%', Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternCard(String pattern, String percentage, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            pattern,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            percentage,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationTab() {
    return Column(
      children: [
        // Moderation Stats
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إحصائيات النزاع',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              const SizedBox(height: 16),
              
              // Moderation Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildModerationStatCard(
                      'المحتوى المحظور',
                      '${_moderationStats['flaggedContent'] ?? 0}',
                      const Icon(Icons.flag, color: Color(0xFFd4af37)),
                    ),
                  ),
                  Expanded(
                    child: _buildModerationStatCard(
                      'قائمة الانتظار',
                      '${_moderationStats['moderationQueue'] ?? 0}',
                      const Icon(Icons.queue, color: Color(0xFFd4af37)),
                    ),
                  ),
                  Expanded(
                    child: _buildModerationStatCard(
                      'التقارير',
                      '${_moderationStats['moderationReports'] ?? 0}',
                      const Icon(Icons.report, color: Color(0xFFd4af37)),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Moderation Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Color(0xFFd4af37)),
                      label: Text(
                        'الموافقة على الكل',
                        style: GoogleFonts.tajawal(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _approveAllContent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete, color: Color(0xFFd4af37)),
                      label: Text(
                        'حذف الكل',
                        style: GoogleFonts.tajawal(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _deleteAllContent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Content List
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المحتوى المحتاج للمراجعة',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Content items would go here
                Expanded(
                  child: Center(
                    child: Text(
                      'لا يوجد محتوى حالياً',
                      style: GoogleFonts.tajawal(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModerationStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon: icon,
                color: const Color(0xFFd4af37),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          const Spacer(),
          Text(
                value,
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        // Reports Stats
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تقارير المحتوى',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              const SizedBox(height: 16),
              
              // Reports Summary
              Row(
                children: [
                  Expanded(
                    child: _buildReportStatCard(
                      'إجمالي التقارير',
                      '${_contentReports.length}',
                      const Icon(Icons.summarize, color: Color(0xFFd4af37)),
                    ),
                  ),
                  Expanded(
                    child: _buildReportStatCard(
                      'قيد المراجعة',
                      '5',
                      const Icon(Icons.pending, color: Colors.orange),
                    ),
                  ),
                  Expanded(
                    child: _buildReportStatCard(
                      'مكتملة',
                      '3',
                      const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Reports List
        Expanded(
          child: ListView.builder(
            itemCount: _contentReports.length,
            itemBuilder: (context, index) {
              final report = _contentReports[index];
              return _buildReportCard(report);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon: icon,
                color: const Color(0xFFd4af37),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          const Spacer(),
          Text(
                value,
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'pending';
    final statusColor = status == 'pending' ? Colors.orange : 
                        status == 'approved' ? Colors.green : Colors.red;
    
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
                // Report ID
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${report['id'] ?? ''}',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status == 'pending' ? 'قيد المراجعة' : 
                          status == 'approved' ? 'مكتملة' : 'مرفوضة',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Action Buttons
                if (status == 'pending')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Color(0xFFd4af37)),
                    label: Text(
                      'موافقة',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _approveReport(report['id']),
                  ),
                if (status == 'approved')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close, color: Color(0xFFd4af37)),
                    label: Text(
                      'رفض',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _rejectReport(report['id']),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Report Details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السبب: ${report['reason'] ?? ''}',
                  style: GoogleFonts.tajawal(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المبلغ: ${report['reporterId'] ?? ''}',
                  style: GoogleFonts.tajawal(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تاريخ: ${report['createdAt'] ?? ''}',
                  style: GoogleFonts.tajawal(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load all data in parallel
      final futures = await Future.wait([
        _adminService.getAllUsers(),
        _adminService.getUserStats(''),
        _adminService.getContentModerationStats(),
        _adminService.getFraudScores(),
        _adminService.getContentReports(),
      ]);
      
      setState(() {
        _users = futures[0] as List<Map<String, dynamic>>;
        _userStats = futures[1] as Map<String, dynamic>;
        _moderationStats = futures[2] as Map<String, dynamic>;
        _fraudScores = futures[3] as List<Map<String, dynamic>>;
        _contentReports = futures[4] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadDashboardData();
  }

  Future<void> _banUser(String userId) async {
    await _adminService.banUser(userId: userId, reason: 'نشاط مشبوه');
    await _loadDashboardData();
  }

  Future<void> _unbanUser(String userId) async {
    await _adminService.unbanUser(userId);
    await _loadDashboardData();
  }

  Future<void> _approveAllContent() async {
    // Approve all pending content
    for (final report in _contentReports) {
      if (report['status'] == 'pending') {
        await _adminService.updateContentStatus(
          contentId: report['contentId'],
          status: 'approved',
        );
      }
    }
    await _loadDashboardData();
  }

  Future<void> _deleteAllContent() async {
    // Delete all flagged content
    for (final report in _contentReports) {
      if (report['status'] == 'pending') {
        await _adminService.updateContentStatus(
          contentId: report['contentId'],
          status: 'deleted',
        );
      }
    }
    await _loadDashboardData();
  }

  Future<void> _approveReport(String reportId) async {
    // Find and approve specific report
    for (final report in _contentReports) {
      if (report['id'] == reportId) {
        await _adminService.updateContentStatus(
          contentId: report['contentId'],
          status: 'approved',
        );
        break;
      }
    }
    await _loadDashboardData();
  }

  Future<void> _rejectReport(String reportId) async {
    // Find and reject specific report
    for (final report in _contentReports) {
      if (report['id'] == reportId) {
        await _adminService.updateContentStatus(
          contentId: report['contentId'],
          status: 'rejected',
          moderatorNote: 'غير مناسب',
        );
        break;
      }
    }
    await _loadDashboardData();
  }
}
