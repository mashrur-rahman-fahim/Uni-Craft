import 'package:flutter/material.dart';
import '../models/poll.dart';

class PollDetailsDialog extends StatefulWidget {
  final Poll poll;
  final Function(String, int) onVote;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;

  const PollDetailsDialog({
    Key? key,
    required this.poll,
    required this.onVote,
    this.onEdit,
    this.onDelete,
    this.onToggleStatus,
  }) : super(key: key);

  @override
  _PollDetailsDialogState createState() => _PollDetailsDialogState();
}

class _PollDetailsDialogState extends State<PollDetailsDialog> {
  int? _selectedOption;
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    // Check if user has already voted (this would be based on Firebase Auth)
    // For now, we'll assume they haven't voted
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPollInfo(),
                    const SizedBox(height: 20),
                    _buildOptions(),
                    if (widget.poll.showResults) ...[
                      const SizedBox(height: 20),
                      _buildResults(),
                    ],
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(),
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.poll.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'by ${widget.poll.creatorName}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
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

  Widget _buildPollInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.poll.description.isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.poll.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                _buildInfoChip(
                  Icons.how_to_vote,
                  '${widget.poll.totalVotes} votes',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.schedule,
                  _formatDate(widget.poll.createdAt),
                  Colors.green,
                ),
              ],
            ),
            if (widget.poll.expiresAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoChip(
                Icons.timer,
                widget.poll.isExpired
                    ? 'Expired'
                    : 'Expires ${_formatDate(widget.poll.expiresAt!)}',
                widget.poll.isExpired ? Colors.red : Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Options',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (widget.poll.canVote && !_hasVoted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'You can vote',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.poll.options.length,
              itemBuilder: (context, index) {
                final option = widget.poll.options[index];
                final isSelected = _selectedOption == index;
                final canVote = widget.poll.canVote && !_hasVoted;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: canVote ? () => _selectOption(index) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xff77a5b5).withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xff77a5b5)
                              : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? const Color(0xff77a5b5)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xff77a5b5)
                                    : Colors.grey,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? const Color(0xff77a5b5) : Colors.black87,
                              ),
                            ),
                          ),
                          if (widget.poll.showResults && widget.poll.totalVotes > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xff77a5b5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${option.votes}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff77a5b5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (widget.poll.canVote && !_hasVoted && _selectedOption != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitVote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff77a5b5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Submit Vote',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (!widget.poll.showResults || widget.poll.totalVotes == 0) {
      return Container();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Results',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.poll.options.length,
              itemBuilder: (context, index) {
                final option = widget.poll.options[index];
                final percentage = widget.poll.getOptionPercentage(index);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option.text,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff77a5b5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff77a5b5)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasActions = widget.onEdit != null ||
                      widget.onDelete != null ||
                      widget.onToggleStatus != null;

    if (!hasActions) return Container();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onEdit != null)
                  ElevatedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (widget.onToggleStatus != null)
                  ElevatedButton.icon(
                    onPressed: widget.onToggleStatus,
                    icon: Icon(
                      widget.poll.status == PollStatus.active
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      size: 16,
                    ),
                    label: Text(
                      widget.poll.status == PollStatus.active ? 'Close' : 'Open',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.poll.status == PollStatus.active
                          ? Colors.orange
                          : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (widget.onDelete != null)
                  ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectOption(int index) {
    if (widget.poll.allowMultipleVotes) {
      // Handle multiple votes logic here
      setState(() => _selectedOption = index);
    } else {
      setState(() => _selectedOption = index);
    }
  }

  void _submitVote() {
    if (_selectedOption != null) {
      widget.onVote(widget.poll.id, _selectedOption!);
      setState(() => _hasVoted = true);
      Navigator.of(context).pop();
    }
  }

  Color _getStatusColor() {
    if (widget.poll.isExpired) return Colors.red;
    switch (widget.poll.status) {
      case PollStatus.active:
        return Colors.green;
      case PollStatus.closed:
        return Colors.orange;
      case PollStatus.draft:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (widget.poll.isExpired) return Icons.timer_off;
    switch (widget.poll.status) {
      case PollStatus.active:
        return Icons.poll;
      case PollStatus.closed:
        return Icons.stop_circle;
      case PollStatus.draft:
        return Icons.edit;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
