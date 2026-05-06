import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  int _unreadCount = 0;
  
  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFd4af37),
              backgroundImage: widget.receiverAvatar != null
                  ? CachedNetworkImageProvider(widget.receiverAvatar!)
                  : null,
              child: widget.receiverAvatar == null
                  ? Text(
                      widget.receiverName.isNotEmpty ? widget.receiverName[0] : '?',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_unreadCount > 0)
                    Text(
                      '$_unreadCount رسالة غير مقروءة',
                      style: GoogleFonts.tajawal(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFd4af37),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
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
              // Messages List
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _chatService.getMessagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ في تحميل الرسائل',
                          style: GoogleFonts.tajawal(color: Colors.white),
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    _messages = messages;

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat,
                              color: Colors.white,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ابدأ المحادثة',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'أرسل رسالة للمستخدم',
                              style: GoogleFonts.tajawal(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _buildMessageBubble(message);
                      },
                    );
                  },
                ),
              ),
              
              // Message Input
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isFromMe;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFd4af37),
              backgroundImage: widget.receiverAvatar != null
                  ? CachedNetworkImageProvider(widget.receiverAvatar!)
                  : null,
              child: widget.receiverAvatar == null
                  ? Text(
                      widget.receiverName.isNotEmpty ? widget.receiverName[0] : '?',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white : const Color(0xFFd4af37),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildMessageContent(message),
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.formattedTime,
                      style: GoogleFonts.tajawal(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.read ? Icons.done_all : Icons.done,
                        color: message.read ? Colors.blue : Colors.white.withOpacity(0.7),
                        size: 12,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFd4af37),
              backgroundImage: _auth.currentUser?.photoURL != null
                  ? CachedNetworkImageProvider(_auth.currentUser!.photoURL!)
                  : null,
              child: _auth.currentUser?.photoURL == null
                  ? Text(
                      _auth.currentUser?.displayName?.isNotEmpty == true
                          ? _auth.currentUser!.displayName![0]
                          : 'أ',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    switch (message.type) {
      case 'text':
        return Text(
          message.content,
          style: GoogleFonts.tajawal(
            color: message.isFromMe ? Colors.black87 : Colors.white,
            fontSize: 14,
          ),
        );
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '[صورة]',
              style: GoogleFonts.tajawal(
                color: message.isFromMe ? Colors.black87 : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: message.content,
                placeholder: (context, url) => Container(
                  height: 150,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFd4af37),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '[فيديو]',
              style: GoogleFonts.tajawal(
                color: message.isFromMe ? Colors.black87 : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Color(0xFFd4af37),
                  size: 48,
                ),
              ),
            ),
          ],
        );
      default:
        return Text(
          message.content,
          style: GoogleFonts.tajawal(
            color: message.isFromMe ? Colors.black87 : Colors.white,
            fontSize: 14,
          ),
        );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Media buttons
          IconButton(
            icon: const Icon(Icons.image, color: Color(0xFFd4af37)),
            onPressed: _pickImage,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Color(0xFFd4af37)),
            onPressed: _pickVideo,
          ),
          
          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: GoogleFonts.tajawal(
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              style: GoogleFonts.tajawal(
                color: Colors.black87,
              ),
              maxLines: 5,
              minLines: 1,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFd4af37),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty) return;
    
    setState(() => _isSending = true);
    
    try {
      await _chatService.sendTextMessage(
        chatId: widget.chatId,
        content: text,
        receiverId: widget.receiverId,
      );
      
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar('فشل إرسال الرسالة');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() => _isSending = true);
        
        await _chatService.sendImageMessage(
          chatId: widget.chatId,
          imageFile: File(image.path),
          receiverId: widget.receiverId,
        );
        
        _scrollToBottom();
        setState(() => _isSending = false);
      }
    } catch (e) {
      _showErrorSnackBar('فشل إرسال الصورة');
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() => _isSending = true);
        
        await _chatService.sendVideoMessage(
          chatId: widget.chatId,
          videoFile: File(result.files.single.path!),
          receiverId: widget.receiverId,
        );
        
        _scrollToBottom();
        setState(() => _isSending = false);
      }
    } catch (e) {
      _showErrorSnackBar('فشل إرسال الفيديو');
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markAllMessagesAsRead(widget.chatId);
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                'حذف المحادثة',
                style: GoogleFonts.tajawal(),
              ),
              onTap: () {
                Navigator.pop(context);
                _clearChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Color(0xFFd4af37)),
              title: Text(
                'المحادثة مشفرة من طرف إلى طرف',
                style: GoogleFonts.tajawal(),
              ),
              subtitle: Text(
                'الرسائل مشفرة ولا يمكن قراءتها من قبل أطراف ثالثة',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearChat() async {
    try {
      await _chatService.clearChatKeys(widget.chatId);
      Navigator.pop(context);
      _showSuccessSnackBar('تم حذف مفاتيح التشفير');
    } catch (e) {
      _showErrorSnackBar('فشل حذف المحادثة');
    }
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
}
