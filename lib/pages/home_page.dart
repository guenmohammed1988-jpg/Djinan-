import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/post_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  
  String _selectedFilter = 'الأقرب';
  List<DocumentSnapshot> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  int _postsPerPage = 10;
  
  final List<String> _filterOptions = [
    'الأقرب',
    'الأعلى تقييماً',
    'الأحدث',
    'الأكثر مشاهدة',
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      if (refresh) {
        _posts.clear();
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      Query query = _firestore.collection('posts').where('isPublic', isEqualTo: true);
      
      // Apply filter
      switch (_selectedFilter) {
        case 'الأقرب':
          final position = await _getCurrentPosition();
          if (position != null) {
            final geopoint = GeoPoint(position.latitude, position.longitude);
            query = query.orderBy('location');
          } else {
            query = query.orderBy('createdAt', descending: true);
          }
          break;
        case 'الأعلى تقييماً':
          query = query.orderBy('likeCount', descending: true);
          break;
        case 'الأحدث':
          query = query.orderBy('createdAt', descending: true);
          break;
        case 'الأكثر مشاهدةً':
          query = query.orderBy('viewCount', descending: true);
          break;
      }

      // Apply pagination
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      query = query.limit(_postsPerPage);

      final snapshot = await query.get();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (snapshot.docs.isNotEmpty) {
            _posts.addAll(snapshot.docs);
            _lastDocument = snapshot.docs.last;
          } else {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('حدث خطأ في تحميل المنشورات');
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;
    await _loadPosts();
  }

  Future<Position?> _getCurrentPosition() async {
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
      );
    } catch (e) {
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.tajawal(),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الرئيسية',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFd4af37),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadPosts(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(),
          
          // Posts List
          Expanded(
            child: _buildPostsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPost,
        backgroundColor: const Color(0xFFd4af37),
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = filter == _selectedFilter;
          
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilterChip(
              label: Text(
                filter,
                style: GoogleFonts.tajawal(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                  _loadPosts(refresh: true);
                }
              },
              backgroundColor: Colors.grey[200],
              selectedColor: const Color(0xFFd4af37),
              checkmarkColor: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsList() {
    if (_isLoading && _posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFd4af37)),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feed_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد منشورات',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'كن أول من ينشر محتوى',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPosts(refresh: true),
      color: const Color(0xFFd4af37),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return _buildLoadingIndicator();
          }
          
          final post = _posts[index];
          final postData = post.data() as Map<String, dynamic>;
          
          return PostCard(
            post: postData,
            postId: post.id,
            currentUserId: _auth.currentUser?.uid ?? '',
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(color: Color(0xFFd4af37)),
      ),
    );
  }

  void _createNewPost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CreatePostScreen(
        onPostCreated: () => _loadPosts(refresh: true),
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  final VoidCallback onPostCreated;

  const CreatePostScreen({
    super.key,
    required this.onPostCreated,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Text(
                'إنشاء منشور جديد',
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd4af37),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'نشر',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Caption Input
          TextField(
            controller: _captionController,
            decoration: InputDecoration(
                  hintText: 'اكتب شيئاً...',
                  hintStyle: GoogleFonts.tajawal(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
            maxLines: 5,
            textAlign: TextAlign.right,
          ),
          
          const SizedBox(height: 20),
          
          // Media Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMediaOption(
                icon: Icons.photo_library,
                label: 'معرض الصور',
                onTap: _selectImage,
              ),
              _buildMediaOption(
                icon: Icons.videocam,
                label: 'التقط فيديو',
                onTap: _recordVideo,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Privacy Settings
          Row(
            children: [
              Switch(
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
                activeColor: const Color(0xFFd4af37),
              ),
              const SizedBox(width: 8),
              Text(
                'منشور عام',
                style: GoogleFonts.tajawal(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: const Color(0xFFd4af37),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    if (_captionController.text.trim().isEmpty) {
      _showErrorSnackBar('الرجاء كتابة وصف للمنشور');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('posts').add({
        'caption': _captionController.text.trim(),
        'userId': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': _isPublic,
        'likeCount': 0,
        'viewCount': 0,
        'commentCount': 0,
        'mediaType': null, // Will be updated when media is added
        'mediaUrl': null,
      });

      widget.onPostCreated();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم نشر المنشور بنجاح',
            style: GoogleFonts.tajawal(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('حدث خطأ في نشر المنشور');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectImage() {
    // Implement image selection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم فتح معرض الصور قريباً',
          style: GoogleFonts.tajawal(),
        ),
      ),
    );
  }

  void _recordVideo() {
    // Implement video recording
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم فتح كاميرا الفيديو قريباً',
          style: GoogleFonts.tajawal(),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.tajawal(),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}
