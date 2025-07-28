import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/member.dart';

class MemberCard extends StatelessWidget {
  final Member member;
  final Member? currentUser;
  final VoidCallback? onDelete;
  final Function(MemberRole)? onRoleChange;
  final VoidCallback? onTap;

  const MemberCard({
    Key? key,
    required this.member,
    this.currentUser,
    this.onDelete,
    this.onRoleChange,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = currentUser?.uid == member.uid;
    final bool canDelete = currentUser?.canRemove(member) ?? false;
    final bool canChangeRole = currentUser?.canChangeRole(member) ?? false;

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentUser
          ? const BorderSide(color: Colors.black, width: 2)
          : BorderSide.none,
      ),
      color: _getCardColor(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildAvatar(),
              const SizedBox(height: 12),
              _buildUserInfo(),
              if (canDelete || canChangeRole) ...[
                const SizedBox(height: 12),
                _buildActionButtons(canDelete, canChangeRole, context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: Colors.grey[300],
          child: member.photoURL.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: CachedNetworkImage(
                  imageUrl: member.photoURL,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.person,
                    size: 35,
                    color: Colors.grey,
                  ),
                ),
              )
            : const Icon(
                Icons.person,
                size: 35,
                color: Colors.grey,
              ),
        ),
        if (member.isAdmin)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        if (member.isCoAdmin)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.supervisor_account,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          member.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor().withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            member.roleDisplayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getRoleColor(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.badge, 'Roll: ${member.rollNumber}'),
        const SizedBox(height: 4),
        _buildInfoRow(Icons.email, member.email),
        if (member.lastActive != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.access_time,
            'Last active: ${_formatLastActive(member.lastActive!)}',
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool canDelete, bool canChangeRole, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (canChangeRole)
          ElevatedButton.icon(
            onPressed: () => _showRoleChangeDialog(context),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Role'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        if (canDelete)
          ElevatedButton.icon(
            onPressed: () => _showDeleteConfirmation(context),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Remove'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
      ],
    );
  }

  void _showRoleChangeDialog(BuildContext context) {
    if (currentUser == null) return;
    
    final availableRoles = currentUser!.getAvailableRolesToAssign(member);
    
    if (availableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to change this member\'s role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${member.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current role: ${member.roleDisplayName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...availableRoles.map((role) {
              return RadioListTile<MemberRole>(
                title: Text(Member.roleToString(role)),
                value: role,
                groupValue: member.role,
                onChanged: (value) {
                  if (value != null && onRoleChange != null) {
                    Navigator.pop(context);
                    onRoleChange!(value);
                  }
                },
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${member.name} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onDelete != null) onDelete!();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getCardColor() {
    if (member.isAdmin) return Colors.blue.shade100;
    if (member.isCoAdmin) return Colors.orange.shade100;
    return Colors.white;
  }

  Color _getRoleColor() {
    if (member.isAdmin) return Colors.blue;
    if (member.isCoAdmin) return Colors.orange;
    return Colors.green;
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
