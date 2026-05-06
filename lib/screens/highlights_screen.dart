import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/highlights_service.dart';

class HighlightsScreen extends StatefulWidget {
  const HighlightsScreen({super.key});

  @override
  State<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends State<HighlightsScreen> {
  final HighlightsService _highlightsService = HighlightsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  UserHighlights? _userHighlights;
  PricingInfo? _pricingInfo;
  List<FeaturedMerchant> _featuredMerchants = [];
  List<DailyStreak> _streakHistory = [];
  
  bool _isLoading = false;
  bool _isPeakHour = false;
  Timer? _peakHourTimer;

  @override
  void initState() {
    super.initState();
    _loadHighlights();
    _loadPricingInfo();
    _loadFeaturedMerchants();
    _loadStreakHistory();
    
    // Start peak hour checker
    _startPeakHourTimer();
  }

  @override
  void dispose() {
    _peakHourTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الإضاءات',
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
                // Daily Streak Section
                _buildStreakSection(),
                
                const SizedBox(height: 24),
                
                // Pricing Section
                _buildPricingSection(),
                
                const SizedBox(height: 24),
                
                // Featured Merchants Section
                _buildFeaturedSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakSection() {
    if (_userHighlights == null) {
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
            Row(
              children: [
                Text(
                  'السلسلة اليومية',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                const Spacer(),
                if (_isPeakHour) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'ساعة الذروة',
                          style: GoogleFonts.tajawal(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                Text(
                  _userHighlights!.streakEmoji,
                  style: GoogleFonts.tajawal(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Streak Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFd4af37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السلسلة الحالية',
                            style: GoogleFonts.tajawal(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          Text(
                            '${_userHighlights!.currentStreak} يوم',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          Text(
                            _userHighlights!.streakMessage,
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                        ],
                      ),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'الأطول',
                            style: GoogleFonts.tajawal(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          Text(
                            '${_userHighlights!.longestStreak} يوم',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          Text(
                            'مجموع الإضاءات',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.history, color: Color(0xFFd4af37)),
                          label: Text(
                            'السجل',
                            style: GoogleFonts.tajawal(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: const Color(0xFFd4af37),
                          ),
                          onPressed: _showStreakHistory,
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.celebration, color: Color(0xFFd4af37)),
                          label: Text(
                            'مشاركة',
                            style: GoogleFonts.tajawal(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFd4af37),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _shareStreak,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    if (_pricingInfo == null) {
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
            Row(
              children: [
                Text(
                  'الأسعار',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                const Spacer(),
                if (_isPeakHour) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'مضاعفة x${_pricingInfo!.peakHourMultiplier.toStringAsFixed(1)}',
                          style: GoogleFonts.tajawal(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                Text(
                  'السعر الحالي: ${_pricingInfo!.formattedCurrentPrice}',
                  style: GoogleFonts.tajawal(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Pricing Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFd4af37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildPricingRow('السعر الأساسي', '${_pricingInfo!.basePrice.toStringAsFixed(0)} دج'),
                  _buildPricingRow('المضاعفة الحالية', '${_pricingInfo!.currentMultiplier.toStringAsFixed(1)}x'),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'الساعات الذروة: ${_pricingInfo!.peakHours.join(', ')}',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'إعادة التعيين: ${_pricingInfo!.timeUntilReset}',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Featured Price
                  Text(
                    'سعر التمييز: ${_pricingInfo!.featuredPrice.toStringAsFixed(0)} دج',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.tajawal(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'التجار المميزة',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_featuredMerchants.length} متجر',
                  style: GoogleFonts.tajawal(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Featured Merchants List
            if (_featuredMerchants.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star,
                      color: Color(0xFFd4af37),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد متاجر مميزة حاليا',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, color: Color(0xFFd4af37)),
                      label: Text(
                        'إضافة متجر',
                        style: GoogleFonts.tajawal(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFd4af37),
                      ),
                    ),
                  ],
                ),
              ) else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _featuredMerchants.length,
                  itemBuilder: (context, index) {
                    final merchant = _featuredMerchants[index];
                    return _buildFeaturedMerchantCard(merchant);
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedMerchantCard(FeaturedMerchant merchant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Featured Badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFd4af37),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Color(0xFFd4af37),
                        size: 12,
                      ),
                    ),
                  ],
                  Center(
                    child: Text(
                      '${(merchant.featuredAt.difference(DateTime.now()).inDays + 1}',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Merchant Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFd4af37),
                        backgroundImage: merchant.logo != null
                            ? CachedNetworkImageProvider(merchant.logo!)
                            : null,
                        child: merchant.logo == null
                            ? Text(
                                merchant.storeName.isNotEmpty ? merchant.storeName[0] : '?',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              merchant.storeName,
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '@${merchant.username}',
                              style: GoogleFonts.tajawal(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFFd4af37),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  merchant.rating.toStringAsFixed(1),
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            
                            if (merchant.categories.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: merchant.categories.take(3).map((category) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      category,
                                      style: GoogleFonts.tajawal(
                                        color: const Color(0xFFd4af37),
                                        fontSize: 8,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            
                            const SizedBox(height: 8),
                            
                            Text(
                              merchant.description,
                              style: GoogleFonts.tajawal(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Action Button
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => _showMerchantDetails(merchant),
            ),
          ],
        ),
      ),
    );
  }

  void _startPeakHourTimer() {
    _peakHourTimer?.cancel();
    _peakHourTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final isPeak = _highlightsService.isPeakHour();
      if (isPeak != _isPeakHour) {
        setState(() => _isPeakHour = isPeak);
      }
    });
  }

  Future<void> _loadHighlights() async {
    setState(() => _isLoading = true);
    try {
      final highlights = await _highlightsService.getUserHighlights();
      setState(() {
        _userHighlights = highlights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPricingInfo() async {
    try {
      final pricing = await _highlightsService.getPricingInfo();
      setState(() {
        _pricingInfo = pricing;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadFeaturedMerchants() async {
    setState(() => _isLoading = true);
    try {
      final merchants = await _highlightsService.getFeaturedMerchants();
      setState(() {
        _featuredMerchants = merchants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStreakHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _highlightsService.getDailyStreaksHistory();
      setState(() {
        _streakHistory = history;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadHighlights();
    await _loadPricingInfo();
    await _loadFeaturedMerchants();
    await _loadStreakHistory();
  }

  void _showStreakHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سجل السلسلة اليومية',
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const Divider(color: Colors.white24),
            
            // Streak History List
            Expanded(
              child: ListView.builder(
                itemCount: _streakHistory.length,
                itemBuilder: (context, index) {
                  final streak = _streakHistory[index];
                  return _buildStreakHistoryItem(streak);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakHistoryItem(DailyStreak streak) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: streak.isActive ? const Color(0xFFd4af37) : Colors.grey[400]!,
        child: Text(
          streak.streakDays.toString(),
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      title: Text(
        'يوم ${streak.streakDays}',
        style: GoogleFonts.tajawal(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFd4af37),
        ),
      subtitle: Text(
        'نشط: ${streak.isActive ? "نعم" : "لا"}',
        style: GoogleFonts.tajawal(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
        ),
      trailing: Text(
        '${streak.date.day}/${streak.date.month}/${streak.date.year}',
        style: GoogleFonts.tajawal(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
        ),
      onTap: () => _showStreakDetails(streak),
    );
  }

  void _showStreakDetails(DailyStreak streak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تفاصيل السلسلة',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'يوم ${streak.streakDays}',
              style: GoogleFonts.tajawal(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              streak.isActive ? 'كان نشطا' : 'لم يكن نشطا',
              style: GoogleFonts.tajawal(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${streak.date.day}/${streak.date.month}/${streak.date.year}',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'موافق',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareStreak() {
    // Share functionality
    final streakMessage = 'لقد حققت سلسلة من ${_userHighlights!.currentStreak} يوم متتالية! 🔥 ${_userHighlights!.streakEmoji}';
    
    // You can implement actual sharing functionality here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          streakMessage,
          style: GoogleFonts.tajawal(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFd4af37),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showMerchantDetails(FeaturedMerchant merchant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          merchant.storeName,
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Merchant Logo
              if (merchant.logo != null) ...[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: merchant.logo!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.store, color: Color(0xFFd4af37)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Merchant Info
              Text(
                '@${merchant.username}',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              
              // Rating
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFd4af37), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    merchant.rating.toStringAsFixed(1),
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Categories
              if (merchant.categories.isNotEmpty) ...[
                Text(
                  'الفئات:',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: merchant.categories.map((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFFd4af37),
                          fontSize: 8,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              
              // Description
              Text(
                merchant.description,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              const SizedBox(height: 8),
              
              // Featured Until
              Text(
                'مميز حتى: ${merchant.featuredUntil.day}/${merchant.featuredUntil.month}/${merchant.featuredUntil.year}',
                style: GoogleFonts.tajawal(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'موافق',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
