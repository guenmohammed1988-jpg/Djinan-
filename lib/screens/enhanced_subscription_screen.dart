import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/enhanced_subscription_service.dart';

class EnhancedSubscriptionScreen extends StatefulWidget {
  const EnhancedSubscriptionScreen({super.key});

  @override
  State<EnhancedSubscriptionScreen> createState() => _EnhancedSubscriptionScreenState();
}

class _EnhancedSubscriptionScreenState extends State<EnhancedSubscriptionScreen> {
  final EnhancedSubscriptionService _subscriptionService = EnhancedSubscriptionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  EnhancedSubscription? _subscription;
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.loading;
  SubscriptionAnalytics? _analytics;
  String _selectedPaymentMethod = 'chargily';
  bool _isLoading = false;
  bool _showPaymentMethods = false;
  bool _showAnalytics = false;
  String _renewalAmount = '';

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الاشتراكات المحسنة',
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
                // Subscription Status Card
                _buildSubscriptionStatusCard(),
                
                const SizedBox(height: 24),
                
                // Payment Methods Card
                _buildPaymentMethodsCard(),
                
                const SizedBox(height: 24),
                
                // Analytics Card
                _buildAnalyticsCard(),
                
                const SizedBox(height: 24),
                
                // Actions Card
                _buildActionsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusCard() {
    if (_subscriptionStatus == SubscriptionStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final statusText = _getStatusText();

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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حالة الاشتراك',
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Subscription Details
            if (_subscription != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نوع الاشتراك',
                      style: GoogleFonts.tajawal(
                        color: const Color(0xFFd4af37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subscription!.planTypeText,
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_subscription!.isTrialActive) ...[
                      Text(
                        'فترة التجربة',
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تنتهي: ${_subscription!.formattedTrialEndDate}',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'تاريخ الانتهاء',
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subscription!.formattedExpiryDate,
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Payment Method
                    Text(
                      'طريقة الدفع',
                      style: GoogleFonts.tajawal(
                        color: const Color(0xFFd4af37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subscription!.paymentMethod,
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Auto-renewal
                    Row(
                      children: [
                        Text(
                          'تجديد تلقائي',
                          style: GoogleFonts.tajawal(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _subscription!.autoRenewal,
                          onChanged: (value) => _toggleAutoRenewal(value),
                          activeColor: const Color(0xFFd4af37),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Days Remaining
                    Text(
                      'الأيام المتبقية',
                      style: GoogleFonts.tajawal(
                        color: const Color(0xFFd4af37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_subscription!.daysRemaining} يوم',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طرق الدفع',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                TextButton.icon(
                  icon: Icon(_showPaymentMethods ? Icons.expand_less : Icons.expand_more, 
                            color: const Color(0xFFd4af37)),
                  label: Text(
                    _showPaymentMethods ? 'إخفاء' : 'عرض',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFd4af37),
                    ),
                  ),
                  onPressed: () => setState(() => _showPaymentMethods = !_showPaymentMethods),
                ),
              ],
            ),
            
            if (_showPaymentMethods) ...[
              const SizedBox(height: 16),
              
              // Payment Method Options
              _buildPaymentMethodOption(
                'chargily',
                'CHARGILY',
                'الدفع عبر الهاتف',
                Icons.phone,
                () => _selectPaymentMethod('chargily'),
              ),
              
              const SizedBox(height: 12),
              
              _buildPaymentMethodOption(
                'stripe',
                'STRIPE',
                'الدفع بالبطاقة',
                Icons.credit_card,
                () => _selectPaymentMethod('stripe'),
              ),
              
              const SizedBox(height: 12),
              
              _buildPaymentMethodOption(
                'paypal',
                'PAYPAL',
                'الدفع عبر بايبال',
                Icons.account_balance_wallet,
                () => _selectPaymentMethod('paypal'),
              ),
              
              const SizedBox(height: 12),
              
              _buildPaymentMethodOption(
                'binance',
                'BINANCE',
                'الدفع بالعملات الرقمية',
                Icons.currency_bitcoin,
                () => _selectPaymentMethod('binance'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption(String method, String displayName, String description, IconData icon, VoidCallback onTap) {
    final isSelected = _selectedPaymentMethod == method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFd4af37) : Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFFd4af37),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.tajawal(
                        color: isSelected ? Colors.white : const Color(0xFFd4af37),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.tajawal(
                        color: isSelected ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    if (_analytics == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.analytics,
                color: Color(0xFFd4af37),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل البيانات التحليلية...',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 16,
                ),
            ],
          ),
        ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'التحليلات',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                TextButton.icon(
                  icon: Icon(_showAnalytics ? Icons.expand_less : Icons.expand_more, 
                            color: const Color(0xFFd4af37)),
                  label: Text(
                    _showAnalytics ? 'إخفاء' : 'عرض',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFd4af37),
                    ),
                  ),
                  onPressed: () => setState(() => _showAnalytics = !_showAnalytics),
                ),
              ],
            ),
            
            if (_showAnalytics) ...[
              const SizedBox(height: 16),
              
              // Analytics Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                children: [
                  _buildAnalyticsItem(
                    'المجموع المدفوع',
                    '${_analytics!.formattedTotalPaid}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                  _buildAnalyticsItem(
                    'عدد المدفوعات',
                    '${_analytics!.paymentsCount}',
                    Icons.receipt,
                    Colors.blue,
                  ),
                  _buildAnalyticsItem(
                    'متوسط الدفعة',
                    '${_analytics!.formattedAveragePayment}',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                  _buildAnalyticsItem(
                    'أيام منذ البدء',
                    '${_analytics!.formattedDaysSinceStart}',
                    Icons.calendar_today,
                    Colors.purple,
                  ),
                  _buildAnalyticsItem(
                    'الأيام المتبقية',
                    '${_analytics!.formattedDaysRemaining}',
                    Icons.access_time,
                    Colors.red,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsItem(String title, String value, IconData icon, Color color) {
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

  Widget _buildActionsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'الإجراءات',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            if (_subscription?.status == 'trial') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upgrade, color: Color(0xFFd4af37)),
                  label: Text(
                    'ترقية إلى اشتراك مدفوع',
                    style: GoogleFonts.tajawal(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFd4af37),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _upgradeToPaid,
                ),
              ),
            ] else if (_subscription?.status == 'active') ...[
              // Renewal Button
              if (_subscription!.needsRenewal) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, color: Color(0xFFd4af37)),
                    label: Text(
                      'تجديد الاشتراك',
                      style: GoogleFonts.tajawal(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFd4af37),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _renewSubscription,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: Text(
                    'إلغاء الاشتراك',
                    style: GoogleFonts.tajawal(),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _cancelSubscription,
                ),
              ),
            ] else ...[
              // Start Trial Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, color: Color(0xFFd4af37)),
                  label: Text(
                    'بدء التجربة المجانية',
                    style: GoogleFonts.tajawal(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFd4af37),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _startFreeTrial,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trialActive:
        return Colors.green;
      case SubscriptionStatus.trialExpired:
        return Colors.orange;
      case SubscriptionStatus.active:
        return Colors.blue;
      case SubscriptionStatus.expired:
        return Colors.red;
      case SubscriptionStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trialActive:
        return Icons.play_circle;
      case SubscriptionStatus.trialExpired:
        return Icons.warning;
      case SubscriptionStatus.active:
        return Icons.check_circle;
      case SubscriptionStatus.expired:
        return Icons.error;
      case SubscriptionStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.trialActive:
        return 'التجربة نشطة';
      case SubscriptionStatus.trialExpired:
        return 'انتهت فترة التجربة';
      case SubscriptionStatus.active:
        return 'الاشتراك نشط';
      case SubscriptionStatus.expired:
        return 'الاشتراك منتهي';
      case SubscriptionStatus.cancelled:
        return 'الاشتراك ملغي';
      case SubscriptionStatus.renewalNeeded:
        return 'يحتاج للتجديد';
      default:
        return 'غير معروف';
    }
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);
    try {
      final subscription = await _subscriptionService.getEnhancedSubscription();
      final status = await _subscriptionService.checkSubscriptionStatus();
      final analytics = await _subscriptionService.getSubscriptionAnalytics();
      
      setState(() {
        _subscription = subscription;
        _subscriptionStatus = status;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadSubscriptionData();
  }

  Future<void> _selectPaymentMethod(String method) async {
    setState(() => _selectedPaymentMethod = method);
  }

  Future<void> _toggleAutoRenewal(bool value) async {
    try {
      await _subscriptionService.updateAutoRenewal(value);
      await _loadSubscriptionData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _startFreeTrial() async {
    try {
      await _subscriptionService.startFreeTrial();
      await _loadSubscriptionData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _upgradeToPaid() async {
    try {
      await _subscriptionService.processPayment(
        paymentMethod: _selectedPaymentMethod,
        amount: EnhancedSubscriptionService.annualSubscriptionFee,
        paymentDetails: {
          'description': 'Upgrade from trial to annual subscription',
        },
      );
      await _loadSubscriptionData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _renewSubscription() async {
    try {
      await _subscriptionService.renewSubscription();
      await _loadSubscriptionData();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _cancelSubscription() async {
    try {
      await _subscriptionService.cancelSubscription();
      await _loadSubscriptionData();
    } catch (e) {
      // Handle error
    }
  }
}
