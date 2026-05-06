import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../services/video_upload_service.dart';
import '../services/merchant_service.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final VideoUploadService _uploadService = VideoUploadService();
  final MerchantService _merchantService = MerchantService();
  
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isCompressing = false;
  String? _uploadProgress;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _checkStoragePermission();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _checkStoragePermission() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      _showErrorSnackBar('تم رفض إذن الوصول إلى التخزين');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'رفع الفيديو',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFd4af37),
        foregroundColor: Colors.white,
        elevation: 0,
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
                // Video Preview Section
                if (_selectedVideo != null) _buildVideoPreview(),
                
                const SizedBox(height: 24),
                
                // Upload Button
                _buildUploadSection(),
                
                // Progress Section
                if (_isUploading || _isCompressing) _buildProgressSection(),
                
                // Error Message
                if (_errorMessage != null) _buildErrorMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معاينة الفيديو',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            
            // Video Player
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _videoController != null
                    ? FutureBuilder(
                        future: _initializeVideoPlayer(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            );
                          } else {
                            return Container(
                              height: 200,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFFd4af37),
                                ),
                              ),
                            );
                          }
                        },
                      )
                    : Container(
                        height: 200,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: const Color(0xFFd4af37),
                            size: 50,
                          ),
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Video Info
            FutureBuilder(
              future: _getVideoInfo(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final info = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('المدة', '${info.duration.inMinutes}:${(info.duration.inSeconds % 60).toString().padLeft(2, '0')}'),
                      _buildInfoRow('الحجم', _formatFileSize(info.fileSize)),
                      if (info.compressedSize != null)
                        _buildInfoRow('الحجم بعد الضغط', _formatFileSize(info.compressedSize!)),
                      _buildInfoRow('الجودة', _getQualityText(info.quality)),
                    ],
                  );
                } else {
                  return const SizedBox();
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Change Video Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: Text(
                  'تغيير الفيديو',
                  style: GoogleFonts.tajawal(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFd4af37),
                  minimumSize: const Size(double.infinity, 45),
                ),
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
        children: [
          Text(
            label,
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.tajawal(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات المتجر',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            
            // Store Name Input
            FutureBuilder(
              future: _getMerchantStoreName(),
              builder: (context, snapshot) {
                return TextField(
                  enabled: !_isUploading && !_isCompressing,
                  controller: TextEditingController(text: snapshot.data ?? ''),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'اسم المتجر',
                    labelStyle: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'سيتمت إضافة العلامة المائية تلقائيًا',
                    hintStyle: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.5),
                    ),
                    prefixIcon: const Icon(Icons.store, color: Color(0xFFd4af37)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading || _isCompressing ? null : _uploadVideo,
                icon: _isUploading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(
                  _isUploading 
                      ? 'جاري الرفع...'
                      : 'رفع الفيديو',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFd4af37),
                  minimumSize: const Size(double.infinity, 50),
                  disabledBackgroundColor: Colors.grey,
                  disabledForegroundColor: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isCompressing ? 'ضغط الفيديو...' : 'رفع الفيديو...',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFd4af37),
              ),
            ),
            const SizedBox(height: 16),
            
            // Progress Bar
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFd4af37)),
            ),
            
            const SizedBox(height: 8),
            
            // Progress Text
            Text(
              _uploadProgress != null 
                  ? '${(_uploadProgress * 100).toStringAsFixed(1)}% - $_uploadProgress'
                  : _uploadProgress ?? '',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            
            if (_uploadProgress != null) ...[
              const SizedBox(height: 8),
              Text(
                'حجم الملف: ${_formatFileSize(_selectedVideo!.length())}',
                style: GoogleFonts.tajawal(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: GoogleFonts.tajawal(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => setState(() => _errorMessage = null),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        // Check video duration
        final fileSize = await video.length();
        final tempFile = File(video.path);
        final duration = await _uploadService._getVideoDuration(tempFile);
        
        if (duration.inMinutes > 10) {
          _showErrorSnackBar('مدة الفيديو تتجوز الحد الأقصى المسموح به وهو 10 دقيقة');
          return;
        }
        
        setState(() {
          _selectedVideo = File(video.path);
          _videoController = VideoPlayerController.file(File(video.path));
          _errorMessage = null;
        });
        
        // Initialize video Player
        await _videoController!.initialize();
        setState(() {});
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ في اختيار الفيديو');
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedVideo == null) {
      _showErrorSnackBar('الرجاء اختيار فيديو أولاً');
      return;
    }

    setState(() {
      _isUploading = true;
      _isCompressing = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      // Get merchant store name
      final storeName = await _getMerchantStoreName();
      
      // Upload video with compression and watermarking
      final result = await _uploadService.uploadVideo(
        videoFile: _selectedVideo!,
        storeName: storeName,
        autoCompress: true,
      );

      setState(() {
        _isUploading = false;
        _isCompressing = false;
        _uploadProgress = null;
      });

      if (result.success) {
        _showSuccessSnackBar('تم رفع الفيديو بنجاح');
        
        // Navigate back or show success
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      } else {
        _showErrorSnackBar(result.errorMessage!);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _isCompressing = false;
        _uploadProgress = null;
      });
      _showErrorSnackBar('حدث خطأ في رفع الفيديو');
    }
  }

  Future<VideoPlayerController> _initializeVideoPlayer() async {
    if (_videoController != null) return _videoController!;
    
    await _videoController!.initialize();
    _videoController!.addListener(() {
      if (_videoController!.value.isInitialized) {
        final progress = _videoController!.value.position.inSeconds / 
                      _videoController!.value.duration.inSeconds;
        
        if (progress >= 0.98) { // 98% = 3 seconds before end
          setState(() => _uploadProgress = 98.0);
        } else if (progress >= 0.95) { // 95% = 3 seconds before end
          setState(() => _uploadProgress = 95.0);
        }
      }
    });
    
    _videoController!.play();
    _videoController!.setVolume(0.0);
    
    return _videoController;
  }

  Future<String?> _getMerchantStoreName() async {
    try {
      final merchantData = await _merchantService.getMerchantData();
      if (merchantData?.exists) {
        final data = merchantData.data() as Map<String, dynamic>;
        return data['storeName'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<VideoInfo?> _getVideoInfo() async {
    if (_selectedVideo == null) return null;
    
    try {
      final fileSize = await _selectedVideo!.length();
      final duration = await _uploadService._getVideoDuration(_selectedVideo!);
      
      return VideoInfo(
        fileSize: fileSize,
        duration: duration,
        quality: _uploadService._calculateQuality(duration),
      );
    } catch (e) {
      return null;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String _getQualityText(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return 'عالية (1080P)';
      case VideoQuality.medium:
        return 'متوسطة (720P)';
      case VideoQuality.low:
        return 'منخفضة (480P)';
      default:
        return 'غير محدد';
    }
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

// Video info class
class VideoInfo {
  final int fileSize;
  final Duration duration;
  final VideoQuality quality;

  VideoInfo({
    required this.fileSize,
    required this.duration,
    required this.quality,
  });
}
