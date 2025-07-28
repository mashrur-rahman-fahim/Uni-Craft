import 'package:flutter/material.dart';
import '../models/poll.dart';

class PollCard extends StatelessWidget {
  final Poll poll;
  final VoidCallback onTap;
  final Function(String, int) onVote;
  final bool canEdit;
  final bool canDelete;

  const PollCard({
    Key? key,
    required this.poll,
    required this.onTap,
    required this.onVote,
    this.canEdit = false,
    this.canDelete = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildTitle(),
              if (poll.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDescription(),
              ],
              const SizedBox(height: 16),
              _buildStatusAndStats(),
              const SizedBox(height: 16),
              _buildQuickVoteSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _getStatusColor(),
          child: Icon(
            _getStatusIcon(),
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                poll.creatorName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                _formatDate(poll.createdAt),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      poll.title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xff1b6e70),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription() {
    return Text(
      poll.description,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatusAndStats() {
    return Row(
      children: [
        Icon(
          Icons.how_to_vote,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '${poll.totalVotes} votes',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.list_alt,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '${poll.options.length} options',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        if (poll.expiresAt != null) ...[
          const SizedBox(width: 16),
          Icon(
            Icons.schedule,
            size: 16,
            color: poll.isExpired ? Colors.red : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            poll.isExpired ? 'Expired' : 'Expires ${_formatDate(poll.expiresAt!)}',
            style: TextStyle(
              fontSize: 14,
              color: poll.isExpired ? Colors.red : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickVoteSection() {
    if (!poll.canVote || poll.options.isEmpty) {
      return _buildResultsPreview();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Vote:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: poll.options.take(3).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return _buildQuickVoteButton(option.text, index);
          }).toList(),
        ),
        if (poll.options.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+${poll.options.length - 3} more options',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickVoteButton(String text, int index) {
    return ElevatedButton(
      onPressed: () => onVote(poll.id, index),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff77a5b5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 2,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildResultsPreview() {
    if (poll.options.isEmpty || poll.totalVotes == 0) {
      return Text(
        'No votes yet',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final topOption = poll.getWinningOption();
    if (topOption == null) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leading Option:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff77a5b5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xff77a5b5).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  topOption.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff77a5b5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${topOption.votes} votes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (poll.isExpired) return Colors.red;
    switch (poll.status) {
      case PollStatus.active:
        return Colors.green;
      case PollStatus.closed:
        return Colors.orange;
      case PollStatus.draft:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (poll.isExpired) return Icons.timer_off;
    switch (poll.status) {
      case PollStatus.active:
        return Icons.play_circle;
      case PollStatus.closed:
        return Icons.stop_circle;
      case PollStatus.draft:
        return Icons.edit;
    }
  }

  String _getStatusText() {
    if (poll.isExpired) return 'Expired';
    switch (poll.status) {
      case PollStatus.active:
        return 'Active';
      case PollStatus.closed:
        return 'Closed';
      case PollStatus.draft:
        return 'Draft';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
