import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class TimePlannerPage extends StatefulWidget {
  @override
  _TimePlannerPageState createState() => _TimePlannerPageState();
}

class _TimePlannerPageState extends State<TimePlannerPage> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Meeting> meetings = [];
  Meeting? selectedMeeting;
  Color selectedColor = const Color.fromARGB(255, 243, 193, 189);
  String? selectedRecurrenceType;
  int? selectedRecurrenceCount;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Meeting> _getEventsForDay(DateTime day) {
    return meetings.where((meeting) => isSameDay(meeting.from, day)).toList();
  }

  String? _generateRecurrenceRule({String? type, int? count}) {
    if (type != null && count != null) {
      return '$type;COUNT=$count';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Time Planner"),
        backgroundColor: Color(0xff7a9e9f),
        actions: [
          IconButton(
            icon: Icon(_calendarFormat == CalendarFormat.week
                ? Icons.calendar_month
                : Icons.calendar_view_week),
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.week
                    ? CalendarFormat.month
                    : CalendarFormat.week;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Meeting>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  selectedMeeting = null;
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              markersMaxCount: 3,
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    _showAddMeetingDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff7a9e9f),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Add Meeting", style: TextStyle(color: Colors.white)),
                      SizedBox(width: 10),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8.0),
                Expanded(
                  child: ListView.builder(
                    itemCount: _getEventsForDay(_selectedDay!).length,
                    itemBuilder: (context, index) {
                      final meeting = _getEventsForDay(_selectedDay!)[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 10,
                            height: 50,
                            decoration: BoxDecoration(
                              color: meeting.background,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          title: Text(meeting.eventName),
                          subtitle: Text(
                            '${DateFormat('HH:mm').format(meeting.from)} - ${DateFormat('HH:mm').format(meeting.to)}',
                          ),
                          onTap: () {
                            setState(() {
                              selectedMeeting = meeting;
                            });
                            _showMeetingDetails(context, meeting);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMeetingDetails(BuildContext context, Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Event Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event Name: ${meeting.eventName}'),
            Text('Start Time: ${DateFormat('dd/MM/yyyy HH:mm').format(meeting.from)}'),
            Text('End Time: ${DateFormat('dd/MM/yyyy HH:mm').format(meeting.to)}'),
            if (meeting.recurrenceRule != null)
              Text('Recurrence: ${meeting.recurrenceRule}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditMeetingDialog(context, meeting);
            },
            child: Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMeeting(meeting);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteMeeting(Meeting meeting) {
    setState(() {
      meetings.remove(meeting);
      selectedMeeting = null;
    });
  }

  Future<void> _showAddMeetingDialog(BuildContext context) async {
    TextEditingController eventNameController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay selectedStartTime = TimeOfDay.now();
    TimeOfDay selectedEndTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add Meeting'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: eventNameController,
                      decoration: InputDecoration(labelText: 'Event Name'),
                    ),
                    SizedBox(height: 10),
                    Text('Select Date:'),
                    ElevatedButton(
                      onPressed: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text('Select Time Range:'),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              TimeOfDay? pickedStartTime = await showTimePicker(
                                context: context,
                                initialTime: selectedStartTime,
                              );
                              if (pickedStartTime != null) {
                                setDialogState(() {
                                  selectedStartTime = pickedStartTime;
                                });
                              }
                            },
                            child: Text(
                              'Start: ${selectedStartTime.format(context)}',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              TimeOfDay? pickedEndTime = await showTimePicker(
                                context: context,
                                initialTime: selectedEndTime,
                              );
                              if (pickedEndTime != null) {
                                setDialogState(() {
                                  selectedEndTime = pickedEndTime;
                                });
                              }
                            },
                            child: Text(
                              'End: ${selectedEndTime.format(context)}',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text('Select Color:'),
                    ElevatedButton(
                      onPressed: () {
                        _openColorPicker(context, setDialogState);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                      ),
                      child: Text('Choose Color'),
                    ),
                    SizedBox(height: 10),
                    Text('Select Recurrence Type:'),
                    DropdownButton<String>(
                      value: selectedRecurrenceType,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          child: Text('None'),
                          value: null,
                        ),
                        DropdownMenuItem(
                          child: Text('Daily'),
                          value: 'FREQ=DAILY',
                        ),
                        DropdownMenuItem(
                          child: Text('Weekly'),
                          value: 'FREQ=WEEKLY',
                        ),
                        DropdownMenuItem(
                          child: Text('Monthly'),
                          value: 'FREQ=MONTHLY',
                        ),
                      ],
                      onChanged: (String? type) {
                        setDialogState(() {
                          selectedRecurrenceType = type;
                        });
                      },
                    ),
                    if (selectedRecurrenceType != null) ...[
                      SizedBox(height: 10),
                      Text('Select Recurrence Count:'),
                      DropdownButton<int>(
                        value: selectedRecurrenceCount,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            child: Text('None'),
                            value: null,
                          ),
                          for (int i = 1; i <= 10; i++)
                            DropdownMenuItem(
                              child: Text('$i times'),
                              value: i,
                            ),
                        ],
                        onChanged: (int? count) {
                          setDialogState(() {
                            selectedRecurrenceCount = count;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (eventNameController.text.isNotEmpty) {
                      setState(() {
                        meetings.add(
                          Meeting(
                            eventNameController.text,
                            DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedStartTime.hour,
                              selectedStartTime.minute,
                            ),
                            DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedEndTime.hour,
                              selectedEndTime.minute,
                            ),
                            selectedColor,
                            false,
                            recurrenceRule: _generateRecurrenceRule(
                              type: selectedRecurrenceType,
                              count: selectedRecurrenceCount,
                            ),
                          ),
                        );
                      });
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditMeetingDialog(BuildContext context, Meeting meeting) async {
    TextEditingController eventNameController = TextEditingController(text: meeting.eventName);
    DateTime selectedDate = meeting.from;
    TimeOfDay selectedStartTime = TimeOfDay(hour: meeting.from.hour, minute: meeting.from.minute);
    TimeOfDay selectedEndTime = TimeOfDay(hour: meeting.to.hour, minute: meeting.to.minute);
    Color editSelectedColor = meeting.background;
    String? selectedType;
    int? selectedCount;

    if (meeting.recurrenceRule != null) {
      List<String> ruleParts = meeting.recurrenceRule!.split(';');
      for (String part in ruleParts) {
        if (part.startsWith('FREQ=')) {
          selectedType = part;
        } else if (part.startsWith('COUNT=')) {
          selectedCount = int.tryParse(part.substring('COUNT='.length));
        }
      }
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Meeting'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: eventNameController,
                      decoration: InputDecoration(labelText: 'Event Name'),
                    ),
                    SizedBox(height: 10),
                    Text('Select Date:'),
                    ElevatedButton(
                      onPressed: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text('Select Time Range:'),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              TimeOfDay? pickedStartTime = await showTimePicker(
                                context: context,
                                initialTime: selectedStartTime,
                              );
                              if (pickedStartTime != null) {
                                setDialogState(() {
                                  selectedStartTime = pickedStartTime;
                                });
                              }
                            },
                            child: Text(
                              'Start: ${selectedStartTime.format(context)}',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              TimeOfDay? pickedEndTime = await showTimePicker(
                                context: context,
                                initialTime: selectedEndTime,
                              );
                              if (pickedEndTime != null) {
                                setDialogState(() {
                                  selectedEndTime = pickedEndTime;
                                });
                              }
                            },
                            child: Text(
                              'End: ${selectedEndTime.format(context)}',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text('Select Color:'),
                    ElevatedButton(
                      onPressed: () {
                        _openEditColorPicker(context, setDialogState, (color) {
                          editSelectedColor = color;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: editSelectedColor,
                      ),
                      child: Text('Choose Color'),
                    ),
                    SizedBox(height: 10),
                    Text('Select Recurrence Type:'),
                    DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          child: Text('None'),
                          value: null,
                        ),
                        DropdownMenuItem(
                          child: Text('Daily'),
                          value: 'FREQ=DAILY',
                        ),
                        DropdownMenuItem(
                          child: Text('Weekly'),
                          value: 'FREQ=WEEKLY',
                        ),
                        DropdownMenuItem(
                          child: Text('Monthly'),
                          value: 'FREQ=MONTHLY',
                        ),
                      ],
                      onChanged: (String? type) {
                        setDialogState(() {
                          selectedType = type;
                        });
                      },
                    ),
                    if (selectedType != null) ...[
                      SizedBox(height: 10),
                      Text('Select Recurrence Count:'),
                      DropdownButton<int>(
                        value: selectedCount,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            child: Text('None'),
                            value: null,
                          ),
                          for (int i = 1; i <= 10; i++)
                            DropdownMenuItem(
                              child: Text('$i times'),
                              value: i,
                            ),
                        ],
                        onChanged: (int? count) {
                          setDialogState(() {
                            selectedCount = count;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (eventNameController.text.isNotEmpty) {
                      setState(() {
                        int index = meetings.indexOf(meeting);
                        meetings[index] = Meeting(
                          eventNameController.text,
                          DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedStartTime.hour,
                            selectedStartTime.minute,
                          ),
                          DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedEndTime.hour,
                            selectedEndTime.minute,
                          ),
                          editSelectedColor,
                          false,
                          recurrenceRule: _generateRecurrenceRule(
                            type: selectedType,
                            count: selectedCount,
                          ),
                        );
                      });
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openColorPicker(BuildContext context, StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) {
                setDialogState(() {
                  selectedColor = color;
                });
                setState(() {
                  selectedColor = color;
                });
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Select'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openEditColorPicker(BuildContext context, StateSetter setDialogState, Function(Color) onColorChanged) {
    Color tempColor = selectedColor;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) {
                tempColor = color;
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Select'),
              onPressed: () {
                setDialogState(() {
                  onColorChanged(tempColor);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class Meeting {
  Meeting(
    this.eventName,
    this.from,
    this.to,
    this.background,
    this.isAllDay, {
    this.recurrenceRule,
  });

  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;
  String? recurrenceRule;

  @override
  String toString() => eventName;
}