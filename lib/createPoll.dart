import 'package:flutter/material.dart';
import 'services/polls_service.dart';
import 'services/members_service.dart';

class CreatePollPage extends StatefulWidget {
  final String joinCode;

  const CreatePollPage({Key? key, required this.joinCode}) : super(key: key);

  @override
  _CreatePollPageState createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isLoading = false;
  bool _allowMultipleVotes = false;
  bool _showResults = true;
  bool _anonymousVoting = false;
  bool _hasExpiration = false;
  DateTime? _expirationDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 10) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2 && index >= 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _selectExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (timePicked != null) {
        setState(() {
          _expirationDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      }
    }
  }

  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final optionTexts = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (optionTexts.length < 2) {
        throw Exception('Please provide at least 2 options');
      }

      final pollId = await PollsService.createPoll(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        optionTexts: optionTexts,
        joinCode: widget.joinCode,
        expiresAt: _hasExpiration ? _expirationDate : null,
        allowMultipleVotes: _allowMultipleVotes,
        showResults: _showResults,
        anonymousVoting: _anonymousVoting,
      );

      if (pollId != null) {
        // Send notifications to group members
        await _sendPollNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poll created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPollNotifications() async {
    // This would integrate with your notification service
    // For now, we'll just update last active status
    await MembersService.updateLastActive();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffb8d8d8),
      appBar: AppBar(
        title: const Text('Create Poll'),
        backgroundColor: const Color(0xff77a5b5),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildPollDetailsCard(),
              const SizedBox(height: 16),
              _buildOptionsCard(),
              const SizedBox(height: 16),
              _buildSettingsCard(),
              const SizedBox(height: 24),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff77a5b5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.poll,
                    color: Color(0xff77a5b5),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Poll',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1b6e70),
                        ),
                      ),
                      Text(
                        'Engage your group with interactive polls',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
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
    );
  }

  Widget _buildPollDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Poll Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff1b6e70),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Poll Title *',
                hintText: 'What would you like to ask?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a poll title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Provide additional context for your poll',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Poll Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1b6e70),
                  ),
                ),
                const Spacer(),
                if (_optionControllers.length < 10)
                  IconButton(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add_circle),
                    color: const Color(0xff77a5b5),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _optionControllers.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Option ${index + 1}${index < 2 ? ' *' : ''}',
                            hintText: 'Enter option text',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xff77a5b5),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          validator: index < 2
                              ? (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Option ${index + 1} is required';
                                  }
                                  return null;
                                }
                              : null,
                        ),
                      ),
                      if (index >= 2)
                        IconButton(
                          onPressed: () => _removeOption(index),
                          icon: const Icon(Icons.remove_circle),
                          color: Colors.red,
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

  Widget _buildSettingsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Poll Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff1b6e70),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Allow Multiple Votes'),
              subtitle: const Text('Users can vote for multiple options'),
              value: _allowMultipleVotes,
              onChanged: (value) => setState(() => _allowMultipleVotes = value),
              activeColor: const Color(0xff77a5b5),
            ),
            SwitchListTile(
              title: const Text('Show Results'),
              subtitle: const Text('Display poll results after voting'),
              value: _showResults,
              onChanged: (value) => setState(() => _showResults = value),
              activeColor: const Color(0xff77a5b5),
            ),
            SwitchListTile(
              title: const Text('Anonymous Voting'),
              subtitle: const Text('Hide voter identities'),
              value: _anonymousVoting,
              onChanged: (value) => setState(() => _anonymousVoting = value),
              activeColor: const Color(0xff77a5b5),
            ),
            SwitchListTile(
              title: const Text('Set Expiration'),
              subtitle: const Text('Automatically close poll after a date'),
              value: _hasExpiration,
              onChanged: (value) => setState(() => _hasExpiration = value),
              activeColor: const Color(0xff77a5b5),
            ),
            if (_hasExpiration) ...[
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _expirationDate == null
                      ? 'Select Expiration Date'
                      : 'Expires: ${_expirationDate!.day}/${_expirationDate!.month}/${_expirationDate!.year} at ${_expirationDate!.hour}:${_expirationDate!.minute.toString().padLeft(2, '0')}',
                ),
                leading: const Icon(Icons.schedule),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectExpirationDate,
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createPoll,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff77a5b5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.create, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Create Poll',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}