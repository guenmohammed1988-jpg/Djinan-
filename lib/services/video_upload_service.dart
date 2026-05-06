import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_compress/video_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class VideoUploadService {
  static final VideoUploadService _instance = VideoUploadService._internal();
  factory VideoUploadService() => _instance;
  VideoUploadService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Constants
  static const int maxVideoDurationMinutes = 10;
  static const int targetQuality = 1080;
  static const String bucketName = 'djinnan_videos';
  static const String watermarkText = 'DJINAN';

  // Upload video to Firebase Storage
  Future<UploadResult> uploadVideo({
    required File videoFile,
    required String storeName,
    bool autoCompress = true,
  }) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return UploadResult.error('تم رفض إذن الوصول إلى التخزين');
      }

      // Check video duration
      final duration = await _getVideoDuration(videoFile);
      if (duration.inMinutes > maxVideoDurationMinutes) {
        return UploadResult.error('مدة الفيديو تتجوز الحد الأقصى المسموح به وهو ${maxVideoDurationMinutes} دقيقة');
      }

      // Get original video info
      final originalSize = await videoFile.length();
      final originalPath = videoFile.path;

      File? compressedFile;
      int? finalSize;

      if (autoCompress) {
        // Compress video
        final compressionResult = await _compressVideo(videoFile);
        if (compressionResult.success) {
          compressedFile = compressionResult.compressedFile;
          finalSize = await compressedFile.length();
        } else {
          return UploadResult.error(compressionResult.errorMessage!);
        }
      } else {
        compressedFile = videoFile;
        finalSize = originalSize;
      }

      // Upload to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$storeName.mp4';
      final ref = _storage.ref().child(bucketName).child(fileName);
      
      final uploadTask = ref.putFile(
        compressedFile!,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'storeName': storeName,
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalSize': originalSize.toString(),
            'compressedSize': finalSize.toString(),
            'duration': duration.inSeconds.toString(),
          },
        ),
      );

      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        // Save video metadata to Firestore
        await _firestore.collection('videos').add({
          'userId': _auth.currentUser?.uid,
          'storeName': storeName,
          'fileName': fileName,
          'downloadUrl': downloadUrl,
          'originalSize': originalSize,
          'compressedSize': finalSize,
          'duration': duration.inSeconds,
          'uploadedAt': FieldValue.serverTimestamp(),
          'isWatermarked': true,
          'isActive': true,
        });

        return UploadResult.success(
          downloadUrl: downloadUrl,
          fileSize: finalSize,
          compressionRatio: originalSize > 0 ? ((finalSize / originalSize) * 100).round() : 100,
        );
      } else {
        return UploadResult.error('فشل رفع الفيديو');
      }
    } catch (e) {
      return UploadResult.error('حدث خطأ غير متوقع: ${e.toString()}');
    }
  }

  // Get video duration
  Future<Duration> _getVideoDuration(File videoFile) async {
    try {
      final info = await VideoCompress.getMediaInfo(videoFile.path);
      if (info.duration != null) {
        return Duration(milliseconds: info.duration!.round());
      }
      return Duration.zero;
    } catch (e) {
      return Duration(minutes: maxVideoDurationMinutes + 1); // Return invalid duration to trigger error
    }
  }

  // Compress video to target quality
  Future<CompressionResult> _compressVideo(File videoFile) async {
    try {
      final originalDuration = await _getVideoDuration(videoFile);
      final originalSize = await videoFile.length();
      
      // Calculate compression parameters
      final targetBitrate = _calculateTargetBitrate(originalDuration);
      final quality = _calculateQuality(originalDuration);
      
      // Compress video
      final result = await VideoCompress.compressVideo(
        videoFile.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (result?.file != null) {
        final compressedSize = await result!.file!.length();
        final compressionRatio = (compressedSize / originalSize) * 100;
        
        // Check if compressed video meets quality requirements
        final compressedDuration = await _getVideoDuration(result.file!);
        final isQualityAcceptable = compressedDuration.inMinutes <= maxVideoDurationMinutes;
        
        return CompressionResult.success(
          compressedFile: result.file!,
          originalSize: originalSize,
          compressedSize: compressedSize,
          isQualityAcceptable: isQualityAcceptable,
          duration: compressedDuration,
        );
      } else {
        return CompressionResult.error('فشل ضغط الفيديو');
      }
    } catch (e) {
      return CompressionResult.error('خطأ في ضغط الفيديو: ${e.toString()}');
    }
  }

  // Calculate target bitrate for compression
  int _calculateTargetBitrate(Duration duration) {
    // Target 1080P quality with reasonable bitrate
    if (duration.inMinutes <= 5) {
      return 5000; // 5 Mbps for short videos
    } else if (duration.inMinutes <= 10) {
      return 3000; // 3 Mbps for medium videos
    } else {
      return 2000; // 2 Mbps for longer videos
    }
  }

  // Calculate video quality based on duration
  VideoQuality _calculateQuality(Duration duration) {
    if (duration.inMinutes <= 3) {
      return VideoQuality.high;
    } else if (duration.inMinutes <= 7) {
      return VideoQuality.medium;
    } else {
      return VideoQuality.low;
    }
  }

  // Get user videos from Firestore
  Future<List<VideoMetadata>> getUserVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        return VideoMetadata.fromFirestore(doc);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Delete video from Firebase Storage and Firestore
  Future<DeleteResult> deleteVideo(String videoId) async {
    try {
      // Get video metadata
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        return DeleteResult.error('الفيديو غير موجود');
      }

      final data = videoDoc.data() as Map<String, dynamic>;
      final fileName = data['fileName'];
      
      // Delete from Firestore
      await _firestore.collection('videos').doc(videoId).delete();
      
      // Delete from Firebase Storage
      if (fileName != null) {
        final ref = _storage.ref().child(bucketName).child(fileName);
        await ref.delete();
      }
      
      return DeleteResult.success();
    } catch (e) {
      return DeleteResult.error('حدث خطأ في حذف الفيديو');
    }
  }

  // Get storage usage statistics
  Future<StorageStats> getStorageStats() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .get();

      int totalSize = 0;
      int totalVideos = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalSize += (data['compressedSize'] ?? 0) as int;
        totalVideos++;
      }

      return StorageStats(
        totalSize: totalSize,
        totalVideos: totalVideos,
        averageSize: totalVideos > 0 ? (totalSize / totalVideos).round() : 0,
      );
    } catch (e) {
      return StorageStats(totalSize: 0, totalVideos: 0, averageSize: 0);
    }
  }
}

// Video quality enum
enum VideoQuality {
  high,
  medium,
  low,
}

// Upload result class
class UploadResult {
  final bool success;
  final String? downloadUrl;
  final int? fileSize;
  final int? compressionRatio;
  final String? errorMessage;

  UploadResult.success({
    this.downloadUrl,
    this.fileSize,
    this.compressionRatio,
  }) : success = true, errorMessage = null;

  UploadResult.error(this.errorMessage)
      : success = false, downloadUrl = null, fileSize = null, compressionRatio = null;
}

// Compression result class
class CompressionResult {
  final bool success;
  final File? compressedFile;
  final int? originalSize;
  final int? compressedSize;
  final bool? isQualityAcceptable;
  final Duration? duration;
  final String? errorMessage;

  CompressionResult.success({
    required this.compressedFile,
    required this.originalSize,
    required this.compressedSize,
    required this.isQualityAcceptable,
    required this.duration,
  }) : success = true, errorMessage = null;

  CompressionResult.error(this.errorMessage)
      : success = false, compressedFile = null, originalSize = null, 
        compressedSize = null, isQualityAcceptable = null, duration = null;
}

// Delete result class
class DeleteResult {
  final bool success;
  final String? errorMessage;

  DeleteResult.success() : success = true, errorMessage = null;
  DeleteResult.error(this.errorMessage) : success = false;
}

// Video metadata class
class VideoMetadata {
  final String id;
  final String userId;
  final String storeName;
  final String fileName;
  final String downloadUrl;
  final int originalSize;
  final int compressedSize;
  final int duration;
  final DateTime uploadedAt;
  final bool isWatermarked;
  final bool isActive;

  VideoMetadata({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.fileName,
    required this.downloadUrl,
    required this.originalSize,
    required this.compressedSize,
    required this.duration,
    required this.uploadedAt,
    required this.isWatermarked,
    required this.isActive,
  });

  factory VideoMetadata.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VideoMetadata(
      id: doc.id,
      userId: data['userId'] ?? '',
      storeName: data['storeName'] ?? '',
      fileName: data['fileName'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      originalSize: (data['originalSize'] ?? 0) as int,
      compressedSize: (data['compressedSize'] ?? 0) as int,
      duration: (data['duration'] ?? 0) as int,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isWatermarked: data['isWatermarked'] ?? false,
      isActive: data['isActive'] ?? true,
    );
  }
}

// Storage statistics class
class StorageStats {
  final int totalSize;
  final int totalVideos;
  final int averageSize;

  StorageStats({
    required this.totalSize,
    required this.totalVideos,
    required this.averageSize,
  });

  String getFormattedSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
