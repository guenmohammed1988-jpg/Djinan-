import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  MerchantSubscription? _merchantSubscription;
  List<CustomerSubscription> _customerSubscriptions = [];
  SubscriptionStats? _stats;
  
  bool _isLoading = false;
  bool _showCustomers = false;
  bool _showWithdrawal = false;
  String _withdrawalAmount = '';

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
          'الاشتراكات',
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
                // Merchant Subscription Section
                _buildMerchantSubscriptionSection(),
                
                const SizedBox(height: 24),
                
                // Customer Management Section
                _buildCustomerManagementSection(),
                
                const SizedBox(height: 24),
                
                // Withdrawal Section
                _buildWithdrawalSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantSubscriptionSection() {
    if (_merchantSubscription == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.store,
                color: Color(0xFFd4af37),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'لا يوجد اشتراك تجاري نشط',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 16,
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Color(0xFFd4af37)),
                label: Text(
                  'تفعيل الاشتراك',
                  style: GoogleFonts.tajawal(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFd4af37),
                ),
                onPressed: _activateMerchantSubscription,
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
              children: [
                Text(
                  'اشتراك التجار',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _merchantSubscription!.isActive 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _merchantSubscription!.isActive ? 'نشط' : 'غير نشط',
                    style: GoogleFonts.tajawal(
                      color: _merchantSubscription!.isActive 
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Subscription Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFd4af37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('تاريخ الاشتراك', 
                    '${_merchantSubscription!.subscriptionDate.day}/${_merchantSubscription!.subscriptionDate.month}/${_merchantSubscription!.subscriptionDate.year}'),
                  
                  _buildInfoRow('الزبائن الحاليون', '${_merchantSubscription!.customerCount}'),
                  
                  _buildInfoRow('المستوى الحالي', _merchantSubscription!.tierName),
                  
                  _buildInfoRow('الإيرادات الإجمالية', '${_merchantSubscription!.totalRevenue.toStringAsFixed(2)} دج'),
                  
                  _buildInfoRow('السحب المعلق', _merchantSubscription!.formattedPendingPayout),
                  
                  const SizedBox(height: 16),
                  
                  // Tier Progress
                  Text(
                    'تقدم المستوى',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Tier Progress Bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        // Tier 1
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: _merchantSubscription!.currentTier.index >= 1 
                                  ? const Color(0xFFd4af37)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 2),
                        
                        // Tier 2
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: _merchantSubscription!.currentTier.index >= 2 
                                  ? const Color(0xFFd4af37)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 2),
                        
                        // Tier 3
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: _merchantSubscription!.currentTier.index >= 3 
                                  ? const Color(0xFFd4af37)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Tier Benefits
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مزايا المستوى:',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Tier 1 Benefits
                      if (_merchantSubscription!.currentTier.index >= 1) ...[
                        _buildTierBenefit('المستوى الأول', '30 زبون', '${SubscriptionService.tier1Payout} دج'),
                      ],
                      
                      // Tier 2 Benefits
                      if (_merchantSubscription!.currentTier.index >= 2) ...[
                        _buildTierBenefit('المستوى الثاني', '60 زبون', '${SubscriptionService.tier2Payout} دج'),
                      ],
                      
                      // Tier 3 Benefits
                      if (_merchantSubscription!.currentTier.index >= 3) ...[
                        _buildTierBenefit('المستوى الثالث', '90 زبون', '${SubscriptionService.tier3Payout} دج'),
                      ],
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

  Widget _buildInfoRow(String label, String value) {
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

  Widget _buildTierBenefit(String tierName, String customerLimit, String payout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tierName,
                style: GoogleFonts.tajawal(
                  color: const Color(0xFFd4af37),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              const Spacer(),
              Text(
                customerLimit,
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            payout,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerManagementSection() {
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
                  'إدارة الزبائن',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                TextButton.icon(
                  icon: Icon(_showCustomers ? Icons.expand_less : Icons.expand_more, 
                            color: const Color(0xFFd4af37)),
                  label: Text(
                    _showCustomers ? 'إخفاء' : 'عرض',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFd4af37),
                    ),
                  ),
                  onPressed: () => setState(() => _showCustomers = !_showCustomers),
                ),
              ],
            ),
            
            if (_showCustomers) ...[
              const SizedBox(height: 16),
              
              // Stats Summary
              if (_stats != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd4af37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'إحصائيات الزبائن',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'الإجمالي',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${_stats!.totalCustomers}',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          Column(
                            children: [
                              Text(
                                'نشط',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${_stats!.activeCustomers}',
                                style: GoogleFonts.tajawal(
                                  color: Colors.green,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          Column(
                            children: [
                              Text(
                                'معلق',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${_stats!.pendingCustomers}',
                                style: GoogleFonts.tajawal(
                                  color: Colors.orange,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
              
              // Customer List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customerSubscriptions.length,
                itemBuilder: (context, index) {
                  final customer = _customerSubscriptions[index];
                  return _buildCustomerCard(customer);
                },
              ),
            ],
            
            // Add Customer Button
            if (!_showCustomers) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, color: Color(0xFFd4af37)),
                  label: Text(
                    'إضافة زبون',
                    style: GoogleFonts.tajawal(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFd4af37),
                  ),
                  onPressed: _addCustomer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(CustomerSubscription customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status Badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: customer.isActive ? Colors.green : Colors.orange,
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
                      child: Icon(
                        customer.isActive ? Icons.check : Icons.hourglass_empty,
                        color: customer.isActive ? Colors.green : Colors.orange,
                        size: 12,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      customer.customerId.substring(0, 6),
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Customer Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'زبون #${customer.customerId}',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFd4af37),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'بدأ: ${customer.startDate.day}/${customer.startDate.month}/${customer.startDate.year}',
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Activity Progress
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'النشاط',
                              style: GoogleFonts.tajawal(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${customer.activeHours}/${SubscriptionService.minActiveHoursPerDay} ساعة',
                              style: GoogleFonts.tajawal(
                                color: customer.meetsRequirement 
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        
                        LinearProgressIndicator(
                          value: customer.progressPercentage / 100,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const Color(0xFFd4af37),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        Text(
                          customer.formattedProgress,
                          style: GoogleFonts.tajawal(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Payment Info
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المدفوع',
                            style: GoogleFonts.tajawal(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            customer.formattedTotalPaid,
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'المتبقي',
                            style: GoogleFonts.tajawal(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            customer.formattedRemainingHours,
                            style: GoogleFonts.tajawal(
                              color: Colors.orange,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Color(0xFFd4af37)),
                        label: Text(
                          'إضافة نشاط',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: const Color(0xFFd4af37),
                        ),
                        onPressed: () => _addCustomerActivity(customer.id),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment, color: Color(0xFFd4af37)),
                        label: Text(
                          'دفع',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: const Color(0xFFd4af37),
                        ),
                        onPressed: () => _processPayment(customer.id),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.info_outline, color: Color(0xFFd4af37)),
                        label: Text(
                          'تفاصيل',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFd4af37),
                        ),
                        onPressed: () => _showCustomerDetails(customer),
                      ),
                    ),
                    
                    if (!customer.meetsRequirement) ...[
                      const SizedBox(width: 8),
                      
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.warning, color: Colors.orange),
                          label: Text(
                            'إلغاء',
                            style: GoogleFonts.tajawal(),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          onPressed: () => _cancelCustomerSubscription(customer.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalSection() {
    if (_merchantSubscription == null) {
      return const SizedBox.shrink();
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
                  'السحب',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFd4af37),
                  ),
                ),
                TextButton.icon(
                  icon: Icon(_showWithdrawal ? Icons.expand_less : Icons.expand_more, 
                            color: const Color(0xFFd4af37)),
                  label: Text(
                    _showWithdrawal ? 'إخفاء' : 'عرض',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFd4af37),
                    ),
                  ),
                  onPressed: () => setState(() => _showWithdrawal = !_showWithdrawal),
                ),
              ],
            ),
            
            if (_showWithdrawal) ...[
              const SizedBox(height: 16),
              
              // Withdrawal Form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFd4af37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'المبلغ المطلوب للسحب',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'أدخل المبلغ',
                        hintStyle: GoogleFonts.tajawal(
                          color: Colors.white.withOpacity(0.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                      ),
                      onChanged: (value) => _withdrawalAmount = value,
                    ),
                    const SizedBox(height: 16),
                    
                    // Available Balance
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الرصيد المتاح:',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _merchantSubscription!.formattedPendingPayout,
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Withdraw Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.account_balance_wallet, color: Color(0xFFd4af37)),
                        label: Text(
                          'سحب',
                          style: GoogleFonts.tajawal(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFd4af37),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _merchantSubscription!.canWithdraw ? _processWithdrawal : null,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);
    try {
      final merchantSub = await _subscriptionService.getMerchantSubscription();
      final customerSubs = await _subscriptionService.getCustomerSubscriptions();
      final stats = await _subscriptionService.getSubscriptionStats();
      
      setState(() {
        _merchantSubscription = merchantSub;
        _customerSubscriptions = customerSubs;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadSubscriptionData();
  }

  Future<void> _activateMerchantSubscription() async {
    try {
      await _subscriptionService.createMerchantSubscription();
      await _loadSubscriptionData();
      _showSuccessSnackBar('تم تفعيل الاشتراك التجاري');
    } catch (e) {
      _showErrorSnackBar('فشل تفعيل الاشتراك');
    }
  }

  Future<void> _addCustomer() async {
    // Show dialog to add customer
    final customerId = await _showAddCustomerDialog();
    if (customerId == null || customerId.isEmpty) return;
    
    try {
      await _subscriptionService.createCustomerSubscription(
        merchantId: _auth.currentUser?.uid ?? '',
        customerId: customerId,
      );
      await _loadSubscriptionData();
      _showSuccessSnackBar('تم إضافة الزبون بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل إضافة الزبون');
    }
  }

  Future<void> _addCustomerActivity(String subscriptionId) async {
    try {
      await _subscriptionService.updateCustomerActivity(
        subscriptionId: subscriptionId,
        additionalHours: 1,
      );
      await _loadSubscriptionData();
      _showSuccessSnackBar('تم إضافة ساعة نشاط');
    } catch (e) {
      _showErrorSnackBar('فشل إضافة النشاط');
    }
  }

  Future<void> _processPayment(String subscriptionId) async {
    try {
      await _subscriptionService.processCustomerPayment(
        subscriptionId: subscriptionId,
        amount: SubscriptionService.customerPricePerHour,
      );
      await _loadSubscriptionData();
      _showSuccessSnackBar('تم معالجة الدفع بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل معالجة الدفع');
    }
  }

  Future<void> _cancelCustomerSubscription(String subscriptionId) async {
    try {
      // Cancel subscription logic here
      await _loadSubscriptionData();
      _showSuccessSnackBar('تم إلغاء اشتراك الزبون');
    } catch (e) {
      _showErrorSnackBar('فشل إلغاء الاشتراك');
    }
  }

  Future<void> _processWithdrawal() async {
    if (_withdrawalAmount.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال المبلغ المطلوب');
      return;
    }
    
    try {
      final amount = double.parse(_withdrawalAmount);
      await _subscriptionService.processWithdrawal(
        merchantId: _auth.currentUser?.uid ?? '',
        amount: amount,
      );
      setState(() => _withdrawalAmount = '');
      await _loadSubscriptionData();
      _showSuccessSnackBar('تم معالجة طلب السحب بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل معالجة طلب السحب');
    }
  }

  Future<String?> _showAddCustomerDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إضافة زبون جديد',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'معرف الزبون',
            hintStyle: GoogleFonts.tajawal(
              color: Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              'إضافة',
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

  void _showCustomerDetails(CustomerSubscription customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تفاصيل الزبون',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'زبون: ${customer.customerId}',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تاريخ البدء: ${customer.startDate.day}/${customer.startDate.month}/${customer.startDate.year}',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الساعات النشطة: ${customer.activeHours}',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'المبلغ المدفوع: ${customer.formattedTotalPaid}',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'المتبقي: ${customer.formattedRemainingHours}',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الحالة: ${customer.meetsRequirement ? "يحقق الشروط" : "لم يحقق الشروط"}',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  color: customer.meetsRequirement ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
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
