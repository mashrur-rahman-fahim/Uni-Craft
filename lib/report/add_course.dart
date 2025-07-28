import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uni_craft/report/marks_section.dart';
import 'package:uni_craft/report/report_graph.dart';

class add_course extends StatefulWidget{
  @override
  State<add_course> createState() => _add_courseState();
}

class _add_courseState extends State<add_course> {

  var course_n=TextEditingController();
  //var twoDList = List<List>.generate(1, (i) => List<dynamic>.generate(3, (index) => null, growable: false), growable: false);

  List course_name=<Map>[];

  var join_code;

  @override
  Widget build(BuildContext context) {
    double screenW = MediaQuery.of(context).size.width;
    double screenH = MediaQuery.of(context).size.height;
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xffb8d8d8),
        title: Text(" Report",
          style: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 30,
          ),),
      ),
      body:
      SingleChildScrollView(
        child: Column(
          children: [
            StreamBuilder(stream: FirebaseFirestore.instance.collection("Profile").snapshots(), builder: (context,snapshots){
              if(snapshots.hasData)
                {
                  var res=snapshots.data?.docs.toList();
        
                  for(var r in res!)
                    {
                      if(r['uid']==FirebaseAuth.instance.currentUser!.uid)
                        {
                          try{
                            course_name=r['course'];
                          }catch(e){
        
                          }
                        }
                    }
                }
              return Column(
                children: [
                  GestureDetector(
                    onTap: (){
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                        content: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 200.0, // Set the maximum height as per your requirement
                          ),),
                        backgroundColor: Color(0xffABCDD0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          //ABCDD0 //B7D9DC
                          actions: <Widget>[
                            TextField(
                              controller:course_n ,
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Color(0xffA0DCE2)),
                                onPressed: (){
                              var map={};
                              map['Name']=course_n.text.toString();
                              map['quiz']=0;
                              map['mid']=0;
                              map['final']=0;
                              course_name.add(map);
                              FirebaseFirestore.instance.collection("Profile").doc(FirebaseAuth.instance.currentUser!.uid).update({
                                'course':course_name,
                              });
                              setState(() {
                                Navigator.pop(context);
                              });


                            }, child: Text("Add"))

                          ],
                        ),
                      );
                    },
                    child: Container(
                      height: 0.08*screenH,
                      color: Color(0xff5a9e9f),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add),
                          Text("Add courses"),
                        ],
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                      itemCount:course_name.length,
                      itemBuilder: (context,index){
                        return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff4E9CA3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0), // Adjust the radius as needed
                              ),
                              fixedSize: Size.fromHeight(42.0),
                            ),
                            onPressed: (){
                          int idx=index;
                          List temp=[];
                          temp.add(course_name);
                          temp.add(idx);
                          Navigator.push(context, MaterialPageRoute(builder: (context)=>marks_sec(temp)));
        
                        }, child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                           Text(course_name[index]['Name'],
                             style: TextStyle(
                                 color:Colors.white,
                                 fontSize: 20,
                                 fontWeight: FontWeight.bold,
                             ),),

                            GestureDetector(
                                onTap: (){
                                  course_name.removeAt(index);
                                  FirebaseFirestore.instance.collection("Profile").doc(FirebaseAuth.instance.currentUser!.uid).update({
                                    'course':course_name,

                                  });
                                  setState(() {

                                  });
                                },
                                child: Icon(Icons.delete,size: 20,color: Color(0xffBB4848),)),
                          ],
                        ));
                      }),

                ],
              );
            })
        
        
          ],

        
        ),
      ),
      backgroundColor: Color(0xffb8d8d8), //0xffc9d9e9


    );
  }
}