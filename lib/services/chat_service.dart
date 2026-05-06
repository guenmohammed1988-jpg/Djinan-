import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Encryption key storage
  static const String _encryptionKeyPrefix = 'chat_key_';
  static const String _ivPrefix = 'chat_iv_';
  
  // Message types
  static const String textType = 'text';
  static const String imageType = 'image';
  static const String videoType = 'video';
  
  // External link detection regex
  static final RegExp _externalLinkRegex = RegExp(
    r'https?://(?:[-\w.])+(?:\:[0-9]+)?(?:/(?:[\w/_.])*(?:\?(?:[\w&=%.])*)?(?:\#(?:[\w.])*)?)?',
    caseSensitive: false,
  );

  // Generate encryption key for chat
  Future<EncryptedKey> generateEncryptionKey(String chatId) async {
    try {
      final key = Key.fromSecureRandom(32);
      final iv = IV.fromSecureRandom(16);
      
      // Store key and IV securely
      await _secureStorage.write(
        key: '${_encryptionKeyPrefix}${_auth.currentUser?.uid}_$chatId',
        value: key.base64,
      );
      await _secureStorage.write(
        key: '${_ivPrefix}${_auth.currentUser?.uid}_$chatId',
        value: iv.base64,
      );
      
      return EncryptedKey(key: key, iv: iv);
    } catch (e) {
      throw Exception('Failed to generate encryption key: $e');
    }
  }

  // Get stored encryption key
  Future<EncryptedKey?> getEncryptionKey(String chatId) async {
    try {
      final keyString = await _secureStorage.read(
        key: '${_encryptionKeyPrefix}${_auth.currentUser?.uid}_$chatId',
      );
      final ivString = await _secureStorage.read(
        key: '${_ivPrefix}${_auth.currentUser?.uid}_$chatId',
      );
      
      if (keyString == null || ivString == null) {
        return null;
      }
      
      final key = Key.fromBase64(keyString);
      final iv = IV.fromBase64(ivString);
      
      return EncryptedKey(key: key, iv: iv);
    } catch (e) {
      return null;
    }
  }

  // Encrypt message content
  String encryptMessage(String content, EncryptedKey encryptedKey) {
    try {
      final encrypter = Encrypter(AES(encryptedKey.key));
      final encrypted = encrypter.encrypt(content, iv: encryptedKey.iv);
      return encrypted.base64;
    } catch (e) {
      throw Exception('Failed to encrypt message: $e');
    }
  }

  // Decrypt message content
  String decryptMessage(String encryptedContent, EncryptedKey encryptedKey) {
    try {
      final encrypter = Encrypter(AES(encryptedKey.key));
      final encrypted = Encrypted.fromBase64(encryptedContent);
      return encrypter.decrypt(encrypted, iv: encryptedKey.iv);
    } catch (e) {
      throw Exception('Failed to decrypt message: $e');
    }
  }

  // Check for external links
  bool containsExternalLink(String text) {
    return _externalLinkRegex.hasMatch(text);
  }

  // Remove external links from text
  String removeExternalLinks(String text) {
    return text.replaceAll(_externalLinkRegex, '[رابط خارجي محذوف]');
  }

  // Send text message
  Future<String> sendTextMessage({
    required String chatId,
    required String content,
    required String receiverId,
  }) async {
    try {
      // Check for external links
      if (containsExternalLink(content)) {
        content = removeExternalLinks(content);
      }
      
      // Get or generate encryption key
      EncryptedKey? encryptedKey = await getEncryptionKey(chatId);
      if (encryptedKey == null) {
        encryptedKey = await generateEncryptionKey(chatId);
      }
      
      // Encrypt content
      final encryptedContent = encryptMessage(content, encryptedKey);
      
      // Create message document
      final messageRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'type': textType,
            'content': encryptedContent,
            'senderId': _auth.currentUser?.uid,
            'receiverId': receiverId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'encrypted': true,
          });
      
      // Update chat metadata
      await _updateChatMetadata(chatId, content, textType);
      
      return messageRef.id;
    } catch (e) {
      throw Exception('Failed to send text message: $e');
    }
  }

  // Send image message
  Future<String> sendImageMessage({
    required String chatId,
    required File imageFile,
    required String receiverId,
  }) async {
    try {
      // Get or generate encryption key
      EncryptedKey? encryptedKey = await getEncryptionKey(chatId);
      if (encryptedKey == null) {
        encryptedKey = await generateEncryptionKey(chatId);
      }
      
      // Upload image to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final ref = _storage.ref().child('chat_images').child(chatId).child(fileName);
      
      final uploadTask = await ref.putFile(imageFile);
      final imageUrl = await uploadTask.ref.getDownloadURL();
      
      // Encrypt image URL
      final encryptedUrl = encryptMessage(imageUrl, encryptedKey);
      
      // Create message document
      final messageRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'type': imageType,
            'content': encryptedUrl,
            'fileName': fileName,
            'fileSize': await imageFile.length(),
            'senderId': _auth.currentUser?.uid,
            'receiverId': receiverId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'encrypted': true,
          });
      
      // Update chat metadata
      await _updateChatMetadata(chatId, '[صورة]', imageType);
      
      return messageRef.id;
    } catch (e) {
      throw Exception('Failed to send image message: $e');
    }
  }

  // Send video message
  Future<String> sendVideoMessage({
    required String chatId,
    required File videoFile,
    required String receiverId,
  }) async {
    try {
      // Get or generate encryption key
      EncryptedKey? encryptedKey = await getEncryptionKey(chatId);
      if (encryptedKey == null) {
        encryptedKey = await generateEncryptionKey(chatId);
      }
      
      // Upload video to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoFile.path)}';
      final ref = _storage.ref().child('chat_videos').child(chatId).child(fileName);
      
      final uploadTask = await ref.putFile(videoFile);
      final videoUrl = await uploadTask.ref.getDownloadURL();
      
      // Encrypt video URL
      final encryptedUrl = encryptMessage(videoUrl, encryptedKey);
      
      // Create message document
      final messageRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'type': videoType,
            'content': encryptedUrl,
            'fileName': fileName,
            'fileSize': await videoFile.length(),
            'senderId': _auth.currentUser?.uid,
            'receiverId': receiverId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'encrypted': true,
          });
      
      // Update chat metadata
      await _updateChatMetadata(chatId, '[فيديو]', videoType);
      
      return messageRef.id;
    } catch (e) {
      throw Exception('Failed to send video message: $e');
    }
  }

  // Update chat metadata
  Future<void> _updateChatMetadata(String chatId, String lastMessage, String messageType) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': lastMessage,
        'lastMessageType': messageType,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'participants': [
          _auth.currentUser?.uid,
        ],
      });
    } catch (e) {
      // Create chat document if it doesn't exist
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': lastMessage,
        'lastMessageType': messageType,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'participants': [
          _auth.currentUser?.uid,
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get messages stream
  Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final messages = <ChatMessage>[];
          
          for (final doc in snapshot.docs) {
            final message = await _parseMessage(doc);
            if (message != null) {
              messages.add(message);
            }
          }
          
          return messages;
        });
  }

  // Parse message document
  Future<ChatMessage?> _parseMessage(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final chatId = doc.reference.parent.parent?.id ?? '';
      
      // Get encryption key
      final encryptedKey = await getEncryptionKey(chatId);
      if (encryptedKey == null) {
        return null;
      }
      
      // Decrypt content
      String decryptedContent = '';
      if (data['encrypted'] == true) {
        decryptedContent = decryptMessage(data['content'], encryptedKey);
      } else {
        decryptedContent = data['content'] ?? '';
      }
      
      return ChatMessage(
        id: doc.id,
        type: data['type'] ?? '',
        content: decryptedContent,
        senderId: data['senderId'] ?? '',
        receiverId: data['receiverId'] ?? '',
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        read: data['read'] ?? false,
        encrypted: data['encrypted'] ?? false,
        fileName: data['fileName'],
        fileSize: (data['fileSize'] ?? 0) as int,
      );
    } catch (e) {
      return null;
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle error
    }
  }

  // Mark all messages as read
  Future<void> markAllMessagesAsRead(String chatId) async {
    try {
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: _auth.currentUser?.uid)
          .where('read', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in messages.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      // Handle error
    }
  }

  // Get user chats
  Stream<List<ChatRoom>> getUserChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: _auth.currentUser?.uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final chats = <ChatRoom>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        chats.add(ChatRoom(
          id: doc.id,
          lastMessage: data['lastMessage'] ?? '',
          lastMessageType: data['lastMessageType'] ?? '',
          lastMessageTimestamp: (data['lastMessageTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          participants: List<String>.from(data['participants'] ?? []),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }
      
      return chats;
    });
  }

  // Get unread messages count
  Future<int> getUnreadMessagesCount(String chatId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: _auth.currentUser?.uid)
          .where('read', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      // Delete from Firestore
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Clear chat keys
  Future<void> clearChatKeys(String chatId) async {
    try {
      await _secureStorage.delete(key: '${_encryptionKeyPrefix}${_auth.currentUser?.uid}_$chatId');
      await _secureStorage.delete(key: '${_ivPrefix}${_auth.currentUser?.uid}_$chatId');
    } catch (e) {
      // Handle error
    }
  }
}

// Encrypted key model
class EncryptedKey {
  final Key key;
  final IV iv;

  EncryptedKey({required this.key, required this.iv});
}

// Chat message model
class ChatMessage {
  final String id;
  final String type;
  final String content;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final bool read;
  final bool encrypted;
  final String? fileName;
  final int fileSize;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.read,
    required this.encrypted,
    this.fileName,
    required this.fileSize,
  });

  // Get formatted time
  String get formattedTime {
    return DateFormat('HH:mm').format(timestamp);
  }

  // Get formatted date
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return 'اليوم';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'أمس';
    } else {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    }
  }

  // Get formatted file size
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Check if message is from current user
  bool get isFromMe {
    return senderId == FirebaseAuth.instance.currentUser?.uid;
  }
}

// Chat room model
class ChatRoom {
  final String id;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageTimestamp;
  final List<String> participants;
  final DateTime createdAt;

  ChatRoom({
    required this.id,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageTimestamp,
    required this.participants,
    required this.createdAt,
  });

  // Get formatted last message time
  String get formattedLastMessageTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(lastMessageTimestamp.year, lastMessageTimestamp.month, lastMessageTimestamp.day);
    
    if (messageDate == today) {
      return DateFormat('HH:mm').format(lastMessageTimestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'أمس';
    } else {
      return DateFormat('dd/MM/yyyy').format(lastMessageTimestamp);
    }
  }
}
