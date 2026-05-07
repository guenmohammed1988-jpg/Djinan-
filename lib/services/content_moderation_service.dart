import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Content moderation constants
  static const String contentCollection = 'content_moderation';
  static const String reportsCollection = 'content_reports';
  static const String flaggedContentCollection = 'flagged_content';
  static const String moderationQueueCollection = 'moderation_queue';
  
  // Content analysis endpoints
  static const String visionApiUrl = 'https://vision.googleapis.com/v1';
  static const String visionApiKey = 'AIzaSyB...'; // Replace with actual API key
  
  // Content categories
  static const Map<String, List<String>> contentCategories = {
    'violence': ['weapons', 'violence', 'hate_speech', 'self_harm'],
    'adult_content': ['nudity', 'sexual_content', 'explicit_material'],
    'inappropriate': ['spam', 'scams', 'fraud', 'misinformation'],
    'copyright': ['copyright_violation', 'trademark_infringement'],
    'hate_speech': ['racism', 'discrimination', 'harassment'],
    'spam': ['excessive_links', 'repetitive_content', 'misleading_content'],
  };

  // Analyze content using Google Vision API
  Future<ContentAnalysis> analyzeContent({
    required String content,
    String? imageUrl,
    String? videoUrl,
  }) async {
    try {
      // Prepare analysis request
      final requestBody = {
        'requests': [
          {
            'image': imageUrl != null ? {
              'source': {
                'imageUri': imageUrl,
              },
              'features': [
                'SAFE_SEARCH',
                'LABEL_DETECTION',
                'WEB_DETECTION',
                'OBJECT_LOCALIZATION',
              ],
            },
            'text': {
              'text': content,
            },
          },
          if (videoUrl != null) ...[
            {
              'video': {
                'source': {
                  'videoUri': videoUrl,
                },
                'features': [
                  'SAFE_SEARCH',
                  'LABEL_DETECTION',
                  'WEB_DETECTION',
                  'OBJECT_LOCALIZATION',
                ],
              },
            },
          ],
        ],
        'features': [
          'EXPLICIT_CONTENT_DETECTION',
          'ADULT_CONTENT_DETECTION',
          'VIOLENCE_DETECTION',
          'RACY_DETECTION',
          'MEDICAL_DETECTION',
          'SPOOF_DETECTION',
          'WEAPON_DETECTION',
          'DRUG_DETECTION',
          'ALCOHOL_DETECTION',
        ],
      };
      
      // Make API request
      final response = await http.post(
        Uri.parse('$visionApiUrl/images:annotate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $visionApiKey',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final responses = responseData['responses'] as List;
        
        if (responses.isNotEmpty) {
          final analysis = responses.first;
          return ContentAnalysis(
            isExplicit: analysis['explicitAnnotation']?.contains('VERY_LIKELY') ?? false,
            isAdult: analysis['adult']?.contains('VERY_LIKELY') ?? false,
            isViolent: analysis['violence']?.contains('VERY_LIKELY') ?? false,
            isRacy: analysis['racy']?.contains('VERY_LIKELY') ?? false,
            containsWeapons: analysis['weapon']?.contains('VERY_LIKELY') ?? false,
            containsHate: analysis['hate']?.contains('VERY_LIKELY') ?? false,
            isSpam: analysis['spam']?.contains('VERY_LIKELY') ?? false,
            isCopyright: analysis['copyright']?.contains('VERY_LIKELY') ?? false,
            isMisinformation: analysis['medical']?.contains('VERY_LIKELY') ?? false,
            confidence: double.tryParse(analysis['explicitAnnotation']?.toString() ?? '0.0') ?? 0.0,
            labels: _extractLabels(analysis),
            detectedObjects: _extractDetectedObjects(analysis),
            detectedText: _extractDetectedText(analysis),
            detectedFaces: _extractDetectedFaces(analysis),
            detectedLogos: _extractDetectedLogos(analysis),
            detectedWebEntities: _extractWebEntities(analysis),
            analysisTimestamp: DateTime.now(),
          );
        }
      }
      
      throw Exception('Content analysis failed');
    } catch (e) {
      throw Exception('Content analysis error: $e');
    }
  }

  // Flag inappropriate content
  Future<void> flagContent({
    required String contentId,
    required String reason,
    String? description,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      await _firestore.collection(flaggedContentCollection).add({
        'contentId': contentId,
        'userId': userId,
        'reason': reason,
        'description': description,
        'additionalData': additionalData,
        'flaggedAt': FieldValue.serverTimestamp(),
        'status': 'flagged',
        'reviewStatus': 'pending_review',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Add to moderation queue
      await _firestore.collection(moderationQueueCollection).add({
        'contentId': contentId,
        'userId': userId,
        'action': 'flag_content',
        'reason': reason,
        'description': description,
        'additionalData': additionalData,
        'queuedAt': FieldValue.serverTimestamp(),
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update content status
      await _firestore.collection(contentCollection).doc(contentId).update({
        'moderationStatus': 'flagged',
        'flaggedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to flag content: $e');
    }
  }

  // Get flagged content for review
  Future<List<FlaggedContent>> getFlaggedContent({int limit = 50}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection(flaggedContentCollection)
          .where('reviewStatus', isEqualTo: 'pending_review')
          .orderBy('flaggedAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return FlaggedContent(
          id: doc.id,
          contentId: data['contentId'] ?? '',
          userId: data['userId'] ?? '',
          reason: data['reason'] ?? '',
          description: data['description'] ?? '',
          flaggedAt: (data['flaggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          reviewStatus: data['reviewStatus'] ?? 'pending_review',
          additionalData: data['additionalData'] ?? {},
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Review flagged content
  Future<void> reviewFlaggedContent({
    required String contentId,
    required String reviewAction,
    String? reviewNotes,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Update flagged content status
      await _firestore.collection(flaggedContentCollection).doc(contentId).update({
        'reviewStatus': reviewAction,
        'reviewNotes': reviewNotes,
        'reviewedBy': userId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove from moderation queue
      await _firestore
          .collection(moderationQueueCollection)
          .where('contentId', isEqualTo: contentId)
          .where('action', isEqualTo: 'flag_content')
          .get()
          .then((querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              await doc.reference.delete();
            }
          });
      
      // Log review action
      await _firestore.collection(reportsCollection).add({
        'contentId': contentId,
        'userId': userId,
        'action': 'review_completed',
        'reviewAction': reviewAction,
        'reviewNotes': reviewNotes,
        'reviewedBy': userId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to review flagged content: $e');
    }
  }

  // Get moderation queue
  Future<List<ModerationQueueItem>> getModerationQueue({int limit = 100}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection(moderationQueueCollection)
          .where('status', isEqualTo: 'queued')
          .orderBy('queuedAt', descending: false)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ModerationQueueItem(
          id: doc.id,
          contentId: data['contentId'] ?? '',
          userId: data['userId'] ?? '',
          action: data['action'] ?? '',
          reason: data['reason'] ?? '',
          description: data['description'] ?? '',
          queuedAt: (data['queuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? 'queued',
          additionalData: data['additionalData'] ?? {},
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Process moderation queue
  Future<void> processModerationQueue() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final snapshot = await _firestore
          .collection(moderationQueueCollection)
          .where('status', isEqualTo: 'queued')
          .orderBy('queuedAt', descending: false)
          .limit(10)
          .get();
      
      if (snapshot.empty) return;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final contentId = data['contentId'];
        final action = data['action'];
        
        switch (action) {
          case 'flag_content':
            await _processFlaggedContent(
              contentId: contentId!,
              reason: data['reason'] ?? 'auto_flagged',
            );
            break;
          case 'delete_content':
            await _deleteContent(contentId!);
            break;
          case 'approve_content':
            await _approveContent(contentId!);
            break;
          case 'reject_content':
            await _rejectContent(
              contentId: contentId!,
              reason: data['reason'] ?? 'rejected_by_moderator',
              reviewNotes: data['reviewNotes'],
            );
            break;
        }
        
        // Update queue item status
        await doc.reference.update({
          'status': 'processing',
          'processedAt': FieldValue.serverTimestamp(),
        });
        
        // Remove from queue after processing
        await doc.reference.delete();
      }
    } catch (e) {
      // Handle error
    }
  }

  // Delete content
  Future<void> deleteContent(String contentId) async {
    await _deleteContent(contentId);
  }

  Future<void> _deleteContent(String contentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Get content details
      final contentDoc = await _firestore.collection(contentCollection).doc(contentId).get();
      if (!contentDoc.exists) return;
      
      final contentData = contentDoc.data() as Map<String, dynamic>;
      
      // Delete from flagged content
      await _firestore.collection(flaggedContentCollection).doc(contentId).delete();
      
      // Delete from moderation queue
      await _firestore
          .collection(moderationQueueCollection)
          .where('contentId', isEqualTo: contentId)
          .get()
          .then((querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              await doc.reference.delete();
            }
          });
      
      // Log deletion
      await _firestore.collection(reportsCollection).add({
        'contentId': contentId,
        'userId': userId,
        'action': 'content_deleted',
        'reason': 'moderator_action',
        'description': 'Content deleted by moderator',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // If content has media files, delete them too
      if (contentData['imageUrl'] != null) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(contentData['imageUrl']);
          await ref.delete();
        } catch (e) {
          // Handle error
        }
      }
      
      if (contentData['videoUrl'] != null) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(contentData['videoUrl']);
          await ref.delete();
        } catch (e) {
          // Handle error
        }
      }
    } catch (e) {
      throw Exception('Failed to delete content: $e');
    }
  }

  // Approve content
  Future<void> _approveContent(String contentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Update content status to approved
      await _firestore.collection(contentCollection).doc(contentId).update({
        'moderationStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove from moderation queue
      await _firestore
          .collection(moderationQueueCollection)
          .where('contentId', isEqualTo: contentId)
          .get()
          .then((querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              await doc.reference.delete();
            }
          });
      
      // Log approval
      await _firestore.collection(reportsCollection).add({
        'contentId': contentId,
        'userId': userId,
        'action': 'content_approved',
        'description': 'Content approved by moderator',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to approve content: $e');
    }
  }

  // Reject content
  Future<void> _rejectContent({
    required String contentId,
    required String reason,
    String? reviewNotes,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Update content status to rejected
      await _firestore.collection(contentCollection).doc(contentId).update({
        'moderationStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': userId,
        'rejectionReason': reason,
        'reviewNotes': reviewNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove from moderation queue
      await _firestore
          .collection(moderationQueueCollection)
          .where('contentId', isEqualTo: contentId)
          .get()
          .then((querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              await doc.reference.delete();
            }
          });
      
      // Log rejection
      await _firestore.collection(reportsCollection).add({
        'contentId': contentId,
        'userId': userId,
        'action': 'content_rejected',
        'reason': reason,
        'reviewNotes': reviewNotes,
        'description': 'Content rejected by moderator',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reject content: $e');
    }
  }

  // Get moderation statistics
  Future<ModerationStats> getModerationStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return ModerationStats(
        totalFlagged: 0,
        queueSize: 0,
        totalReports: 0,
        autoFlagged: 0,
        manuallyFlagged: 0,
        processedToday: 0,
        period: '30_days',
      );
      
      final now = DateTime.now();
      final thirtyDaysAgo = DateTime(now.year, now.month, now.day - 30);
      
      // Get flagged content stats
      final flaggedSnapshot = await _firestore
          .collection(flaggedContentCollection)
          .where('flaggedAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();
      
      // Get moderation queue stats
      final queueSnapshot = await _firestore
          .collection(moderationQueueCollection)
          .where('queuedAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();
      
      // Get reports stats
      final reportsSnapshot = await _firestore
          .collection(reportsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();
      
      return ModerationStats(
        totalFlagged: flaggedSnapshot.size,
        queueSize: queueSnapshot.size,
        totalReports: reportsSnapshot.size,
        autoFlagged: flaggedSnapshot.docs
            .where((doc) => doc.data()['reason'] == 'auto_flagged')
            .length,
        manuallyFlagged: flaggedSnapshot.docs
            .where((doc) => doc.data()['reason'] != 'auto_flagged')
            .length,
        processedToday: queueSnapshot.docs
            .where((doc) {
                final data = doc.data();
                final queuedAt = (data['queuedAt'] as Timestamp).toDate();
                return queuedAt.isAfter(DateTime(now.year, now.month, now.day - 1)) &&
                       data['status'] == 'processed';
              })
            .length,
        period: '30_days',
      );
    } catch (e) {
      return ModerationStats(
        totalFlagged: 0,
        queueSize: 0,
        totalReports: 0,
        autoFlagged: 0,
        manuallyFlagged: 0,
        processedToday: 0,
        period: '30_days',
      );
    }
  }

  // Process flagged content automatically
  Future<void> _processFlaggedContent({
    required String contentId,
    required String reason,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Add to moderation queue
      await _firestore.collection(moderationQueueCollection).add({
        'contentId': contentId,
        'userId': userId,
        'action': 'flag_content',
        'reason': reason,
        'queuedAt': FieldValue.serverTimestamp(),
        'status': 'queued',
      });
    } catch (e) {
      print('Error processing flagged content: $e');
    }
  }

  // Helper methods
  List<String> _extractLabels(Map<String, dynamic> analysis) {
    final labels = <String>[];
    if (analysis.containsKey('labelAnnotations')) {
      final labelAnnotations = analysis['labelAnnotations'] as List;
      for (final annotation in labelAnnotations) {
        final label = annotation['description'] ?? '';
        if (label.isNotEmpty) labels.add(label);
      }
    }
    return labels;
  }

  List<DetectedObject> _extractDetectedObjects(Map<String, dynamic> analysis) {
    final objects = <DetectedObject>[];
    if (analysis.containsKey('localizedObjectAnnotations')) {
      final localizedObjects = analysis['localizedObjectAnnotations'] as List;
      for (final obj in localizedObjects) {
        final name = obj['name'] ?? '';
        final boundingPoly = obj['boundingPoly'] as List<dynamic>?;
        final score = (obj['score'] ?? 0.0) as double;
        
        if (name.isNotEmpty && boundingPoly != null) {
          final vertices = (boundingPoly as List<dynamic>)
              .map((vertex) {
                final x = vertex['x'] as double?;
                final y = vertex['y'] as double?;
                return DetectedVertex(x: x!, y: y!);
              }).toList();
          
          objects.add(DetectedObject(
            name: name,
            boundingPoly: vertices,
            score: score,
            type: _getObjectType(name),
          ));
        }
      }
    }
    return objects;
  }

  List<String> _extractDetectedText(Map<String, dynamic> analysis) {
    final texts = <String>[];
    if (analysis.containsKey('textAnnotations')) {
      final textAnnotations = analysis['textAnnotations'] as List;
      for (final annotation in textAnnotations) {
        final text = annotation['description'] ?? '';
        if (text.isNotEmpty) texts.add(text);
      }
    }
    return texts;
  }

  List<DetectedFace> _extractDetectedFaces(Map<String, dynamic> analysis) {
    final faces = <DetectedFace>[];
    if (analysis.containsKey('faceAnnotations')) {
      final faceAnnotations = analysis['faceAnnotations'] as List;
      for (final annotation in faceAnnotations) {
        final boundingPoly = annotation['boundingPoly'] as List<dynamic>?;
        final confidence = (annotation['confidence'] ?? 0.0) as double;
        
        if (boundingPoly != null) {
          final vertices = (boundingPoly as List<dynamic>)
              .map((vertex) {
                final x = vertex['x'] as double?;
                final y = vertex['y'] as double?;
                return DetectedVertex(x: x!, y: y!);
              }).toList();
          
          faces.add(DetectedFace(
            confidence: confidence,
            boundingPoly: vertices,
            role: annotation['role'] ?? '',
            joy: annotation['joy'] ?? '',
            sorrow: annotation['sorrow'] ?? '',
            anger: annotation['anger'] ?? '',
            surprise: annotation['surprise'] ?? '',
          ));
        }
      }
    }
    return faces;
  }

  List<DetectedLogo> _extractDetectedLogos(Map<String, dynamic> analysis) {
    final logos = <DetectedLogo>[];
    if (analysis.containsKey('logoAnnotations')) {
      final logoAnnotations = analysis['logoAnnotations'] as List;
      for (final annotation in logoAnnotations) {
        final boundingPoly = annotation['boundingPoly'] as List<dynamic>?;
        final confidence = (annotation['confidence'] ?? 0.0) as double;
        final description = annotation['description'] ?? '';
        
        if (boundingPoly != null) {
          final vertices = (boundingPoly as List<dynamic>)
              .map((vertex) {
                final x = vertex['x'] as double?;
                final y = vertex['y'] as double?;
                return DetectedVertex(x: x!, y: y!);
              }).toList();
          
          logos.add(DetectedLogo(
            confidence: confidence,
            boundingPoly: vertices,
            description: description,
          ));
        }
      }
    }
    return logos;
  }

  List<String> _extractWebEntities(Map<String, dynamic> analysis) {
    final entities = <String>[];
    if (analysis.containsKey('webDetection')) {
      final webDetection = analysis['webDetection'] as Map<String, dynamic>;
      
      // Extract URLs
      final urls = <String>[];
      if (webDetection.containsKey('pagesWithMatchingImages')) {
        final pages = webDetection['pagesWithMatchingImages'] as List;
        for (final page in pages) {
          if (page.containsKey('fullMatchingImages')) {
            final images = page['fullMatchingImages'] as List;
            for (final image in images) {
              if (image.containsKey('url')) {
                urls.add(image['url'] as String);
              }
            }
          }
        }
      }
      
      // Extract detected entities
      if (webDetection.containsKey('bestGuessLabels')) {
        final bestGuesses = webDetection['bestGuessLabels'] as List;
        for (final guess in bestGuesses) {
          if (guess.containsKey('label')) {
            entities.add(guess['label'] as String);
          }
        }
      }
      
      // Extract detected web entities
      if (webDetection.containsKey('webEntities')) {
        final webEntities = webDetection['webEntities'] as List;
        for (final entity in webEntities) {
          if (entity.containsKey('description')) {
            entities.add(entity['description'] as String);
          }
        }
      }
      
      entities.addAll(urls);
    }
    return entities;
  }

  String _getObjectType(String name) {
    final lowerName = name.toLowerCase();
    
    // Check for weapons
    if (contentCategories['violence']?.any((weapon) => lowerName.contains(weapon)) ?? false) {
      return 'weapon';
    }
    
    // Check for violence
    if (contentCategories['violence']?.any((violence) => lowerName.contains(violence)) ?? false) {
      return 'violence';
    }
    
    // Check for hate speech
    if (contentCategories['hate_speech']?.any((hate) => lowerName.contains(hate)) ?? false) {
      return 'hate_speech';
    }
    
    // Check for self harm
    if (contentCategories['self_harm']?.any((harm) => lowerName.contains(harm)) ?? false) {
      return 'self_harm';
    }
    
    // Check for adult content
    if (contentCategories['adult_content']?.any((adult) => lowerName.contains(adult)) ?? false) {
      return 'adult_content';
    }
    
    // Check for inappropriate content
    if (contentCategories['inappropriate']?.any((inappropriate) => lowerName.contains(inappropriate)) ?? false) {
      return 'inappropriate';
    }
    
    // Check for copyright
    if (contentCategories['copyright']?.any((copyright) => lowerName.contains(copyright)) ?? false) {
      return 'copyright';
    }
    
    // Check for hate speech
    if (contentCategories['hate_speech']?.any((hate) => lowerName.contains(hate)) ?? false) {
      return 'hate_speech';
    }
    
    // Check for spam
    if (contentCategories['spam']?.any((spam) => lowerName.contains(spam)) ?? false) {
      return 'spam';
    }
    
    return 'general';
  }
}

// Content analysis model
class ContentAnalysis {
  final bool isExplicit;
  final bool isAdult;
  final bool isViolent;
  final bool isRacy;
  final bool containsWeapons;
  final bool containsHate;
  final bool isSpam;
  final bool isCopyright;
  final bool isMisinformation;
  final double confidence;
  final List<String> labels;
  final List<DetectedObject> detectedObjects;
  final List<String> detectedText;
  final List<DetectedFace> detectedFaces;
  final List<DetectedLogo> detectedLogos;
  final List<String> detectedWebEntities;
  final DateTime analysisTimestamp;

  ContentAnalysis({
    required this.isExplicit,
    required this.isAdult,
    required this.isViolent,
    required this.isRacy,
    required this.containsWeapons,
    required this.containsHate,
    required this.isSpam,
    required this.isCopyright,
    required this.isMisinformation,
    required this.confidence,
    required this.labels,
    required this.detectedObjects,
    required this.detectedText,
    required this.detectedFaces,
    required this.detectedLogos,
    required this.detectedWebEntities,
    required this.analysisTimestamp,
  });

  String get contentStatus {
    if (isExplicit || isAdult || isViolent || containsWeapons || containsHate) {
      return 'blocked';
    } else if (isRacy || isSpam || isCopyright || isMisinformation) {
      return 'flagged';
    } else {
      return 'approved';
    }
  }

  String get contentAction {
    if (isExplicit || isAdult || isViolent || containsWeapons || containsHate) {
      return 'block';
    } else if (isRacy || isSpam || isCopyright || isMisinformation) {
      return 'review';
    } else {
      return 'approve';
    }
  }
}

// Flagged content model
class FlaggedContent {
  final String id;
  final String contentId;
  final String userId;
  final String reason;
  final String description;
  final DateTime flaggedAt;
  final String reviewStatus;
  final Map<String, dynamic> additionalData;

  FlaggedContent({
    required this.id,
    required this.contentId,
    required this.userId,
    required this.reason,
    required this.description,
    required this.flaggedAt,
    required this.reviewStatus,
    required this.additionalData,
  });

  String get reasonText {
    switch (reason) {
      case 'auto_flagged':
        return 'تحديد تلقائي';
      case 'explicit_content':
        return 'محتوى صريح';
      case 'violence':
        return 'عنيف';
      case 'adult_content':
        return 'محتوى للبالغين';
      case 'inappropriate':
        return 'محتوى غير لائق';
      case 'copyright':
        return 'انتهاك حقوق الطبع والنشر';
      case 'hate_speech':
        return 'خطاب كراه';
      case 'spam':
        return 'رسائل مزعجة';
      case 'misinformation':
        return 'معلومات خاطئة';
      case 'moderator_action':
        return 'إجراء المشرف';
      default:
        return 'غير معروف';
    }
  }
}

// Moderation queue item model
class ModerationQueueItem {
  final String id;
  final String contentId;
  final String userId;
  final String action;
  final String reason;
  final String description;
  final DateTime queuedAt;
  final String status;
  final Map<String, dynamic> additionalData;

  ModerationQueueItem({
    required this.id,
    required this.contentId,
    required this.userId,
    required this.action,
    required this.reason,
    required this.description,
    required this.queuedAt,
    required this.status,
    required this.additionalData,
  });

  String get actionText {
    switch (action) {
      case 'flag_content':
        return 'تحديد المحتوى';
      case 'delete_content':
        return 'حذف المحتوى';
      case 'approve_content':
        return 'موافقة المحتوى';
      case 'reject_content':
        return 'رفض المحتوى';
      default:
        return 'غير معروف';
    }
  }
}

// Moderation statistics model
class ModerationStats {
  final int totalFlagged;
  final int queueSize;
  final int totalReports;
  final int autoFlagged;
  final int manuallyFlagged;
  final int processedToday;
  final String period;

  ModerationStats({
    required this.totalFlagged,
    required this.queueSize,
    required this.totalReports,
    required this.autoFlagged,
    required this.manuallyFlagged,
    required this.processedToday,
    required this.period,
  });
}

// Detected object model
class DetectedObject {
  final String name;
  final List<DetectedVertex> boundingPoly;
  final double score;
  final String type;

  DetectedObject({
    required this.name,
    required this.boundingPoly,
    required this.score,
    required this.type,
  });
}

// Detected vertex model
class DetectedVertex {
  final double x;
  final double y;

  DetectedVertex({
    required this.x,
    required this.y,
  });
}

// Detected face model
class DetectedFace {
  final double confidence;
  final List<DetectedVertex> boundingPoly;
  final String role;
  final String joy;
  final String sorrow;
  final String anger;
  final String surprise;

  DetectedFace({
    required this.confidence,
    required this.boundingPoly,
    required this.role,
    required this.joy,
    required this.sorrow,
    required this.anger,
    required this.surprise,
  });
}

// Detected logo model
class DetectedLogo {
  final double confidence;
  final List<DetectedVertex> boundingPoly;
  final String description;

  DetectedLogo({
    required this.confidence,
    required this.boundingPoly,
    required this.description,
  });
}
