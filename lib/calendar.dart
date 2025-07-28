import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


class Calendar extends StatefulWidget {
  final String uid_ad;
  final String role;

  const Calendar(this.uid_ad, this.role, {Key? key}) : super(key: key);

  @override
  _CalendarState createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  DateTime today = DateTime.now();
  Map<String, List<Map<String, dynamic>>> events = {};
  List<String> token = [];
  String? joinCode;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserEvents();
  }

  String _formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _loadUserEvents() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("Profile")
          .doc(widget.uid_ad)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('events') && data['events'] != null) {
          Map<String, dynamic> firebaseEvents = data['events'];
          setState(() {
            events = firebaseEvents.map((key, value) {
              if (value is List) {
                return MapEntry(key, List<Map<String, dynamic>>.from(
                  value.map((item) => item is Map<String, dynamic>
                    ? item
                    : {'title': item.toString(), 'id': DateTime.now().millisecondsSinceEpoch.toString()})
                ));
              }
              return MapEntry(key, <Map<String, dynamic>>[]);
            });
          });
        }
      }
    } catch (e) {
      print("Error loading events: $e");
    }
  }

  void _onDaySelected(DateTime day, DateTime focusDay) {
    setState(() {
      today = day;
    });
  }

  Future<void> _onEventAdded(String eventTitle) async {
    if (eventTitle.trim().isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      String dateKey = _formatDateKey(today);
      String eventId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> newEvent = {
        'id': eventId,
        'title': eventTitle.trim(),
        'date': dateKey,
        'createdAt': Timestamp.now(),
        'createdBy': widget.uid_ad,
      };

      setState(() {
        if (events.containsKey(dateKey)) {
          events[dateKey]!.add(newEvent);
        } else {
          events[dateKey] = [newEvent];
        }
      });

      // Update Firebase
      await FirebaseFirestore.instance
          .collection("Profile")
          .doc(widget.uid_ad)
          .update({
        "events": events,
        "lastUpdated": Timestamp.now(),
      });

      // Send notifications if admin
      if (widget.role == "Administrator" && token.isNotEmpty) {
        await _sendEventNotification(eventTitle);
      }

    } catch (e) {
      print("Error adding event: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add event: $e")),
      );
      // Revert local state on error
      await _loadUserEvents();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    setState(() {
      isLoading = true;
    });

    try {
      String dateKey = _formatDateKey(today);

      setState(() {
        if (events.containsKey(dateKey)) {
          events[dateKey]!.removeWhere((e) => e['id'] == event['id']);
          if (events[dateKey]!.isEmpty) {
            events.remove(dateKey);
          }
        }
      });

      // Update Firebase
      await FirebaseFirestore.instance
          .collection("Profile")
          .doc(widget.uid_ad)
          .update({
        "events": events,
        "lastUpdated": Timestamp.now(),
      });

    } catch (e) {
      print("Error deleting event: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete event: $e")),
      );
      // Revert local state on error
      await _loadUserEvents();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendEventNotification(String eventTitle) async {
    try {
      for (String userToken in token) {
        var data = {
          'to': userToken,
          'priority': 'high',
          'notification': {
            'title': "New Event Added",
            'body': "$eventTitle on ${_formatDateKey(today)}",
          },
          'data': {
            'type': 'calendar_event',
            'date': _formatDateKey(today),
            'event': eventTitle,
          }
        };

        await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          body: jsonEncode(data),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'key=AAAA2TCZdvQ:APA91bHvIxfRdJ4yoEJXHDrPKBcMeWmf-VlVcHuh6gvun7QUGwrFiN9dobcO7H8jx1Z7ayt3nXEV2yjnoWB3_VbdranUUy8UNRfuEDOtb9vCWqi-DXxmZk-1Bnul2UfUnX1zhi-pm9vH'
          },
        );
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    String dateKey = _formatDateKey(day);
    return events[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Academic Calendar"),
        backgroundColor: Color(0xff7a9e9f),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUserEvents,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection("Profile").snapshots(),
            builder: (context, snapshots) {
              if (snapshots.hasData) {
                token.clear();
                var res = snapshots.data!.docs.toList();

                for (var r in res) {
                  if (r['uid'] == widget.uid_ad) {
                    joinCode = r['code'];
                  }
                }

                for (var r in res) {
                  if (r['code'] == joinCode && r['role'] != "Administrator") {
                    token.add(r['token']);
                  }
                }
              }
              return const SizedBox.shrink();
            }
          ),
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/calendar_bg04.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.75),
                  BlendMode.dstATop,
                ),
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Selected Day: ${_formatDateKey(today)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TableCalendar<Map<String, dynamic>>(
                      locale: "en_US",
                      rowHeight: 43,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        decoration: BoxDecoration(
                          color: Color(0xff7a9e9f),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        titleTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        markerDecoration: BoxDecoration(
                          color: Color(0xff476d79),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Color(0xff7a9e9f),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Color(0xff476d79).withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      availableGestures: AvailableGestures.all,
                      selectedDayPredicate: (day) => isSameDay(day, today),
                      focusedDay: today,
                      firstDay: DateTime.utc(2020, 01, 01),
                      lastDay: DateTime.utc(2030, 12, 31),
                      onDaySelected: _onDaySelected,
                      eventLoader: _getEventsForDay,
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isNotEmpty) {
                            return Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xff476d79),
                                  shape: BoxShape.circle,
                                ),
                                width: 16,
                                height: 16,
                                child: Center(
                                  child: Text(
                                    '${events.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TodoListView(
                    role: widget.role,
                    uid: widget.uid_ad,
                    selectedDate: today,
                    events: _getEventsForDay(today),
                    onEventAdded: _onEventAdded,
                    onDeleteEvent: _deleteEvent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Color(0xffb8d8d8),
    );
  }
}

class TodoListView extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> events;
  final Function(String) onEventAdded;
  final Function(Map<String, dynamic>) onDeleteEvent;
  final String uid;
  final String role;

  const TodoListView({
    required this.selectedDate,
    required this.events,
    required this.onEventAdded,
    required this.onDeleteEvent,
    required this.uid,
    required this.role,
    Key? key,
  }) : super(key: key);

  @override
  _TodoListViewState createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Events for ${DateFormat('MMM dd, yyyy').format(widget.selectedDate)}",
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.events.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text(
                  "No events for this day",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.events.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final event = widget.events[index];
                return ListTile(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xff476d79),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    event['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: event['createdAt'] != null
                      ? Text(
                          "Added: ${DateFormat('MMM dd, HH:mm').format(event['createdAt'].toDate())}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: widget.role == "Administrator"
                      ? IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade400,
                          ),
                          onPressed: () => _showDeleteDialog(event),
                        )
                      : null,
                );
              },
            ),
          if (widget.role == "Administrator") ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: "Add new event...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xff7a9e9f)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: _addEvent,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff7a9e9f),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _addEvent([String? value]) {
    final newEvent = value ?? textController.text;
    if (newEvent.isNotEmpty) {
      widget.onEventAdded(newEvent);
      textController.clear();
    }
  }

  void _showDeleteDialog(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Event"),
          content: Text("Are you sure you want to delete '${event['title']}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDeleteEvent(event);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
