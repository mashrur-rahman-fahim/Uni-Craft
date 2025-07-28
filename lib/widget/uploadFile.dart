import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

import '../Homepage.dart';
import '../api/firebase_api.dart';
import 'button_widget.dart';

class uploadFile extends StatefulWidget {
  final dynamic code2;
  const uploadFile(this.code2, {Key? key}) : super(key: key);
  @override
  State<uploadFile> createState() => _uploadFileState();
}

class _uploadFileState extends State<uploadFile> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  var urlDownload;
  UploadTask? task;
  File? file;
  var upload_check = false, link_up = false;
  var caption = TextEditingController();
  var link = TextEditingController();
  var check_for_save = false;
  String string = "";
  var date = [];
  var to=[];

  @override
  Widget build(BuildContext context) {
    double screenW = MediaQuery.of(context).size.width;
    double screenH = MediaQuery.of(context).size.height;
    final fileName = file != null ? basename(file!.path) : 'No File Selected';

    return Scaffold(
        backgroundColor: Color(0xffb8d8d8),
        appBar: AppBar(
          title: Text("Upload File"),
          backgroundColor: Color(0xff7a9e9f),
        ),
        body: StreamBuilder(
            stream:
                FirebaseFirestore.instance.collection("Profile").snapshots(),
            builder: (context, snapshots) {
              if(snapshots.hasData)
                {
                  var res=snapshots.data!.docs.toList();
                  to.clear();
                  for(var r in res)
                    {
                      if(r['code']==widget.code2.toString() && r['role']!="Administrator")
                        {
                          to.add(r['token']);
                        }
                    }
                }
              return SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      height: 0,
                      width: 0,
                      child: StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection("Profile")
                              .snapshots(),
                          builder:
                              (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (snapshot.hasData && upload_check == true) {
                              final res = snapshot.data!.docs.toList();
                              for (var r in res!) {
                                if (r['uid'] ==
                                        FirebaseAuth
                                            .instance.currentUser!.uid &&
                                    r['role'] == "Administrator") {
                                  int c = 0;
                                  int b = c + 1;
                                  int d = b + 1;
                                  while (true) {
                                    try {
                                      if (r[c.toString()] == "") {
                                        break;
                                      } else {
                                        c = c + 3;
                                        b = c + 1;
                                        d = b + 1;
                                      }
                                    } catch (e) {
                                      break;
                                    }
                                  }

                                  FirebaseFirestore.instance
                                      .collection("Profile")
                                      .doc(FirebaseAuth
                                          .instance.currentUser!.uid)
                                      .update({
                                    c.toString(): urlDownload.toString(),
                                    b.toString(): fileName.toString(),
                                    d.toString(): string.toString(),
                                  });
                                  upload_check = false;
                                }
                              }
                              return Text("Upload Successfull");
                            }
                            if (snapshot.hasData && link_up == true) {
                              final res = snapshot.data!.docs.toList();
                              for (var r in res!) {
                                if (r['uid'] ==
                                        FirebaseAuth
                                            .instance.currentUser!.uid &&
                                    r['role'] == "Administrator") {
                                  int l = 0;
                                  int l1 = l + 1;
                                  int l2 = l1 + 1;
                                  while (true) {
                                    try {
                                      if (r['link' + l.toString()] == "") {
                                        break;
                                      } else {
                                        l = l + 3;
                                        l1 = l + 1;
                                        l2 = l1 + 1;
                                      }
                                    } catch (e) {
                                      break;
                                    }
                                  }

                                  FirebaseFirestore.instance
                                      .collection("Profile")
                                      .doc(FirebaseAuth
                                          .instance.currentUser!.uid)
                                      .update({
                                    'link' + l.toString():
                                        caption.text.toString(),
                                    'link' + l1.toString():
                                        link.text.toString(),
                                    'link' + l2.toString(): string,
                                  });
                                  link_up = false;
                                }
                              }
                              return Text("Upload Successfull");
                            } else
                              return Container();
                          }),
                    ),
                    SizedBox.fromSize(size: Size(0, (((50 / 872) * screenH)))),
                    Container(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 0.07 * screenH,
                              width: 0.9 * screenW,
                              decoration: BoxDecoration(
                                // color:  Color(0xffa84747),
                                color: Color(0xff33678a),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: GestureDetector(
                                onTap: selectFile,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.attach_file,
                                      color: Colors.greenAccent,
                                    ),
                                    Container(
                                      width: 0.01 * screenW,
                                    ),
                                    Text(
                                      "Select File",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              fileName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black),
                            ),
                            SizedBox(height: 48),
                            Container(
                              height: 0.07 * screenH,
                              width: 0.9 * screenW,
                              decoration: BoxDecoration(
                                // color:  Color(0xffa84747),
                                color: Color(0xff33678a),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: GestureDetector(
                                onTap: uploadFile,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.upload_file,
                                      color: Colors.greenAccent,
                                    ),
                                    Container(
                                      width: 0.01 * screenW,
                                    ),
                                    Text(
                                      "Upload File",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            task != null
                                ? buildUploadStatus(task!)
                                : Container(),
                            SizedBox.fromSize(
                                size: Size(0, (41 / 872) * screenH)),
                            Form(
                                key: formKey,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: (0 / 372) * screenW),
                                      child: TextFormField(
                                        style: TextStyle(
                                            color: Colors.black, fontSize: 17),
                                        controller: caption,
                                        decoration: InputDecoration(
                                          hintText: "Title",
                                          hintStyle: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 17),
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: Color(0xff4f6367),
                                              )),
                                          enabledBorder: UnderlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(1),
                                              borderSide: BorderSide(
                                                color: Color(0xff4f6367),
                                              )),
                                          // label: Text(
                                          //   "Name",
                                          //   style: TextStyle(color: Colors.white70),
                                          // ),
                                        ),
                                        validator: (value) {
                                          if (value!.isEmpty) {
                                            return "Enter a title ";
                                          } else
                                            return null;
                                        },
                                      ),
                                    ),
                                    SizedBox.fromSize(
                                        size: Size(0, (41 / 872) * screenH)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: (0 / 372) * screenW),
                                      child: TextFormField(
                                        style: TextStyle(
                                            color: Colors.black, fontSize: 17),
                                        controller: link,
                                        decoration: InputDecoration(
                                          hintText: "Link (https://)",
                                          hintStyle: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 17),
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: Color(0xff4f6367),
                                              )),
                                          enabledBorder: UnderlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(1),
                                              borderSide: BorderSide(
                                                color: Color(0xff4f6367),
                                              )),
                                          // label: Text(
                                          //   "Name",
                                          //   style: TextStyle(color: Colors.white70),
                                          // ),
                                        ),
                                        validator: (value) {
                                          if (value!.isEmpty ||
                                              !RegExp(r'[h]*[t]*[t]*[p]*[s]*[:]*[/]*[.]*(https://)')
                                                  .hasMatch(value!)) {
                                            return "Enter link ";
                                          } else
                                            return null;
                                        },
                                      ),
                                    ),
                                  ],
                                )),
                            Container(
                              height: 0.04 * screenH,
                            ),
                            Container(
                              height: 0.05 * screenH,
                              width: 0.3 * screenW,
                              decoration: BoxDecoration(
                                // color:  Color(0xffa84747),
                                color: Color(0xff33678a),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: GestureDetector(
                                  onTap: () async {

                                    if (formKey.currentState!.validate()) {

                                      try {
                                        final result =
                                            await InternetAddress.lookup(
                                                'google.com');
                                        if (result.isNotEmpty &&
                                            result[0].rawAddress.isNotEmpty) {
                                          check_for_save = true;
                                        }
                                      } on SocketException catch (_) {
                                        check_for_save = false;
                                      }
                                      if (check_for_save == true) {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return Center(
                                                child: CircularProgressIndicator());
                                          },
                                        );

                                        await Future.delayed(Duration(milliseconds: 500));
                                        Navigator.of(context).pop();
                                        Navigator.of(context).pop();

                                        DateFormat dateFormat =
                                            DateFormat("yyyy-MM-dd HH:mm:ss");
                                        string =
                                            dateFormat.format(DateTime.now());
                                        setState(() {
                                          link_up = true;
                                        });
                                      }
                                    }
                                  },
                                  child: Center(
                                      child: const Text(
                                    "Upload Link",
                                    style: TextStyle(color: Colors.white),
                                  ))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }));
  }

  Future selectFile() async {
    final permissionStatus = await Permission.storage.status;
    if (permissionStatus.isDenied) {
      // Here just ask for the permission for the first time
      await Permission.storage.request();

      // I noticed that sometimes popup won't show after user press deny
      // so I do the check once again but now go straight to appSettings
      if (permissionStatus.isDenied) {
        await openAppSettings();
      }
    } else if (permissionStatus.isPermanentlyDenied) {
      // Here open app settings for user to manually enable permission in case
      // where permission was permanently denied
      await openAppSettings();
    } else {
      // Do stuff that require permission here
    }
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);

    if (result == null) return;
    final path = result.files.single.path!;

    setState(() => file = File(path));
    upload_check = false;
  }

  Future uploadFile() async {

    DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    string = dateFormat.format(DateTime.now());

    if (file == null) return;

    final fileName = basename(file!.path);
    final destination = 'files/$fileName';

    task = FirebaseApi.uploadFile(destination, file!);
    setState(() {});

    if (task == null) return;

    final snapshot = await task!.whenComplete(() {});
    urlDownload = await snapshot.ref.getDownloadURL();
    setState(() {
      upload_check = true;
    });

    // print('Download-Link: $urlDownload');
  }

  Widget buildUploadStatus(UploadTask task) => StreamBuilder<TaskSnapshot>(
        stream: task.snapshotEvents,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final snap = snapshot.data!;
            final progress = snap.bytesTransferred / snap.totalBytes;
            final percentage = (progress * 100).toStringAsFixed(2);

            return Text(
              '$percentage %',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            );
          } else {
            return Container();
          }
        },
      );
}
