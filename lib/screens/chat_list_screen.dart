import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الرسائل',
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
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
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
          child: StreamBuilder<List<ChatRoom>>(
            stream: _chatService.getUserChats(),
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
                    'حدث خطأ في تحميل المحادثات',
                    style: GoogleFonts.tajawal(color: Colors.white),
                  ),
                );
              }

              final chatRooms = snapshot.data ?? [];

              if (chatRooms.isEmpty) {
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
                        'لا توجد محادثات',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ محادثة جديدة',
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
                padding: const EdgeInsets.all(16),
                itemCount: chatRooms.length,
                itemBuilder: (context, index) {
                  final chatRoom = chatRooms[index];
                  return _buildChatRoomCard(chatRoom);
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: const Color(0xFFd4af37),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildChatRoomCard(ChatRoom chatRoom) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFd4af37),
          child: Text(
            'م',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          'مستخدم ${chatRoom.id.substring(0, 8)}',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFd4af37),
          ),
        ),
        subtitle: Text(
          _getLastMessagePreview(chatRoom),
          style: GoogleFonts.tajawal(
            color: Colors.grey[600],
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              chatRoom.formattedLastMessageTime,
              style: GoogleFonts.tajawal(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            // Unread count indicator would go here
          ],
        ),
        onTap: () => _openChat(chatRoom),
      ),
    );
  }

  String _getLastMessagePreview(ChatRoom chatRoom) {
    switch (chatRoom.lastMessageType) {
      case 'text':
        return chatRoom.lastMessage;
      case 'image':
        return '[صورة]';
      case 'video':
        return '[فيديو]';
      default:
        return chatRoom.lastMessage;
    }
  }

  void _openChat(ChatRoom chatRoom) {
    // Get the other participant's ID
    final otherParticipantId = chatRoom.participants
        .firstWhere((id) => id != _auth.currentUser?.uid);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatRoom.id,
          receiverId: otherParticipantId,
          receiverName: 'مستخدم ${otherParticipantId.substring(0, 8)}',
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'بحث عن محادثة',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'اكتب اسم المستخدم...',
            hintStyle: GoogleFonts.tajawal(
              color: Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'بحث',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'محادثة جديدة',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل معرف المستخدم للمحادثة',
              style: GoogleFonts.tajawal(),
            ),
            const SizedBox(height: 16),
            TextField(
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'معرف المستخدم...',
                hintStyle: GoogleFonts.tajawal(
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: GoogleFonts.tajawal(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'بدء',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
