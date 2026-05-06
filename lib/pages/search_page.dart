import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  
  final List<String> _categories = [
    'الكل',
    'المنتجات',
    'الخدمات',
    'المستخدمون',
    'المنشورات',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'البحث',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFd4af37),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Input Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFd4af37),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث عن...',
                    hintStyle: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textAlign: TextAlign.right,
                ),
                
                const SizedBox(height: 15),
                
                // Categories
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(
                            category,
                            style: GoogleFonts.tajawal(
                              color: isSelected ? Colors.white : const Color(0xFFd4af37),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFFd4af37),
                          checkmarkColor: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Search Results
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildEmptyState()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'ابدأ البحث عن المحتوى',
            style: GoogleFonts.tajawal(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'اكتب كلمات مفتاحية للبحث',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_selectedCategory == 'الكل') {
      return Column(
        children: [
          _buildSectionTitle('المنتجات'),
          _buildProductsSearch(),
          _buildSectionTitle('الخدمات'),
          _buildServicesSearch(),
          _buildSectionTitle('المستخدمون'),
          _buildUsersSearch(),
        ],
      );
    } else if (_selectedCategory == 'المنتجات') {
      return _buildProductsSearch();
    } else if (_selectedCategory == 'الخدمات') {
      return _buildServicesSearch();
    } else if (_selectedCategory == 'المستخدمون') {
      return _buildUsersSearch();
    } else {
      return _buildPostsSearch();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFd4af37),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: Text(
              'عرض الكل',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFd4af37),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSearch() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('products')
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: '${_searchQuery}\uf8ff')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults('منتجات');
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final product = snapshot.data!.docs[index];
            final productData = product.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFd4af37),
                  child: const Icon(
                    Icons.shopping_bag,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  productData['name'] ?? '',
                  style: GoogleFonts.tajawal(),
                ),
                subtitle: Text(
                  productData['description'] ?? '',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Text(
                  '${productData['price'] ?? 0} ريال',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFFd4af37),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildServicesSearch() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('services')
          .where('title', isGreaterThanOrEqualTo: _searchQuery)
          .where('title', isLessThanOrEqualTo: '${_searchQuery}\uf8ff')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults('خدمات');
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final service = snapshot.data!.docs[index];
            final serviceData = service.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFd4af37),
                  child: const Icon(
                    Icons.miscellaneous_services,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  serviceData['title'] ?? '',
                  style: GoogleFonts.tajawal(),
                ),
                subtitle: Text(
                  serviceData['provider'] ?? '',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersSearch() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: '${_searchQuery}\uf8ff')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults('مستخدمين');
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final user = snapshot.data!.docs[index];
            final userData = user.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFd4af37),
                  child: Text(
                    (userData['name'] ?? '')[0].toUpperCase(),
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  userData['name'] ?? '',
                  style: GoogleFonts.tajawal(),
                ),
                subtitle: Text(
                  userData['email'] ?? '',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostsSearch() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('content', isGreaterThanOrEqualTo: _searchQuery)
          .where('content', isLessThanOrEqualTo: '${_searchQuery}\uf8ff')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults('منشورات');
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final post = snapshot.data!.docs[index];
            final postData = post.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFd4af37),
                  child: const Icon(
                    Icons.article,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  postData['title'] ?? '',
                  style: GoogleFonts.tajawal(),
                ),
                subtitle: Text(
                  postData['content'] ?? '',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoResults(String type) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'لا توجد نتائج لـ $type',
          style: GoogleFonts.tajawal(
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
