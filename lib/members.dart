import 'package:flutter/material.dart';
import 'models/member.dart';
import 'services/members_service.dart';
import 'widget/member_card.dart';

class MembersPage extends StatefulWidget {
  @override
  _MembersPageState createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Member? _currentUser;
  String? _joinCode;
  bool _isLoading = true;
  Map<String, int> _statistics = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
    _updateLastActive();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user data
      _currentUser = await MembersService.getCurrentMember();
      _joinCode = await MembersService.getCurrentUserJoinCode();

      if (_joinCode != null) {
        _statistics = await MembersService.getMemberStatistics(_joinCode!);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing data: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load member data');
    }
  }

  Future<void> _updateLastActive() async {
    await MembersService.updateLastActive();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteMember(Member member) async {
    try {
      final success = await MembersService.deleteMember(member.uid);
      if (success) {
        _showSuccessSnackBar('${member.name} has been removed from the group');
        // Refresh statistics
        if (_joinCode != null) {
          _statistics = await MembersService.getMemberStatistics(_joinCode!);
          setState(() {});
        }
      } else {
        _showErrorSnackBar('Failed to remove member');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _updateMemberRole(Member member, MemberRole newRole) async {
    try {
      final success = await MembersService.updateMemberRole(member.uid, newRole);
      if (success) {
        _showSuccessSnackBar('${member.name}\'s role updated successfully');
        // Refresh statistics
        if (_joinCode != null) {
          _statistics = await MembersService.getMemberStatistics(_joinCode!);
          setState(() {});
        }
      } else {
        _showErrorSnackBar('Failed to update member role');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  void _showMemberDetails(Member member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Role', member.roleDisplayName),
            _buildDetailRow('Email', member.email),
            _buildDetailRow('Roll Number', member.rollNumber),
            _buildDetailRow('Join Code', member.joinCode),
            _buildDetailRow('Joined', _formatDate(member.joinedAt)),
            if (member.lastActive != null)
              _buildDetailRow('Last Active', _formatDate(member.lastActive!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xffb8d8d8),
        appBar: AppBar(
          title: const Text('Members'),
          backgroundColor: const Color(0xff77a5b5),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_joinCode == null) {
      return Scaffold(
        backgroundColor: const Color(0xffb8d8d8),
        appBar: AppBar(
          title: const Text('Members'),
          backgroundColor: const Color(0xff77a5b5),
        ),
        body: const Center(
          child: Text('Unable to load member data. Please try again.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffb8d8d8),
      appBar: AppBar(
        title: const Text('Members'),
        backgroundColor: const Color(0xff77a5b5),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members...',
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
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStatisticsCard(),
          Expanded(child: _buildMembersList()),
        ],
      ),
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
            _buildStatItem('Total', _statistics['total'] ?? 0, Colors.blue),
            _buildStatItem('Admins', _statistics['administrators'] ?? 0, Colors.green),
            _buildStatItem('Co-Admins', _statistics['coAdministrators'] ?? 0, Colors.orange),
            _buildStatItem('Members', _statistics['generalMembers'] ?? 0, Colors.grey),
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

  Widget _buildMembersList() {
    return StreamBuilder<List<Member>>(
      stream: MembersService.getMembersByJoinCode(_joinCode!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No members found'));
        }

        List<Member> members = snapshot.data!;

        // Filter members based on search query
        if (_searchQuery.isNotEmpty) {
          members = members.where((member) {
            final query = _searchQuery.toLowerCase();
            return member.name.toLowerCase().contains(query) ||
                   member.rollNumber.toLowerCase().contains(query) ||
                   member.email.toLowerCase().contains(query);
          }).toList();
        }

        // Sort members: current user first, then by role, then by name
        members.sort((a, b) {
          // Current user first
          if (a.uid == _currentUser?.uid) return -1;
          if (b.uid == _currentUser?.uid) return 1;

          // Then by role priority
          final roleOrder = {
            MemberRole.administrator: 0,
            MemberRole.coAdministrator: 1,
            MemberRole.generalMember: 2,
          };

          final roleComparison = (roleOrder[a.role] ?? 2).compareTo(roleOrder[b.role] ?? 2);
          if (roleComparison != 0) return roleComparison;

          // Finally by name
          return a.name.compareTo(b.name);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return MemberCard(
              member: member,
              currentUser: _currentUser,
              onDelete: () => _deleteMember(member),
              onRoleChange: (newRole) => _updateMemberRole(member, newRole),
              onTap: () => _showMemberDetails(member),
            );
          },
        );
      },
    );
  }

}