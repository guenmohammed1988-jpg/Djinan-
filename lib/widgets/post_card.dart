import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final String currentUserId;

  const PostCard({
    super.key,
    required this.post,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  int _shareCount = 0;
  bool _canLike = true; // For images, can like immediately
  bool _hasWatched60Percent = false; // Track 60% watch requirement

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadEngagementData();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoPositionListener);
    _videoController?.dispose();
    super.dispose();
  }

  void _videoPositionListener() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final currentPosition = _videoController!.value.position;
      final totalDuration = _videoController!.value.duration;
      
      if (totalDuration.inMilliseconds > 0) {
        final watchedPercentage = (currentPosition.inMilliseconds / totalDuration.inMilliseconds) * 100;
        
        if (watchedPercentage >= 60 && !_hasWatched60Percent) {
          setState(() {
            _hasWatched60Percent = true;
            _canLike = true;
          });
        }
      }
    }
  }

  double _getWatchPercentage() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final currentPosition = _videoController!.value.position;
      final totalDuration = _videoController!.value.duration;
      
      if (totalDuration.inMilliseconds > 0) {
        return (currentPosition.inMilliseconds / totalDuration.inMilliseconds) * 100;
      }
    }
    return 0.0;
  }

  Future<void> _initializeVideo() async {
    if (widget.post['mediaType'] == 'video' && widget.post['mediaUrl'] != null) {
      try {
        _videoController = VideoPlayerController.network(widget.post['mediaUrl']);
        await _videoController!.initialize();
        
        // Add position listener to track 60% watch
        _videoController!.addListener(_videoPositionListener);
        
        setState(() {
          _isVideoInitialized = true;
          _canLike = false; // Video requires 60% watch to like
        });
      } catch (e) {
        print('Error initializing video: $e');
      }
    } else if (widget.post['mediaType'] == 'image') {
      setState(() {
        _canLike = true; // Images can be liked immediately
      });
    }
  }

  Future<void> _loadEngagementData() async {
    final engagementDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('engagement')
        .doc('stats')
        .get();

    if (engagementDoc.exists) {
      final data = engagementDoc.data() as Map<String, dynamic>;
      setState(() {
        _likeCount = data['likeCount'] ?? 0;
        _commentCount = data['commentCount'] ?? 0;
        _shareCount = data['shareCount'] ?? 0;
        _isLiked = data['likedBy']?.contains(widget.currentUserId) ?? false;
      });
    }
  }

  Future<void> _toggleLike() async {
    // Check if user can like (60% watched for videos, immediate for images)
    if (!_canLike) {
      _showLikeRequirementMessage();
      return;
    }

    final engagementRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('engagement')
        .doc('stats');

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final doc = await transaction.get(engagementRef);
      
      if (!doc.exists) {
        transaction.set(engagementRef, {
          'likeCount': _likeCount,
          'commentCount': 0,
          'shareCount': 0,
          'likedBy': _isLiked ? [widget.currentUserId] : [],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data() as Map<String, dynamic>;
        List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
        
        if (_isLiked) {
          likedBy.add(widget.currentUserId);
        } else {
          likedBy.remove(widget.currentUserId);
        }
        
        transaction.update(engagementRef, {
          'likeCount': _likeCount,
          'likedBy': likedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  void _showLikeRequirementMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.post['mediaType'] == 'video' 
              ? 'يجب مشاهدة 60% من الفيديو قبل الإعجاب' 
              : 'لا يمكن الإعجاب بهذا المحتوى',
          style: GoogleFonts.tajawal(),
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleVideoPlayback() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        _isPlaying = !_isPlaying;
      });
      if (_isPlaying) {
        _videoController!.play();
      } else {
        _videoController!.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header
          _buildUserHeader(),
          
          // Media Content
          if (widget.post['mediaType'] != null)
            _buildMediaContent(),
          
          // Post Content
          if (widget.post['caption'] != null)
            _buildCaption(),
          
          // Engagement Buttons
          _buildEngagementButtons(),
          
          // Engagement Stats
          _buildEngagementStats(),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post['userId'])
          .get(),
      builder: (context, snapshot) {
        String userName = 'مستخدم';
        String userAvatar = '';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          userName = userData['name'] ?? 'مستخدم';
          userAvatar = userData['avatar'] ?? '';
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFd4af37),
                backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                child: userAvatar.isEmpty
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
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
                      '@$userName',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatTimestamp(widget.post['createdAt']),
                      style: GoogleFonts.tajawal(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _showPostOptions(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaContent() {
    if (widget.post['mediaType'] == 'video') {
      return _buildVideoContent();
    } else if (widget.post['mediaType'] == 'image') {
      return _buildImageContent();
    }
    return const SizedBox.shrink();
  }

  Widget _buildVideoContent() {
    if (!_isVideoInitialized) {
      return Container(
        height: 300,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFd4af37)),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          height: 300,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
        
        // Progress indicator at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
            child: LinearProgressIndicator(
              value: _videoController!.value.isInitialized && _videoController!.value.duration.inMilliseconds > 0
                  ? (_videoController!.value.position.inMilliseconds / _videoController!.value.duration.inMilliseconds)
                  : 0.0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasWatched60Percent ? Colors.green : const Color(0xFFd4af37),
              ),
            ),
          ),
        ),
        
        // Watch percentage indicator
        if (!_canLike && widget.post['mediaType'] == 'video')
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(_getWatchPercentage()).toStringAsFixed(0)}% مشاهدة',
                style: GoogleFonts.tajawal(
                  color: _hasWatched60Percent ? Colors.green : Colors.white,
                  fontSize: 12,
                  fontWeight: _hasWatched60Percent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        
        // Like available indicator
        if (_canLike && widget.post['mediaType'] == 'video' && _hasWatched60Percent)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'متاح الإعجاب',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatVideoDuration(_videoController!.value.duration),
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: _toggleVideoPlayback,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent() {
    return CachedNetworkImage(
      imageUrl: widget.post['mediaUrl'],
      height: 300,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 300,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFd4af37)),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 300,
        color: Colors.grey[200],
        child: const Icon(Icons.error),
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        widget.post['caption'],
        style: GoogleFonts.tajawal(
          fontSize: 14,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildEngagementButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Like Button - Only enabled if user can like
          GestureDetector(
            onTap: _canLike ? _toggleLike : _showLikeRequirementMessage,
            child: Row(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked 
                      ? Colors.red 
                      : _canLike 
                          ? Colors.grey[600] 
                          : Colors.grey[400], // Dimmed when not allowed
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  'إعجاب',
                  style: GoogleFonts.tajawal(
                    color: _canLike ? Colors.grey[600] : Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                // Show lock icon for videos that haven't reached 60%
                if (widget.post['mediaType'] == 'video' && !_canLike) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock,
                    color: Colors.grey[400],
                    size: 12,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          
          // Comment Button
          GestureDetector(
            onTap: () => _openComments(),
            child: Row(
              children: [
                Icon(
                  Icons.comment_outlined,
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  'تعليق',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          
          // Share Button
          GestureDetector(
            onTap: _sharePost,
            child: Row(
              children: [
                Icon(
                  Icons.share_outlined,
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  'مشاركة',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          if (_likeCount > 0)
            Text(
              '$_likeCount إعجابات',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          if (_likeCount > 0 && _commentCount > 0)
            const Text(' • '),
          if (_commentCount > 0)
            Text(
              '$_commentCount تعليقات',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag),
              title: Text(
                'الإبلاغ عن المنشور',
                style: GoogleFonts.tajawal(),
              ),
              onTap: () {
                Navigator.pop(context);
                _reportPost();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: Text(
                'حفظ المنشور',
                style: GoogleFonts.tajawal(),
              ),
              onTap: () {
                Navigator.pop(context);
                _savePost();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          postId: widget.postId,
          postUserId: widget.post['userId'],
        ),
      ),
    );
  }

  void _sharePost() async {
    setState(() {
      _shareCount++;
    });
    
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت مشاركة المنشور',
          style: GoogleFonts.tajawal(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _reportPost() {
    // Implement report functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم الإبلاغ عن المنشور',
          style: GoogleFonts.tajawal(),
        ),
      ),
    );
  }

  void _savePost() {
    // Implement save functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم حفظ المنشور',
          style: GoogleFonts.tajawal(),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final date = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقائق';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعات';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatVideoDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postUserId;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postUserId,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'التعليقات',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFd4af37),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد تعليقات',
                      style: GoogleFonts.tajawal(),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final comment = snapshot.data!.docs[index];
                    final commentData = comment.data() as Map<String, dynamic>;
                    
                    return _buildCommentCard(comment, commentData);
                  },
                );
              },
            ),
          ),
          
          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                          hintText: 'اكتب تعليق...',
                          hintStyle: GoogleFonts.tajawal(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _addComment,
                  backgroundColor: const Color(0xFFd4af37),
                  mini: true,
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(DocumentSnapshot comment, Map<String, dynamic> commentData) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(commentData['userId']).get(),
      builder: (context, userSnapshot) {
        String userName = 'مستخدم';
        String userAvatar = '';
        
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          userName = userData['name'] ?? 'مستخدم';
          userAvatar = userData['avatar'] ?? '';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFd4af37),
                backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                child: userAvatar.isEmpty
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '@$userName',
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(commentData['createdAt']),
                          style: GoogleFonts.tajawal(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      commentData['text'] ?? '',
                      style: GoogleFonts.tajawal(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
            'text': _commentController.text.trim(),
            'userId': _auth.currentUser?.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Update comment count
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('engagement')
          .doc('stats')
          .set({
            'commentCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ في إضافة التعليق',
            style: GoogleFonts.tajawal(),
          ),
        ),
      );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final date = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقائق';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعات';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
