import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  String mid;
  String senderID;
  String senderEmail;
  String receiverID;
  String receiverEmail;
  String message;
  Timestamp timeSent;
  bool messageSeen;
  Timestamp? timeSeen;
  String? imageUrl;
  String? fileName;
  String? fileUrl;
  String messageType;
  bool isDelivered;
  bool isDeleted;
  Timestamp? deletedAt;
  String? deletedBy;

  Message({
    required this.mid,
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.receiverEmail,
    required this.message,
    required this.timeSent,
    required this.messageSeen,
    this.timeSeen,
    this.imageUrl,
    this.fileName,
    this.fileUrl,
    this.messageType = 'text',
    this.isDelivered = false,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  Map<String, dynamic> toJson() => {
    'mid': mid,
    'senderID': senderID,
    'senderEmail': senderEmail,
    'receiverID': receiverID,
    'receiverEmail': receiverEmail,
    'message': message,
    'timeSent': timeSent,
    'messageSeen': messageSeen,
    'timeSeen': timeSeen,
    'imageUrl': imageUrl,
    'fileName': fileName,
    'fileUrl': fileUrl,
    'messageType': messageType,
    'isDelivered': isDelivered,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt,
    'deletedBy': deletedBy,
  };

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      mid: json['mid'] ?? '',
      senderID: json['senderID'] ?? '',
      senderEmail: json['senderEmail'] ?? '',
      receiverID: json['receiverID'] ?? '',
      receiverEmail: json['receiverEmail'] ?? '',
      message: json['message'] ?? '',
      timeSent: json['timeSent'] ?? Timestamp.now(),
      messageSeen: json['messageSeen'] ?? false,
      timeSeen: json['timeSeen'],
      imageUrl: json['imageUrl'],
      fileName: json['fileName'],
      fileUrl: json['fileUrl'],
      messageType: json['messageType'] ?? 'text',
      isDelivered: json['isDelivered'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: json['deletedAt'],
      deletedBy: json['deletedBy'],
    );
  }

  // Helper methods
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get isTextMessage => messageType == 'text';
  bool get isImageMessage => messageType == 'image';
  bool get isFileMessage => messageType == 'file';

  String get displayTime {
    DateTime dateTime = timeSent.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      // Today - show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(dateTime).inDays < 7) {
      // This week - show day
      List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Older - show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
