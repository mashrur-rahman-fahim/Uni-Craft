import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/event_service.dart';

class AdminEventManager extends StatefulWidget {
  final String adminUid;
  final String role;
  const AdminEventManager({
    Key? key,
    required this.adminUid,
    required this.role,
  }) : super(key: key);

  @override
  _AdminEventManagerState createState() => _AdminEventManagerState();
}

class _AdminEventManagerState extends State<AdminEventManager> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedEventType = 'general';
  bool _isLoading = false;

  final List<String> eventTypes = [
    'general',
    'exam',
    'assignment',
    'holiday',
    'meeting',
    'workshop',
    'seminar',
    'deadline',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.role != "Administrator") {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Access Denied"),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Text(
            "Only administrators can access this feature",
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Manager"),
        backgroundColor: const Color(0xff7a9e9f),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xff7a9e9f).withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildAddEventCard(),
              const SizedBox(height: 24),
              _buildBulkEventCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: const Color(0xff7a9e9f)),
                const SizedBox(width: 8),
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionChip(
                  "Today's Class",
                  Icons.school,
                  () => _quickAddEvent("Today's Class", 'general'),
                ),
                _buildQuickActionChip(
                  "Assignment Due",
                  Icons.assignment,
                  () => _quickAddEvent("Assignment Due", 'assignment'),
                ),
                _buildQuickActionChip(
                  "Exam Alert",
                  Icons.quiz,
                  () => _quickAddEvent("Exam", 'exam'),
                ),
                _buildQuickActionChip(
                  "Holiday",
                  Icons.celebration,
                  () => _quickAddEvent("Holiday", 'holiday'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: const Color(0xff7a9e9f).withValues(alpha: 0.1),
      side: BorderSide(color: const Color(0xff7a9e9f).withValues(alpha: 0.3)),
    );
  }

  Widget _buildAddEventCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle, color: const Color(0xff7a9e9f)),
                const SizedBox(width: 8),
                const Text(
                  "Add New Event",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Event Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Event Title",
                hintText: "Enter event title",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            // Event Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Description (Optional)",
                hintText: "Enter event description",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 16),

            // Date Picker
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Event Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedEventType,
              decoration: InputDecoration(
                labelText: "Event Type",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.category),
              ),
              items: eventTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedEventType = value ?? 'general';
                });
              },
            ),
            const SizedBox(height: 24),

            // Add Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _addEvent,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? "Adding..." : "Add Event"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff7a9e9f),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkEventCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.playlist_add, color: const Color(0xff7a9e9f)),
                const SizedBox(width: 8),
                const Text(
                  "Bulk Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addSampleEvents,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text("Add Sample Events"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addWeeklySchedule,
                    icon: const Icon(Icons.schedule),
                    label: const Text("Add Weekly Schedule"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _quickAddEvent(String title, String type) async {
    setState(() {
      _titleController.text = title;
      _selectedEventType = type;
    });

    // Auto-add the event with current date
    await _addEvent();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff7a9e9f),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _addEvent() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter event title');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get group code from the admin's profile
      String? groupCode = await _getAdminGroupCode();

      if (groupCode == null) {
        _showErrorSnackBar('Could not find group code');
        return;
      }

      final eventId = await EventService.addEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        groupCode: groupCode,
        category: _selectedEventType,
      );

      if (eventId != null) {
        _showSuccessSnackBar('Event added successfully!');
        _clearForm();
      } else {
        _showErrorSnackBar('Failed to add event');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _getAdminGroupCode() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Profile')
          .doc(widget.adminUid)
          .get();

      if (doc.exists) {
        return doc.data()?['code'] as String?;
      }
    } catch (e) {
      print('Error getting admin group code: $e');
    }
    return null;
  }

  Future<void> _addSampleEvents() async {
    List<Map<String, dynamic>> sampleEvents = [
      {
        'title': 'Mathematics Class',
        'date': DateTime.now().add(const Duration(days: 1)),
        'type': 'general',
        'description': 'Regular mathematics class'
      },
      {
        'title': 'Physics Lab',
        'date': DateTime.now().add(const Duration(days: 2)),
        'type': 'general',
        'description': 'Physics laboratory session'
      },
      {
        'title': 'Chemistry Assignment Due',
        'date': DateTime.now().add(const Duration(days: 3)),
        'type': 'assignment',
        'description': 'Submit chemistry assignment'
      },
      {
        'title': 'Mid-term Exam',
        'date': DateTime.now().add(const Duration(days: 7)),
        'type': 'exam',
        'description': 'Mid-term examination'
      },
    ];

    int added = await EventService.addMultipleEvents(
      adminUid: widget.adminUid,
      eventsList: sampleEvents,
      sendNotification: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added $added sample events"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _addWeeklySchedule() async {
    List<Map<String, dynamic>> weeklyEvents = [];
    DateTime startDate = DateTime.now();

    // Add events for next 7 days
    for (int i = 0; i < 7; i++) {
      DateTime eventDate = startDate.add(Duration(days: i));
      String dayName = DateFormat('EEEE').format(eventDate);

      weeklyEvents.add({
        'title': '$dayName Classes',
        'date': eventDate,
        'type': 'general',
        'description': 'Regular classes for $dayName'
      });
    }

    int added = await EventService.addMultipleEvents(
      adminUid: widget.adminUid,
      eventsList: weeklyEvents,
      sendNotification: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added $added weekly events"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedEventType = 'general';
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
