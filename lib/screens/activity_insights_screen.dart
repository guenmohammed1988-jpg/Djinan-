import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/activity_tracking_service.dart';

class ActivityInsightsScreen extends StatefulWidget {
  const ActivityInsightsScreen({super.key});

  @override
  State<ActivityInsightsScreen> createState() => _ActivityInsightsScreenState();
}

class _ActivityInsightsScreenState extends State<ActivityInsightsScreen> {
  final ActivityTrackingService _trackingService = ActivityTrackingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  ActivityStats? _stats;
  ActivityInsights? _insights;
  bool _isLoading = false;
  String _selectedPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'رؤية النشاط',
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
            onPressed: _refreshInsights,
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
              // Stats Cards
              _buildStatsCards(),
              
              const SizedBox(height: 24),
              
              // Period Selector
              _buildPeriodSelector(),
              
              const SizedBox(height: 24),
              
              // Activity Chart
              _buildActivityChart(),
              
              const SizedBox(height: 24),
              
              // Insights
              _buildInsightsSection(),
            ],
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
            'إجمالي الوقت',
            '${_stats?.totalMinutes ?? 0} دقيقة',
            const Icon(Icons.access_time, color: Color(0xFFd4af37)),
            Colors.white,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'متوسط يومي',
            '${((_stats?.dailyMinutes ?? 0) / 60).toStringAsFixed(1)} ساعة',
            const Icon(Icons.schedule, color: Color(0xFFd4af37)),
            Colors.white,
          ),
        ),
        Expanded(
          child: _buildStatCard(
            'مجموع أسبوعي',
            '${((_stats?.weeklyMinutes ?? 0) / 60).toStringAsFixed(1)} ساعة',
            const Icon(Icons.date_range, color: Color(0xFFd4af37)),
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
                  color: textColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.tajawal(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodChip('يوم', 'week'),
          ),
          Expanded(
            child: _buildPeriodChip('شهر', 'month'),
          ),
          Expanded(
            child: _buildPeriodChip('سنة', 'year'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String period) {
    bool isSelected = _selectedPeriod == period;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
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

  Widget _buildActivityChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نشاط اليومي',
            style: GoogleFonts.tajawal(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '120 دقيقة',
            style: GoogleFonts.tajawal(
              color: const Color(0xFFd4af37),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '2 ساعة',
            style: GoogleFonts.tajawal(
              color: Colors.white.withOpacity(0.6),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليل النشاط',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // User Type
          if (_insights?.userType != null) ...[
            _buildInsightCard(
              'نوع المستخدم',
              _insights!.userType == 'power_user' ? 'مستخدم نشط' : 'مستخدم عادي',
              const Icon(Icons.person, color: Color(0xFFd4af37)),
              Colors.white,
            ),
          ],
          
          // Risk Score
          _buildInsightCard(
            'مستوى المخاطرة',
            '${_insights!.fraudScore?.toStringAsFixed(1) ?? '0'}%',
            const Icon(Icons.warning, color: Colors.orange),
              Colors.white,
            ),
          ],
          
          // Activity Patterns
          _buildInsightCard(
              'أنماط النشاط',
              _insights!.stdDev != null 
                  ? '${_insights!.stdDev.toStringAsFixed(2)} دقيقة'
                  : 'غير محدد',
              const Icon(Icons.analytics, color: Color(0xFFd4af37)),
              Colors.white,
            ),
          ],
          
          // Recommendations
          if (_insights?.userType == 'dedicated_user') ...[
            _buildRecommendationCard(
              'حافظ على الاستمرارية',
              'استمر لمدة 15 ساعة يومياً للحفاظ على نشاطك',
              const Icon(Icons.trending_up, color: Color(0xFFd4af37)),
              Colors.white,
            ),
          ],
        ],
        
        const SizedBox(height: 24),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, color: Color(0xFFd4af37)),
                label: Text(
                  'بدء التتبع',
                  style: GoogleFonts.tajawal(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _startTracking,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop, color: Color(0xFFd4af37)),
                label: Text(
                  'إيقاف',
                  style: GoogleFonts.tajawal(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: _stopTracking,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String content, IconData icon, Color textColor) {
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
                size: 20,
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
                content,
                style: GoogleFonts.tajawal(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String title, String content, IconData icon) {
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
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          const Spacer(),
          Text(
                content,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);
    
    try {
      final insights = await _trackingService.getActivityInsights();
      final stats = await _trackingService.getActivityStats();
      
      setState(() {
        _insights = insights;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshInsights() async {
    await _loadInsights();
  }

  Future<void> _startTracking() async {
    await _trackingService.startTracking();
    setState(() {});
  }

  Future<void> _stopTracking() async {
    await _trackingService.stopTracking();
    setState(() {});
  }
}
