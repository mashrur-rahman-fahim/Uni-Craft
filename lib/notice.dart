import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uni_craft/add_notice.dart';
import 'package:uni_craft/notice_detail.dart' as notice_detail;
import 'package:uni_craft/services/notice_service.dart';
import 'package:uni_craft/utils.dart';

class Notice extends StatefulWidget {
  final String role;
  final dynamic code;

  const Notice(this.role, this.code, {super.key});

  @override
  State<Notice> createState() => _NoticeState();
}

class _NoticeState extends State<Notice> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedPriority = 'all';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Map<String, int> _noticeStats = {};

  final List<String> _categories = ['all', 'general', 'academic', 'event', 'announcement', 'urgent'];
  final List<String> _priorities = ['all', 'low', 'normal', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNoticeStats();
    NoticeService.archiveExpiredNotices(); // Clean up expired notices
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNoticeStats() async {
    Map<String, int> stats = await NoticeService.getNoticeStats(widget.code.toString());
    setState(() {
      _noticeStats = stats;
    });
  }

  List<Map<String, dynamic>> _filterNotices(List<Map<String, dynamic>> notices) {
    if (_searchQuery.isEmpty) {
      return notices;
    }
    return notices.where((notice) =>
        notice['title']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
        notice['content']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
        notice['authorName']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true
    ).toList();
  }

  Future<void> _deleteNotice(String noticeId) async {
    try {
      bool confirmed = await AppUtils.showConfirmationDialog(
        context,
        'Delete Notice',
        'Are you sure you want to delete this notice? This action cannot be undone.',
      );

      if (confirmed) {
        bool success = await NoticeService.deleteNotice(noticeId);
        if (success) {
          AppUtils.showSuccessSnackBar(context, 'Notice deleted successfully');
          _loadNoticeStats();
        } else {
          AppUtils.showErrorSnackBar(context, 'Failed to delete notice');
        }
      }
    } catch (e) {
      AppUtils.showErrorSnackBar(context, 'Error deleting notice: ${e.toString()}');
    }
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Filter
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xff1b6e70),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                bool isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xff1b6e70),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xff1b6e70),
                    checkmarkColor: Colors.white,
                    side: const BorderSide(color: Color(0xff1b6e70)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Priority Filter
          const Text(
            'Priority',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xff1b6e70),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _priorities.map((priority) {
                bool isSelected = _selectedPriority == priority;
                Color priorityColor = _getPriorityColor(priority);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : priorityColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPriority = priority;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: priorityColor,
                    checkmarkColor: Colors.white,
                    side: BorderSide(color: priorityColor),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return const Color(0xff1b6e70);
    }
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final String formattedDate = AppUtils.formatTimestamp(notice['createdAt']);
    final bool isAdmin = AppUtils.isAdmin(widget.role);
    final String priority = notice['priority'] ?? 'normal';
    final String category = notice['category'] ?? 'general';
    final int viewCount = notice['viewCount'] ?? 0;
    final int likeCount = notice['likeCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Increment view count
          await NoticeService.incrementViewCount(notice['id']);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => notice_detail.NoticeDetail(notice: notice, userRole: widget.role),
              ),
            );
          }
        },
        child: Column(
          children: [
            // Priority and Category Header
            if (priority != 'normal' || category != 'general')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getPriorityColor(priority).withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    if (priority != 'normal') ...[
                      Icon(
                        _getPriorityIcon(priority),
                        color: _getPriorityColor(priority),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(priority),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xff1b6e70).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1b6e70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notice['title'] ?? 'No Title',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff1b6e70),
                          ),
                        ),
                      ),
                      if (isAdmin && notice['authorId'] == _auth.currentUser?.uid)
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Color(0xff1b6e70)),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteNotice(notice['id']);
                            } else if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddNotice(
                                    widget.code,
                                    widget.role,
                                    editNotice: notice,
                                  ),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  _loadNoticeStats();
                                }
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notice['content'] ?? 'No Content',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Stats Row
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notice['authorName'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$viewCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$likeCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.check_circle;
      default:
        return Icons.circle;
    }
  }

  Widget _buildStatsCard() {
    if (_noticeStats.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1b6e70), Color(0xff7a9e9f)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', _noticeStats['total'] ?? 0, Icons.campaign),
          _buildStatItem('Urgent', _noticeStats['urgent'] ?? 0, Icons.warning),
          _buildStatItem('Recent', _noticeStats['recent'] ?? 0, Icons.schedule),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildNoticesList(bool activeOnly) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getSimpleNoticesStream(activeOnly),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading notices',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xff1b6e70)),
          );
        }

        List<Map<String, dynamic>> allNotices = snapshot.data ?? [];

        // Apply client-side filtering
        List<Map<String, dynamic>> filteredNotices = allNotices.where((notice) {
          if (_selectedCategory != 'all' && notice['category'] != _selectedCategory) {
            return false;
          }
          if (_selectedPriority != 'all' && notice['priority'] != _selectedPriority) {
            return false;
          }
          return true;
        }).toList();

        filteredNotices = _filterNotices(filteredNotices);

        if (filteredNotices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? (activeOnly ? 'No active notices found' : 'No archived notices found')
                      : 'No notices match your search',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                if (_searchQuery.isNotEmpty || _selectedCategory != 'all' || _selectedPriority != 'all') ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedCategory = 'all';
                        _selectedPriority = 'all';
                        _searchController.clear();
                      });
                    },
                    child: const Text('Clear Filters'),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xff1b6e70),
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            itemCount: filteredNotices.length,
            itemBuilder: (context, index) {
              return _buildNoticeCard(filteredNotices[index]);
            },
          ),
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getSimpleNoticesStream(bool activeOnly) {
    return NoticeService.getNoticesStream(widget.code.toString(), activeOnly);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AppUtils.isAdmin(widget.role);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notices',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xff1b6e70),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search notices...',
                    prefixIcon: Icon(Icons.search, color: Color(0xff1b6e70)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.campaign, size: 18),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            'Active (${_noticeStats['active'] ?? 0})',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.archive, size: 18),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            'Archived (${_noticeStats['archived'] ?? 0})',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics, size: 18),
                        SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            'Stats',
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Notices Tab
          Column(
            children: [
              _buildFilterChips(),
              Expanded(child: _buildNoticesList(true)),
            ],
          ),

          // Archived Notices Tab
          Column(
            children: [
              _buildFilterChips(),
              Expanded(child: _buildNoticesList(false)),
            ],
          ),

          // Stats Tab
          SingleChildScrollView(
            child: Column(
              children: [
                _buildStatsCard(),
                // Add more stats widgets here if needed
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xff1b6e70),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNotice(widget.code, widget.role),
                  ),
                ).then((result) {
                  if (result == true) {
                    _loadNoticeStats();
                  }
                });
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
