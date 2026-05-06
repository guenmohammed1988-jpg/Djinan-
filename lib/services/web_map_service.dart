import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlng;
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

    double a = math.pow(math.sin(dLat / 2), 2) +
              math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
              math.pow(math.sin(dLon / 2), 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Create web-compatible map widget
  Widget createMap({
    required double latitude,
    required double longitude,
    required double zoom,
    List<MerchantLocation>? locations,
    Map<String, dynamic>? options,
  }) {
    if (kIsWeb) {
      return _createFlutterMap(
        latitude: latitude,
        longitude: longitude,
        zoom: zoom,
        locations: locations,
        options: options,
      );
    } else {
      return _createGoogleMap(
        latitude: latitude,
        longitude: longitude,
        zoom: zoom,
        locations: locations,
        options: options,
      );
    }
  }

  // Flutter Map for web
  Widget _createFlutterMap({
    required double latitude,
    required double longitude,
    required double zoom,
    List<MerchantLocation>? locations,
    Map<String, dynamic>? options,
  }) {
    return flutter_map.FlutterMap(
      options: flutter_map.MapOptions(
        initialCenter: latlng.LatLng(latitude, longitude),
        initialZoom: zoom,
        minZoom: 2.0,
        maxZoom: 18.0,
      ),
      children: [
        flutter_map.TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.app',
        ),
        if (locations != null)
          flutter_map.MarkerLayer(
            markers: locations.map((location) => _createFlutterMarker(location)).toList(),
          ),
      ],
    );
  }

  // Google Maps for mobile
  Widget _createGoogleMap({
    required double latitude,
    required double longitude,
    required double zoom,
    List<MerchantLocation>? locations,
    Map<String, dynamic>? options,
  }) {
    final markers = <google_maps.Marker>{};
    
    if (locations != null) {
      for (final location in locations) {
        markers.add(_createGoogleMarker(location));
      }
    }

    return google_maps.GoogleMap(
      initialCameraPosition: google_maps.CameraPosition(
        target: google_maps.LatLng(latitude, longitude),
        zoom: zoom,
      ),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }

  // Create Flutter Map marker
  flutter_map.Marker _createFlutterMarker(MerchantLocation location) {
    return flutter_map.Marker(
      point: latlng.LatLng(location.latitude, location.longitude),
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

  // Create Google Maps marker
  google_maps.Marker _createGoogleMarker(MerchantLocation location) {
    return google_maps.Marker(
      markerId: google_maps.MarkerId(location.id),
      position: google_maps.LatLng(location.latitude, location.longitude),
      infoWindow: google_maps.InfoWindow(
        title: location.name,
        snippet: location.address,
      ),
      icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
        google_maps.BitmapDescriptor.hueRed,
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
