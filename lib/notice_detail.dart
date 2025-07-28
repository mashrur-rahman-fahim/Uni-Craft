import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_craft/services/notice_service.dart';
import 'package:uni_craft/utils.dart';
import 'package:intl/intl.dart';

class NoticeDetail extends StatefulWidget {
  final Map<String, dynamic> notice;
  final String userRole;

  const NoticeDetail({
    super.key,
    required this.notice,
    required this.userRole,
  });

  @override
  State<NoticeDetail> createState() => _NoticeDetailState();
}

class _NoticeDetailState extends State<NoticeDetail> {
  bool _isLiked = false;
  int _likeCount = 0;
  int _viewCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeNoticeData();
    _checkLikeStatus();
  }

  void _initializeNoticeData() {
    _likeCount = widget.notice['likeCount'] ?? 0;
    _viewCount = widget.notice['viewCount'] ?? 0;
  }

  Future<void> _checkLikeStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      bool liked = await NoticeService.isLikedByUser(widget.notice['id'], currentUser.uid);
      setState(() {
        _isLiked = liked;
      });
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool success = await NoticeService.toggleLike(widget.notice['id'], currentUser.uid);
      if (success) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
        
        AppUtils.showSuccessSnackBar(
          context, 
          _isLiked ? 'Notice liked!' : 'Like removed'
        );
      }
    } catch (e) {
      AppUtils.showErrorSnackBar(context, 'Error updating like: ${e.toString()}');
      print("Error toggling like: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  Widget _buildHeader() {
    final String priority = widget.notice['priority'] ?? 'normal';
    final String category = widget.notice['category'] ?? 'general';
    final String formattedDate = AppUtils.formatTimestamp(widget.notice['createdAt']);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getPriorityColor(priority),
            _getPriorityColor(priority).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getPriorityColor(priority).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority and Category Row
            Row(
              children: [
                if (priority != 'normal') ...[
                  Icon(
                    _getPriorityIcon(priority),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    priority.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.notice['title'] ?? 'No Title',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Author and Date
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.notice['authorName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff1b6e70),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.notice['content'] ?? 'No content available',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Views
          Column(
            children: [
              Icon(
                Icons.visibility,
                color: Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                '$_viewCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b6e70),
                ),
              ),
              Text(
                'Views',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          // Likes
          Column(
            children: [
              GestureDetector(
                onTap: _isLoading ? null : _toggleLike,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isLiked ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_likeCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b6e70),
                ),
              ),
              Text(
                'Likes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          // Share
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  // Implement share functionality
                  AppUtils.showSuccessSnackBar(context, 'Share functionality coming soon!');
                },
                child: Icon(
                  Icons.share,
                  color: Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b6e70),
                ),
              ),
              Text(
                'Share',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    final List<String> tags = List<String>.from(widget.notice['tags'] ?? []);
    final expiryDate = widget.notice['expiryDate'];

    if (tags.isEmpty && expiryDate == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.isNotEmpty) ...[
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xff1b6e70),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tags.map((tag) => Chip(
                label: Text(
                  tag,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: const Color(0xff1b6e70).withValues(alpha: 0.1),
                side: const BorderSide(color: Color(0xff1b6e70)),
              )).toList(),
            ),
          ],
          if (tags.isNotEmpty && expiryDate != null) const SizedBox(height: 16),
          if (expiryDate != null) ...[
            const Text(
              'Expires On',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xff1b6e70),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(expiryDate.toDate()),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notice Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xff1b6e70),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildContent(),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 16),
            _buildAdditionalInfo(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
