import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uni_craft/Stopwatch.dart';
import 'package:uni_craft/timeplanner.dart';

class Calendar extends StatefulWidget {
  var uid_ad;
   Calendar(this.uid_ad,{Key? key}) : super(key: key);


  @override
  _CalendarState createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  DateTime today = DateTime.now();
  Map<DateTime, List<String>> events = {};
 Map<String, dynamic>e = {};
 List b=[];

  void _onDaySelected(var day, DateTime focusDay) {
    setState(() {
      today = day;
    });
  }

  void _onEventAdded(String event) {




    setState(()  {

      events.update(
        today,
            (existingEvents) => [...existingEvents, event],
        ifAbsent: () => [event],
      );
      e.update(
        today.toString(),
            (existingEvents) => [...existingEvents, event],
        ifAbsent: () => [event],
      );

      FirebaseFirestore.instance.collection("Profile").doc(widget.uid_ad).update({
        "events":e,
      });

    });



  }

  void _deleteEvent(String event) {
    setState(() {
      if (events.containsKey(today)) {
        events[today]!.remove(event);
        e[today.toString()]!.remove(event);
        if (events[today]!.isEmpty) {
          events.remove(today);
          e.remove(today.toString());
        }
      }
      FirebaseFirestore.instance.collection("Profile").doc(widget.uid_ad).update({
        "events":e,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Academic Calendar"),
        backgroundColor: Color(0xff7a9e9f),//Colors.black.withOpacity(0.35),
        actions: [

          // IconButton(
          //   icon: Icon(Icons.calendar_view_week),
          //   onPressed: () {
          //     // Navigate to the TimePlanner page
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) =>
          //             TimePlannerPage(), // Replace with your TimePlanner page widget
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
      body:
      Stack(
        children: [
          StreamBuilder(stream: FirebaseFirestore.instance.collection("Profile").snapshots(), builder: (context,snapshots){
            if(snapshots.hasData)
            {
              var res=snapshots.data!.docs.toList();
              for(var r in res)
              {
                if(r['uid']==widget.uid_ad)
                {


                    e=r['events'];
                    print("tes");
                  ;

                }
              }

            }
            return Center();
          }),


          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/calendar_bg04.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(
                      0.75), // Adjust the opacity here (0.0 to 1.0)
                  BlendMode.dstATop,
                ),
              ),
            ),
          ),


          SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                        "Selected Day = ${today.toString().split(" ")[0]}"),
                  ),
                  TableCalendar(
                    locale: "en_US",
                    rowHeight: 43,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    availableGestures: AvailableGestures.all,
                    selectedDayPredicate: (day) => isSameDay(day, today ),
                    focusedDay: today ,
                    firstDay: DateTime.utc(2012, 01, 01),
                    lastDay: DateTime.utc(2050, 01, 01),
                    onDaySelected: _onDaySelected,
                  ),
                  const SizedBox(height: 20),
                  TodoListView(
                    uid: widget.uid_ad,
                    selectedDate: today ,
                    events: events[today] ?? [],
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
   List events=[];
  final Function(String) onEventAdded;
  final Function(String) onDeleteEvent;
  var uid;

   TodoListView({
    required this.selectedDate,
    required this.events,
    required this.onEventAdded,
    required this.onDeleteEvent,
    required this.uid,
    Key? key,
  }) : super(key: key);

  @override
  _TodoListViewState createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "Events for ${widget.selectedDate.toString().split(" ")[0]}",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder(stream: FirebaseFirestore.instance.collection("Profile").snapshots(), builder: (context,snapshots){
          if(snapshots.hasData)
            {
              var res=snapshots.data!.docs.toList();
              for(var r in res)
                {
                  if(r['uid']==widget.uid)
                    {
                      try{
                      widget.events=r['events'][widget.selectedDate.toString()];}catch(e){};
                    }
                }

            }
          return ListView.builder(
            shrinkWrap: true,
            itemCount: widget.events.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(widget.events[index]),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  onPressed: () {
                    widget.onDeleteEvent(widget.events[index]);
                  },
                ),
              );
            },
          );
        }),


        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    hintText: "Add your new Event.........",
                    hintStyle: TextStyle(
                        color: Colors.blueGrey), // Color of the hint text
                    // Optionally, you can set the border color and focused border color
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  style: TextStyle(
                      color: Colors.black), // Color of the entered text
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: Colors.black.withOpacity(0.9),
                ),
                onPressed: () {

                  final newEvent = textController.text;
                  print(widget.events);
                  setState(() {

                  });
                  if (newEvent.isNotEmpty) {

                    widget.onEventAdded(newEvent);
                    textController.clear();




                  }


                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}