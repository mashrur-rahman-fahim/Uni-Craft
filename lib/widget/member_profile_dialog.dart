import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/member.dart';
import '../utils/members_utils.dart';

class MemberProfileDialog extends StatelessWidget {
  final Member member;
  final Member? currentUser;
  final VoidCallback? onEdit;
  final Function(MemberRole)? onRoleChange;
  final VoidCallback? onDelete;

  const MemberProfileDialog({
    Key? key,
    required this.member,
    this.currentUser,
    this.onEdit,
    this.onRoleChange,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool canEdit = MembersUtils.canPerformAdminActions(currentUser, member);
    final bool canChangeRole = MembersUtils.canChangeRole(currentUser, member);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProfileImage(),
                    const SizedBox(height: 16),
                    _buildMemberInfo(),
                    const SizedBox(height: 20),
                    _buildPermissionsInfo(),
                    if (canEdit || canChangeRole) ...[
                      const SizedBox(height: 20),
                      _buildActionButtons(canEdit, canChangeRole, context),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MembersUtils.getRoleColor(member.role),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            MembersUtils.getRoleIcon(member.role),
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[300],
          child: member.photoURL.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: CachedNetworkImage(
                    imageUrl: member.photoURL,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                )
              : const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.grey,
                ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MembersUtils.getRoleColor(member.role),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              MembersUtils.getRoleIcon(member.role),
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Role', member.roleDisplayName, MembersUtils.getRoleColor(member.role)),
            const Divider(),
            _buildInfoRow('Email', member.email, Colors.grey[700]!),
            const Divider(),
            _buildInfoRow('Roll Number', member.rollNumber, Colors.grey[700]!),
            const Divider(),
            _buildInfoRow('Join Code', member.joinCode, Colors.grey[700]!),
            const Divider(),
            _buildInfoRow('Joined', _formatDate(member.joinedAt), Colors.grey[700]!),
            if (member.lastActive != null) ...[
              const Divider(),
              _buildInfoRow(
                'Last Active',
                MembersUtils.formatTimeDifference(member.lastActive!),
                _getActivityColor(member.lastActive!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsInfo() {
    return Card(
      color: MembersUtils.getRoleColor(member.role).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: MembersUtils.getRoleColor(member.role),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Permissions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: MembersUtils.getRoleColor(member.role),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              MembersUtils.getPermissionLevel(member.role),
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool canEdit, bool canChangeRole, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (canChangeRole)
          ElevatedButton.icon(
            onPressed: () => _showRoleChangeDialog(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Change Role'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        if (canEdit)
          ElevatedButton.icon(
            onPressed: () => _showDeleteConfirmation(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  void _showRoleChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Change Role for ${member.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MemberRole.values.map((role) {
            return RadioListTile<MemberRole>(
              title: Text(Member.roleToString(role)),
              subtitle: Text(
                MembersUtils.getPermissionLevel(role),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              value: role,
              groupValue: member.role,
              onChanged: (value) {
                if (value != null && onRoleChange != null) {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context); // Close profile dialog
                  onRoleChange!(value);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to remove ${member.name} from the group?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context); // Close profile dialog
              if (onDelete != null) onDelete!();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getActivityColor(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inDays == 0) {
      return Colors.green; // Active today
    } else if (difference.inDays <= 7) {
      return Colors.orange; // Active this week
    } else {
      return Colors.red; // Inactive
    }
  }
}
