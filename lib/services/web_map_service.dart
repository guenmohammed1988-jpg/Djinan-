import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart' if (dart.library.io) 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' if (dart.library.html) 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class WebMapService {
  static final WebMapService _instance = WebMapService._internal();
  factory WebMapService() => _instance;
  WebMapService._internal();

  bool get isWebPlatform => kIsWeb;

  // Get current position
  Future<Position?> getCurrentPosition() async {
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
      print('Error getting position: $e');
      return null;
    }
  }

  // Calculate distance between two points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = (dLat / 2).abs() * (dLat / 2).abs() +
              (_toRadians(lat1) * _toRadians(lat2) * (dLon / 2).abs() * (dLon / 2).abs());

    double c = 2 * _atan2(a.sqrt(), (1 - a).sqrt());

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  double _atan2(double a, double b) {
    return a == 0 ? 0 : a.sqrt() / b.sqrt();
  }

  // Create web-compatible map widget
  Widget createMap({
    required double latitude,
    required double longitude,
    required double zoom,
    List<Marker>? markers,
    Map<String, dynamic>? options,
  }) {
    if (kIsWeb) {
      return _createFlutterMap(
        latitude: latitude,
        longitude: longitude,
        zoom: zoom,
        markers: markers,
        options: options,
      );
    } else {
      return _createGoogleMap(
        latitude: latitude,
        longitude: longitude,
        zoom: zoom,
        markers: markers,
        options: options,
      );
    }
  }

  // Flutter Map for web
  Widget _createFlutterMap({
    required double latitude,
    required double longitude,
    required double zoom,
    List<Marker>? markers,
    Map<String, dynamic>? options,
  }) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(latitude, longitude),
        initialZoom: zoom,
        minZoom: 2.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          options: TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
        ),
        if (markers != null)
          MarkerLayer(
            markers: markers.map((marker) => _convertToFlutterMarker(marker)).toList(),
          ),
      ],
    );
  }

  // Google Maps for mobile
  Widget _createGoogleMap({
    required double latitude,
    required double longitude,
    required double zoom,
    List<Marker>? markers,
    Map<String, dynamic>? options,
  }) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(latitude, longitude),
        zoom: zoom,
      ),
      markers: markers ?? <Marker>{},
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }

  // Convert Google Maps marker to Flutter Map marker
  Marker _convertToFlutterMarker(Marker googleMarker) {
    return Marker(
      point: LatLng(googleMarker.position.latitude, googleMarker.position.longitude),
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(
          Icons.location_on,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // Open coordinates in web map
  Future<void> openCoordinatesInMap(double latitude, double longitude) async {
    if (kIsWeb) {
      final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      html.window.open(url, '_blank');
    }
  }

  // Get directions
  Future<void> getDirections(double startLat, double startLon, double endLat, double endLon) async {
    if (kIsWeb) {
      final url = 'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLon&destination=$endLat,$endLon';
      html.window.open(url, '_blank');
    }
  }
}

// Merchant location model for maps
class MerchantLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final String category;
  final String? imageUrl;
  final double? distance;

  MerchantLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.category,
    this.imageUrl,
    this.distance,
  });

  factory MerchantLocation.fromMap(Map<String, dynamic> map) {
    return MerchantLocation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      rating: (map['rating'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'],
      distance: map['distance']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'category': category,
      'imageUrl': imageUrl,
      'distance': distance,
    };
  }
}
