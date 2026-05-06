import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/geospatial_search_service.dart';
import '../services/web_map_service.dart';

class EnhancedMapsScreen extends StatefulWidget {
  const EnhancedMapsScreen({super.key});

  @override
  State<EnhancedMapsScreen> createState() => _EnhancedMapsScreenState();
}

class _EnhancedMapsScreenState extends State<EnhancedMapsScreen> {
  final GeospatialSearchService _searchService = GeospatialSearchService();
  
  Position? _currentPosition;
  List<MerchantLocation> _merchants = [];
  List<MerchantLocation> _filteredMerchants = [];
  bool _isLoading = false;
  String _selectedFilter = 'الأقرب';
  double _searchRadius = 100.0;
  
  final List<String> _filterOptions = [
    'الأقرب',
    'الأعلى تقييما',
    'TOP 100',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndSearch();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'خريطة المتاجر',
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
            onPressed: _refreshSearch,
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
              // Filter Section
              _buildFilterSection(),
              
              // Map Section
              Expanded(
                flex: 2,
                child: _buildMapSection(),
              ),
              
              // Results Section
              Expanded(
                flex: 3,
                child: _buildResultsSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filter Options
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = _selectedFilter == filter;
                
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: GoogleFonts.tajawal(
                        color: isSelected ? const Color(0xFFd4af37) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) => _onFilterSelected(filter),
                    backgroundColor: Colors.white.withOpacity(0.2),
                    selectedColor: Colors.white,
                    checkmarkColor: const Color(0xFFd4af37),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Search Radius Slider (for nearest and highest rated)
          if (_selectedFilter != 'TOP 100')
            Row(
              children: [
                Text(
                  'نطاق البحث: ${_searchRadius.toStringAsFixed(0)} كم',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _searchRadius,
                    min: 10.0,
                    max: 200.0,
                    divisions: 19,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                    onChanged: _onRadiusChanged,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    if (_currentPosition == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'لا يمكن الوصول إلى موقعك الحالي',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الرجاء تفعيل خدمة الموقع والمحاولة مرة أخرى',
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _getCurrentLocationAndSearch,
                icon: const Icon(Icons.my_location),
                label: Text(
                  'إعادة المحاولة',
                  style: GoogleFonts.tajawal(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFd4af37),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Map Placeholder (since Google Maps isn't available)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.map,
                      color: Color(0xFFd4af37),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'خريطة المتاجر',
                      style: GoogleFonts.tajawal(
                        color: const Color(0xFFd4af37),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_filteredMerchants.length} متجر في نطاق البحث',
                      style: GoogleFonts.tajawal(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Current Location Indicator
              if (_currentPosition != null)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              
              // Filter Info
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd4af37).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedFilter,
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_filteredMerchants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.store,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد متاجر في هذا النطاق',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'جرب تغيير الفلتر أو توسيع نطاق البحث',
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Results Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'النتائج: ${_filteredMerchants.length}',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _selectedFilter,
                  style: GoogleFonts.tajawal(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Results List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredMerchants.length,
              itemBuilder: (context, index) {
                final merchant = _filteredMerchants[index];
                return _buildMerchantCard(merchant, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(MerchantLocation merchant, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getRankColor(rank),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  rank <= 3 ? '#$rank' : '$rank',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: rank <= 3 ? 16 : 12,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Store Logo
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFd4af37),
                borderRadius: BorderRadius.circular(8),
              ),
              child: merchant.logo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: merchant.logo!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 25,
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 25,
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // Store Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchant.storeName,
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFd4af37),
                          ),
                        ),
                      ),
                      if (merchant.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'نشط',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${merchant.username}',
                    style: GoogleFonts.tajawal(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Rating Stars
                      if (_selectedFilter == 'الأعلى تقييما' || _selectedFilter == 'TOP 100')
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
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${merchant.totalRatings})',
                              style: GoogleFonts.tajawal(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      
                      // Distance (for nearest)
                      if (_selectedFilter == 'الأقرب') ...[
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFd4af37),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          merchant.formattedDistance,
                          style: GoogleFonts.tajawal(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                      
                      // Completion (for popular)
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.star,
                        color: Color(0xFFd4af37),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        merchant.completionPercentage,
                        style: GoogleFonts.tajawal(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (merchant.categories.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: merchant.categories.take(2).map((category) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFd4af37).withOpacity(0.1),
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
                ],
              ),
            ),
            
            // Action Button
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showMerchantDetails(merchant),
              color: const Color(0xFFd4af37),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return Colors.grey[400]!; // Silver
      case 3:
        return Colors.brown[300]!; // Bronze
      default:
        return const Color(0xFFd4af37);
    }
  }

  Future<void> _getCurrentLocationAndSearch() async {
    setState(() => _isLoading = true);
    
    try {
      final position = await _searchService.getCurrentLocation();
      
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        
        await _searchMerchants();
      } else {
        _showErrorSnackBar('لا يمكن الوصول إلى موقعك الحالي');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ في الحصول على الموقع');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchMerchants() async {
    if (_currentPosition == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      List<MerchantLocation> merchants = [];
      
      switch (_selectedFilter) {
        case 'الأقرب':
          merchants = await _searchService.getNearestStores(
            centerLatitude: _currentPosition!.latitude,
            centerLongitude: _currentPosition!.longitude,
            radiusKm: _searchRadius,
            limit: 50,
          );
          break;
        case 'الأعلى تقييما':
          merchants = await _searchService.getHighestRatedStores(
            centerLatitude: _currentPosition!.latitude,
            centerLongitude: _currentPosition!.longitude,
            radiusKm: _searchRadius,
            limit: 50,
          );
          break;
        case 'TOP 100':
          merchants = await _searchService.getTop100Merchants();
          break;
      }
      
      setState(() {
        _merchants = merchants;
        _filteredMerchants = merchants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('حدث خطأ في البحث عن المتاجر');
    }
  }

  void _onFilterSelected(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _searchMerchants();
  }

  void _onRadiusChanged(double radius) {
    setState(() {
      _searchRadius = radius;
    });
    _searchMerchants();
  }

  void _refreshSearch() {
    _getCurrentLocationAndSearch();
  }

  void _showMerchantDetails(MerchantLocation merchant) {
    // Navigate to merchant details screen
    // You can implement this navigation
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
