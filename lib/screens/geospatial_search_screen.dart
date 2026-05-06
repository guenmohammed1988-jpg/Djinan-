import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/geospatial_search_service.dart';

class GeospatialSearchScreen extends StatefulWidget {
  const GeospatialSearchScreen({super.key});

  @override
  State<GeospatialSearchScreen> createState() => _GeospatialSearchScreenState();
}

class _GeospatialSearchScreenState extends State<GeospatialSearchScreen> {
  final GeospatialSearchService _searchService = GeospatialSearchService();
  
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<MerchantLocation> _merchants = [];
  List<MerchantLocation> _filteredMerchants = [];
  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  double _searchRadius = 100.0;
  SearchStats? _searchStats;
  
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'الكل',
    'مطاعم',
    'ملابس',
    'إلكترونيات',
    'أثاث',
    'أدوات منزلية',
    'مستلزمات تجميل',
    'ألعاب',
    'كتب',
    'رياضة',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'بحث المتاجر القريبة',
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
              // Search Section
              _buildSearchSection(),
              
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

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'بحث عن متجر',
              labelStyle: GoogleFonts.tajawal(
                color: Colors.white.withOpacity(0.7),
              ),
              hintText: 'اكتب اسم المتجر...',
              hintStyle: GoogleFonts.tajawal(
                color: Colors.white.withOpacity(0.5),
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFd4af37)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFd4af37)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: GoogleFonts.tajawal(
              color: Colors.white,
            ),
            onChanged: _onSearchChanged,
          ),
          
          const SizedBox(height: 12),
          
          // Category Filter
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(
                      category,
                      style: GoogleFonts.tajawal(
                        color: isSelected ? const Color(0xFFd4af37) : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) => _onCategorySelected(category),
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
          
          // Search Radius Slider
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
        child: GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 12,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
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
                'جرب توسيع نطاق البحث أو تغيير الفئة',
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
          // Search Stats
          if (_searchStats != null) _buildSearchStats(),
          
          const SizedBox(height: 8),
          
          // Results List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredMerchants.length,
              itemBuilder: (context, index) {
                final merchant = _filteredMerchants[index];
                return _buildMerchantCard(merchant);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('المتاجر', '${_searchStats!.totalMerchants}'),
          _buildStatItem('نشطة', '${_searchStats!.activeMerchants}'),
          _buildStatItem('فئات', '${_searchStats!.uniqueCategories}'),
          _buildStatItem('متوسط المسافة', _searchStats!.formattedAverageDistance),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.tajawal(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantCard(MerchantLocation merchant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Store Logo
            Container(
              width: 60,
              height: 60,
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
                          size: 30,
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 30,
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
              icon: const Icon(Icons.directions),
              onPressed: () => _openDirections(merchant),
              color: const Color(0xFFd4af37),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocationAndSearch() async {
    setState(() => _isLoading = true);
    
    try {
      final position = await _searchService.getCurrentLocation();
      
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        
        await _searchNearbyMerchants();
        
        // Move map to current location
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 12,
              ),
            ),
          );
        }
      } else {
        _showErrorSnackBar('لا يمكن الوصول إلى موقعك الحالي');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ في الحصول على الموقع');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchNearbyMerchants() async {
    if (_currentPosition == null) return;
    
    setState(() => _isSearching = true);
    
    try {
      final merchants = await _searchService.searchStoresWithinRadius(
        centerLatitude: _currentPosition!.latitude,
        centerLongitude: _currentPosition!.longitude,
        radiusKm: _searchRadius,
      );
      
      final stats = await _searchService.getSearchStats(
        centerLatitude: _currentPosition!.latitude,
        centerLongitude: _currentPosition!.longitude,
        radiusKm: _searchRadius,
      );
      
      setState(() {
        _merchants = merchants;
        _filteredMerchants = merchants;
        _searchStats = stats;
        _isSearching = false;
      });
      
      _updateMapMarkers();
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorSnackBar('حدث خطأ في البحث عن المتاجر');
    }
  }

  void _updateMapMarkers() {
    if (_currentPosition == null) return;
    
    final markers = _searchService.createMerchantMarkers(
      merchants: _filteredMerchants,
      onMarkerTap: (merchantId) => _showMerchantDetails(merchantId),
    );
    
    // Add current location marker
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        infoWindow: const InfoWindow(title: 'موقعك الحالي'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
    
    setState(() => _markers = markers);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterMerchants();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filterMerchants();
    });
  }

  void _onRadiusChanged(double radius) {
    setState(() {
      _searchRadius = radius;
    });
    _searchNearbyMerchants();
  }

  void _filterMerchants() {
    var filtered = _merchants;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((merchant) =>
        merchant.storeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        merchant.username.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Filter by category
    if (_selectedCategory != 'الكل') {
      filtered = filtered.where((merchant) =>
        merchant.categories.contains(_selectedCategory)
      ).toList();
    }
    
    setState(() => _filteredMerchants = filtered);
    _updateMapMarkers();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filterMerchants();
    });
  }

  void _refreshSearch() {
    _getCurrentLocationAndSearch();
  }

  void _showMerchantDetails(String merchantId) {
    // Navigate to merchant details screen
    // You can implement this navigation
  }

  void _openDirections(MerchantLocation merchant) {
    // Open Google Maps with directions
    // You can implement this using url_launcher
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
