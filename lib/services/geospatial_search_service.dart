import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeospatialSearchService {
  static final GeospatialSearchService _instance = GeospatialSearchService._internal();
  factory GeospatialSearchService() => _instance;
  GeospatialSearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeoFlutterFire _geo = GeoFlutterFire();
  
  // Constants
  static const double searchRadiusKm = 100.0;
  static const String merchantsCollection = 'merchants';
  static const String geoCollection = 'merchants_geo';

  // Get current user location
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  // Search stores within 100km radius
  Future<List<MerchantLocation>> searchStoresWithinRadius({
    required double centerLatitude,
    required double centerLongitude,
    double radiusKm = searchRadiusKm,
  }) async {
    try {
      // Create GeoFirePoint for center location
      final center = _geo.point(latitude: centerLatitude, longitude: centerLongitude);
      
      // Create a collection reference
      final collectionRef = _firestore.collection(merchantsCollection);
      
      // Query for merchants within radius
      final stream = _geo.collection(collectionRef: collectionRef)
          .within(center: center, radius: radiusKm, field: 'location');
      
      // Get results
      final results = await stream.first;
      
      // Convert to MerchantLocation objects
      final merchants = <MerchantLocation>[];
      for (final doc in results) {
        final data = doc.data() as Map<String, dynamic>;
        final geoPoint = data['location']['geopoint'] as GeoPoint;
        
        merchants.add(MerchantLocation(
          id: doc.id,
          storeName: data['storeName'] ?? '',
          username: data['username'] ?? '',
          phone: data['phone'] ?? '',
          address: data['location']['address'] ?? '',
          latitude: geoPoint.latitude,
          longitude: geoPoint.longitude,
          distance: _calculateDistance(
            centerLatitude,
            centerLongitude,
            geoPoint.latitude,
            geoPoint.longitude,
          ),
          isActive: data['isActive'] ?? false,
          profileCompletion: (data['profileCompletion'] ?? 0.0).toDouble(),
          rating: (data['rating'] ?? 0.0).toDouble(),
          totalRatings: (data['totalRatings'] ?? 0) as int,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          categories: List<String>.from(data['categories'] ?? []),
          description: data['description'] ?? '',
          logo: data['logo'],
          website: data['website'],
          instagram: data['instagram'],
          twitter: data['twitter'],
        ));
      }
      
      // Sort by distance
      merchants.sort((a, b) => a.distance.compareTo(b.distance));
      
      return merchants;
    } catch (e) {
      return [];
    }
  }

  // Search stores near current location
  Future<List<MerchantLocation>> searchNearbyStores({double radiusKm = searchRadiusKm}) async {
    final position = await getCurrentLocation();
    if (position == null) {
      return [];
    }

    return await searchStoresWithinRadius(
      centerLatitude: position.latitude,
      centerLongitude: position.longitude,
      radiusKm: radiusKm,
    );
  }

  // Calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Update merchant location in Firestore
  Future<void> updateMerchantLocation({
    required String merchantId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      // Create GeoFirePoint
      final geoPoint = _geo.point(latitude: latitude, longitude: longitude);
      
      // Update merchant document with location
      await _firestore.collection(merchantsCollection).doc(merchantId).update({
        'location': {
          'geopoint': geoPoint.data,
          'address': address,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update merchant location: $e');
    }
  }

  // Get merchant by ID with location
  Future<MerchantLocation?> getMerchantById(String merchantId) async {
    try {
      final doc = await _firestore.collection(merchantsCollection).doc(merchantId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      final locationData = data['location'] as Map<String, dynamic>?;
      
      if (locationData == null) {
        return null;
      }

      final geoPoint = locationData['geopoint'] as GeoPoint?;
      
      if (geoPoint == null) {
        return null;
      }

      return MerchantLocation(
        id: doc.id,
        storeName: data['storeName'] ?? '',
        username: data['username'] ?? '',
        phone: data['phone'] ?? '',
        address: locationData['address'] ?? '',
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
        distance: 0.0,
        isActive: data['isActive'] ?? false,
        profileCompletion: (data['profileCompletion'] ?? 0.0).toDouble(),
        rating: (data['rating'] ?? 0.0).toDouble(),
        totalRatings: (data['totalRatings'] ?? 0) as int,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        categories: List<String>.from(data['categories'] ?? []),
        description: data['description'] ?? '',
        logo: data['logo'],
        website: data['website'],
        instagram: data['instagram'],
        twitter: data['twitter'],
      );
    } catch (e) {
      return null;
    }
  }

  // Search stores by category within radius
  Future<List<MerchantLocation>> searchStoresByCategory({
    required double centerLatitude,
    required double centerLongitude,
    required String category,
    double radiusKm = searchRadiusKm,
  }) async {
    try {
      final merchants = await searchStoresWithinRadius(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusKm: radiusKm,
      );
      
      // Filter by category
      return merchants.where((merchant) => 
        merchant.categories.contains(category)
      ).toList();
    } catch (e) {
      return [];
    }
  }

  // Search stores by name within radius
  Future<List<MerchantLocation>> searchStoresByName({
    required double centerLatitude,
    required double centerLongitude,
    required String searchTerm,
    double radiusKm = searchRadiusKm,
  }) async {
    try {
      final merchants = await searchStoresWithinRadius(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusKm: radiusKm,
      );
      
      // Filter by name (case-insensitive)
      final searchLower = searchTerm.toLowerCase();
      return merchants.where((merchant) => 
        merchant.storeName.toLowerCase().contains(searchLower) ||
        merchant.username.toLowerCase().contains(searchLower)
      ).toList();
    } catch (e) {
      return [];
    }
  }

  // Get nearest stores within radius
  Future<List<MerchantLocation>> getNearestStores({
    required double centerLatitude,
    required double centerLongitude,
    double radiusKm = searchRadiusKm,
    int limit = 20,
  }) async {
    try {
      final merchants = await searchStoresWithinRadius(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusKm: radiusKm,
      );
      
      // Filter active stores and sort by distance
      final activeMerchants = merchants.where((m) => m.isActive).toList();
      activeMerchants.sort((a, b) => a.distance.compareTo(b.distance));
      
      return activeMerchants.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Get highest rated stores within radius
  Future<List<MerchantLocation>> getHighestRatedStores({
    required double centerLatitude,
    required double centerLongitude,
    double radiusKm = searchRadiusKm,
    int limit = 20,
  }) async {
    try {
      final merchants = await searchStoresWithinRadius(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusKm: radiusKm,
      );
      
      // Filter active stores and sort by rating
      final activeMerchants = merchants.where((m) => m.isActive).toList();
      activeMerchants.sort((a, b) => b.rating.compareTo(a.rating));
      
      return activeMerchants.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Get TOP 100 merchants globally
  Future<List<MerchantLocation>> getTop100Merchants() async {
    try {
      // Get all active merchants from Firestore
      final snapshot = await _firestore
          .collection(merchantsCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(100)
          .get();

      final merchants = <MerchantLocation>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final locationData = data['location'] as Map<String, dynamic>?;
        
        if (locationData != null) {
          final geoPoint = locationData['geopoint'] as GeoPoint?;
          
          if (geoPoint != null) {
            merchants.add(MerchantLocation(
              id: doc.id,
              storeName: data['storeName'] ?? '',
              username: data['username'] ?? '',
              phone: data['phone'] ?? '',
              address: locationData['address'] ?? '',
              latitude: geoPoint.latitude,
              longitude: geoPoint.longitude,
              distance: 0.0,
              isActive: data['isActive'] ?? false,
              profileCompletion: (data['profileCompletion'] ?? 0.0).toDouble(),
              rating: (data['rating'] ?? 0.0).toDouble(),
              totalRatings: (data['totalRatings'] ?? 0) as int,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              categories: List<String>.from(data['categories'] ?? []),
              description: data['description'] ?? '',
              logo: data['logo'],
              website: data['website'],
              instagram: data['instagram'],
              twitter: data['twitter'],
            ));
          }
        }
      }
      
      return merchants;
    } catch (e) {
      return [];
    }
  }

  // Get popular stores within radius (sorted by profile completion)
  Future<List<MerchantLocation>> getPopularStores({
    required double centerLatitude,
    required double centerLongitude,
    double radiusKm = searchRadiusKm,
    int limit = 10,
  }) async {
    try {
      final merchants = await searchStoresWithinRadius(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusKm: radiusKm,
      );
      
      // Filter active stores and sort by profile completion
      final activeMerchants = merchants.where((m) => m.isActive).toList();
      activeMerchants.sort((a, b) => b.profileCompletion.compareTo(a.profileCompletion));
      
      return activeMerchants.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Add rating to merchant
  Future<void> addMerchantRating({
    required String merchantId,
    required double rating,
    required String userId,
  }) async {
    try {
      final merchantRef = _firestore.collection(merchantsCollection).doc(merchantId);
      
      // Use a transaction to safely update ratings
      await _firestore.runTransaction((transaction) async {
        final merchantDoc = await transaction.get(merchantRef);
        
        if (!merchantDoc.exists) {
          throw Exception('Merchant not found');
        }
        
        final data = merchantDoc.data() as Map<String, dynamic>;
        final currentRating = (data['rating'] ?? 0.0) as double;
        final totalRatings = (data['totalRatings'] ?? 0) as int;
        
        // Calculate new average rating
        final newTotalRatings = totalRatings + 1;
        final newRating = ((currentRating * totalRatings) + rating) / newTotalRatings;
        
        // Update merchant rating
        transaction.update(merchantRef, {
          'rating': newRating,
          'totalRatings': newTotalRatings,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Add rating record
        transaction.set(
          _firestore.collection('merchant_ratings').doc(),
          {
            'merchantId': merchantId,
            'userId': userId,
            'rating': rating,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });
    } catch (e) {
      throw Exception('Failed to add rating: $e');
    }
  }

  // Get user's rating for a merchant
  Future<double?> getUserRatingForMerchant({
    required String merchantId,
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('merchant_ratings')
          .where('merchantId', isEqualTo: merchantId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        return (data['rating'] ?? 0.0) as double;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Create Google Maps markers for merchants
  Set<Marker> createMerchantMarkers({
    required List<MerchantLocation> merchants,
    required Function(String) onMarkerTap,
    BitmapDescriptor? customIcon,
  }) {
    final Set<Marker> markers = {};
    
    for (final merchant in merchants) {
      final marker = Marker(
        markerId: MarkerId(merchant.id),
        position: LatLng(merchant.latitude, merchant.longitude),
        infoWindow: InfoWindow(
          title: merchant.storeName,
          snippet: '${merchant.distance.toStringAsFixed(1)} km • ${merchant.username}',
        ),
        icon: customIcon ?? BitmapDescriptor.defaultMarkerWithHue(
          merchant.isActive ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        onTap: () => onMarkerTap(merchant.id),
      );
      
      markers.add(marker);
    }
    
    return markers;
  }

  // Get search statistics
  Future<SearchStats> getSearchStats({
    required double centerLatitude,
    required double centerLongitude,
    double radiusKm = searchRadiusKm,
  }) async {
    try {
      final merchants = await searchStoresWithinRadius(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusKm: radiusKm,
      );
      
      final activeMerchants = merchants.where((m) => m.isActive).toList();
      final categories = <String>{};
      
      for (final merchant in merchants) {
        categories.addAll(merchant.categories);
      }
      
      return SearchStats(
        totalMerchants: merchants.length,
        activeMerchants: activeMerchants.length,
        uniqueCategories: categories.length,
        averageDistance: merchants.isNotEmpty 
            ? merchants.map((m) => m.distance).reduce((a, b) => a + b) / merchants.length
            : 0.0,
        searchRadius: radiusKm,
      );
    } catch (e) {
      return SearchStats(
        totalMerchants: 0,
        activeMerchants: 0,
        uniqueCategories: 0,
        averageDistance: 0.0,
        searchRadius: radiusKm,
      );
    }
  }
}

// Merchant location model
class MerchantLocation {
  final String id;
  final String storeName;
  final String username;
  final String phone;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;
  final bool isActive;
  final double profileCompletion;
  final double rating;
  final int totalRatings;
  final DateTime createdAt;
  final List<String> categories;
  final String description;
  final String? logo;
  final String? website;
  final String? instagram;
  final String? twitter;

  MerchantLocation({
    required this.id,
    required this.storeName,
    required this.username,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.isActive,
    required this.profileCompletion,
    this.rating = 0.0,
    this.totalRatings = 0,
    required this.createdAt,
    required this.categories,
    required this.description,
    this.logo,
    this.website,
    this.instagram,
    this.twitter,
  });

  // Get formatted distance string
  String get formattedDistance {
    if (distance < 1.0) {
      return '${(distance * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  // Get completion percentage
  String get completionPercentage {
    return '${profileCompletion.toStringAsFixed(0)}%';
  }

  // Check if store is open (simplified - you can add actual hours logic)
  bool get isOpen {
    // This is a simplified check - you can add actual business hours logic
    return isActive;
  }
}

// Search statistics model
class SearchStats {
  final int totalMerchants;
  final int activeMerchants;
  final int uniqueCategories;
  final double averageDistance;
  final double searchRadius;

  SearchStats({
    required this.totalMerchants,
    required this.activeMerchants,
    required this.uniqueCategories,
    required this.averageDistance,
    required this.searchRadius,
  });

  // Get formatted average distance
  String get formattedAverageDistance {
    if (averageDistance < 1.0) {
      return '${(averageDistance * 1000).toStringAsFixed(0)} m';
    } else {
      return '${averageDistance.toStringAsFixed(1)} km';
    }
  }

  // Get search area
  double get searchArea {
    return pi * searchRadius * searchRadius;
  }

  // Get merchant density
  double get merchantDensity {
    return searchArea > 0 ? totalMerchants / searchArea : 0.0;
  }
}
