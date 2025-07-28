import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/poll.dart';
import 'services/polls_service.dart';
import 'widget/poll_card.dart';
import 'widget/poll_details_dialog.dart';

class ViewPollsPage extends StatefulWidget {
  final String joinCode;
  final String userRole;

  const ViewPollsPage({
    Key? key,
    required this.joinCode,
    required this.userRole,
  }) : super(key: key);

  @override
  _ViewPollsPageState createState() => _ViewPollsPageState();
}

class _ViewPollsPageState extends State<ViewPollsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await PollsService.getPollStatistics(widget.joinCode);
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showPollDetails(Poll poll) {
    showDialog(
      context: context,
      builder: (context) => PollDetailsDialog(
        poll: poll,
        onVote: _handleVote,
        onEdit: _canEditPoll(poll) ? () => _editPoll(poll) : null,
        onDelete: _canDeletePoll(poll) ? () => _deletePoll(poll) : null,
        onToggleStatus: _canEditPoll(poll) ? () => _togglePollStatus(poll) : null,
      ),
    );
  }

  Future<void> _handleVote(String pollId, int optionIndex) async {
    try {
      await PollsService.voteOnPoll(pollId: pollId, optionIndex: optionIndex);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vote recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePoll(Poll poll) async {
    final confirmed = await _showConfirmationDialog(
      'Delete Poll',
      'Are you sure you want to delete "${poll.title}"? This action cannot be undone.',
    );

    if (confirmed) {
      try {
        await PollsService.deletePoll(poll.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStatistics(); // Refresh statistics
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting poll: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePollStatus(Poll poll) async {
    final newStatus = poll.status == PollStatus.active
        ? PollStatus.closed
        : PollStatus.active;

    try {
      await PollsService.updatePollStatus(poll.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Poll ${newStatus == PollStatus.active ? 'opened' : 'closed'} successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadStatistics(); // Refresh statistics
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating poll: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editPoll(Poll poll) {
    // Navigate to edit poll page (would be implemented)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  bool _canEditPoll(Poll poll) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null &&
           poll.creatorUid == currentUser.uid &&
           (widget.userRole == 'Administrator' || widget.userRole == 'Co-Administrator');
  }

  bool _canDeletePoll(Poll poll) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null &&
           (poll.creatorUid == currentUser.uid || widget.userRole == 'Administrator');
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffb8d8d8),
      appBar: AppBar(
        title: const Text('Polls'),
        backgroundColor: const Color(0xff77a5b5),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              _buildSearchBar(),
              _buildTabBar(),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (!_isLoading) _buildStatisticsCard(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search polls...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      tabs: const [
        Tab(text: 'All Polls'),
        Tab(text: 'Active'),
        Tab(text: 'Closed'),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', _statistics['totalPolls'] ?? 0, Colors.blue),
            _buildStatItem('Active', _statistics['activePolls'] ?? 0, Colors.green),
            _buildStatItem('Closed', _statistics['closedPolls'] ?? 0, Colors.orange),
            _buildStatItem('Votes', _statistics['totalVotes'] ?? 0, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPollsList(null), // All polls
        _buildPollsList(PollStatus.active), // Active polls
        _buildPollsList(PollStatus.closed), // Closed polls
      ],
    );
  }

  Widget _buildPollsList(PollStatus? statusFilter) {
    return StreamBuilder<List<Poll>>(
      stream: PollsService.getPollsByJoinCode(widget.joinCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        List<Poll> polls = snapshot.data!;

        // Filter by status
        if (statusFilter != null) {
          polls = polls.where((poll) {
            if (statusFilter == PollStatus.active) {
              return poll.isActive;
            } else {
              return poll.status == statusFilter;
            }
          }).toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          polls = polls.where((poll) {
            final query = _searchQuery.toLowerCase();
            return poll.title.toLowerCase().contains(query) ||
                   poll.description.toLowerCase().contains(query) ||
                   poll.creatorName.toLowerCase().contains(query);
          }).toList();
        }

        if (polls.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: polls.length,
          itemBuilder: (context, index) {
            final poll = polls[index];
            return PollCard(
              poll: poll,
              onTap: () => _showPollDetails(poll),
              onVote: _handleVote,
              canEdit: _canEditPoll(poll),
              canDelete: _canDeletePoll(poll),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.poll_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No polls found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Create your first poll to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
