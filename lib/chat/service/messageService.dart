import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../model/message.dart';

class MessageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Build unique chat room ID
  String buildChatRoomID(String senderID, String receiverID) {
    List<String> id = [senderID, receiverID];
    id.sort();
    String chatRoomID = id.join("_");
    return chatRoomID;
  }

  // Send Message with enhanced error handling
  Future<bool> sendMessage(String receiverID, String receiverEmail, String message, {String? imageUrl, String? fileName, String? fileUrl}) async {
    try {
      // Validate inputs
      if (receiverID.isEmpty || message.trim().isEmpty) {
        throw Exception('Invalid message data');
      }

      // Current User Info
      String senderID = _auth.currentUser!.uid;
      String senderEmail = _auth.currentUser!.email ?? '';
      Timestamp timestamp = Timestamp.now();

      // Get sender's name for notification
      String senderName = await _getUserDisplayName(senderID);

      // Create chat room with id as - senderID_receiverID
      String chatRoomID = buildChatRoomID(senderID, receiverID);

      // Create message document inside chat_room
      final docMessage = _firestore
          .collection("chat_room")
          .doc(chatRoomID)
          .collection("messages")
          .doc();

      // Create new message with enhanced fields
      Message newMessage = Message(
        mid: docMessage.id,
        senderID: senderID,
        senderEmail: senderEmail,
        receiverID: receiverID,
        receiverEmail: receiverEmail,
        message: message,
        timeSent: timestamp,
        messageSeen: false,
        timeSeen: null,
        imageUrl: imageUrl,
        fileName: fileName,
        fileUrl: fileUrl,
        messageType: _getMessageType(message, imageUrl, fileUrl),
        isDelivered: false,
      );

      // Store the message in Cloud Firestore with retry mechanism
      await _retryOperation(() => docMessage.set(newMessage.toJson()));

      // Update last message in chat room
      await _updateLastMessage(chatRoomID, message, timestamp);

      return true;
    } catch (e) {
      print("Error sending message: $e");
      return false;
    }
  }

  // Upload image and send message
  Future<bool> sendImageMessage(String receiverID, String receiverEmail, File imageFile, {String? caption}) async {
    try {
      String imageUrl = await _uploadImage(imageFile);
      return await sendMessage(
        receiverID,
        receiverEmail,
        caption ?? 'Image',
        imageUrl: imageUrl
      );
    } catch (e) {
      print("Error sending image: $e");
      return false;
    }
  }

  // Upload file and send message
  Future<bool> sendFileMessage(String receiverID, String receiverEmail, File file, String fileName) async {
    try {
      String fileUrl = await _uploadFile(file, fileName);
      return await sendMessage(
        receiverID,
        receiverEmail,
        fileName,
        fileName: fileName,
        fileUrl: fileUrl
      );
    } catch (e) {
      print("Error sending file: $e");
      return false;
    }
  }

  // Upload image to Firebase Storage
  Future<String> _uploadImage(File imageFile) async {
    try {
      String fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload file to Firebase Storage
  Future<String> _uploadFile(File file, String fileName) async {
    try {
      String filePath = 'chat_files/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Get message type
  String _getMessageType(String message, String? imageUrl, String? fileUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) return 'image';
    if (fileUrl != null && fileUrl.isNotEmpty) return 'file';
    return 'text';
  }

  // Update last message in chat room
  Future<void> _updateLastMessage(String chatRoomID, String message, Timestamp timestamp) async {
    try {
      await _firestore.collection("chat_room").doc(chatRoomID).set({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'lastMessageSender': _auth.currentUser!.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating last message: $e");
    }
  }

  // Get user display name for notifications
  Future<String> _getUserDisplayName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['displayName'] ?? userData['name'] ?? userData['email'] ?? 'Unknown User';
      }
      return 'Unknown User';
    } catch (e) {
      print('Error getting user display name: $e');
      return 'Unknown User';
    }
  }

  // Retry operation with exponential backoff
  Future<T> _retryOperation<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception('Max retry attempts reached');
  }

  // Map snapshot into a list of message objects with enhanced error handling
  List<Message> messageListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      try {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Message(
          mid: doc.id,
          senderID: data['senderID'] ?? '',
          senderEmail: data['senderEmail'] ?? '',
          receiverID: data['receiverID'] ?? '',
          receiverEmail: data['receiverEmail'] ?? '',
          message: data['message'] ?? '',
          timeSent: data['timeSent'] ?? Timestamp.now(),
          messageSeen: data['messageSeen'] ?? false,
          timeSeen: data['timeSeen'],
          imageUrl: data['imageUrl'],
          fileName: data['fileName'],
          fileUrl: data['fileUrl'],
          messageType: data['messageType'] ?? 'text',
          isDelivered: data['isDelivered'] ?? false,
        );
      } catch (e) {
        print("Error parsing message: $e");
        // Return a placeholder message to prevent crashes
        return Message(
          mid: doc.id,
          senderID: '',
          senderEmail: '',
          receiverID: '',
          receiverEmail: '',
          message: 'Error loading message',
          timeSent: Timestamp.now(),
          messageSeen: false,
          timeSeen: null,
        );
      }
    }).toList();
  }

  // Get messages between two users with offline support
  Stream<List<Message>> getMessages(String userID, String otherUserID) {
    String chatRoomID = buildChatRoomID(userID, otherUserID);

    return _firestore
        .collection("chat_room")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timeSent", descending: false)
        .snapshots(includeMetadataChanges: true)
        .map(messageListFromSnapshot);
  }

  // Get unseen messages with better filtering
  Stream<List<Message>> getUnseenMessages(String userID, String otherUserID) {
    String chatRoomID = buildChatRoomID(userID, otherUserID);

    return _firestore
        .collection("chat_room")
        .doc(chatRoomID)
        .collection("messages")
        .where("receiverID", isEqualTo: userID)
        .where("messageSeen", isEqualTo: false)
        .snapshots()
        .map(messageListFromSnapshot);
  }

  // Mark message as seen with enhanced error handling
  Future<bool> markMessageAsSeen(String messageID, String senderID, String receiverID) async {
    try {
      String chatRoomID = buildChatRoomID(senderID, receiverID);

      await _retryOperation(() => _firestore
          .collection("chat_room")
          .doc(chatRoomID)
          .collection("messages")
          .doc(messageID)
          .update({
        'messageSeen': true,
        'timeSeen': Timestamp.now(),
      }));

      return true;
    } catch (e) {
      print("Error marking message as seen: $e");
      return false;
    }
  }

  // Mark all messages as seen in a chat with batch operation
  Future<bool> markAllMessagesAsSeen(String userID, String otherUserID) async {
    try {
      String chatRoomID = buildChatRoomID(userID, otherUserID);

      QuerySnapshot unseenMessages = await _firestore
          .collection("chat_room")
          .doc(chatRoomID)
          .collection("messages")
          .where("receiverID", isEqualTo: userID)
          .where("messageSeen", isEqualTo: false)
          .get();

      if (unseenMessages.docs.isEmpty) return true;

      // Batch update all unseen messages
      WriteBatch batch = _firestore.batch();
      for (QueryDocumentSnapshot doc in unseenMessages.docs) {
        batch.update(doc.reference, {
          'messageSeen': true,
          'timeSeen': Timestamp.now(),
        });
      }
      await batch.commit();
      return true;
    } catch (e) {
      print("Error marking all messages as seen: $e");
      return false;
    }
  }

  // Delete message with soft delete option
  Future<bool> deleteMessage(String messageID, String senderID, String receiverID, {bool hardDelete = false}) async {
    try {
      String chatRoomID = buildChatRoomID(senderID, receiverID);
      DocumentReference messageRef = _firestore
          .collection("chat_room")
          .doc(chatRoomID)
          .collection("messages")
          .doc(messageID);

      if (hardDelete) {
        await messageRef.delete();
      } else {
        await messageRef.update({
          'isDeleted': true,
          'deletedAt': Timestamp.now(),
          'deletedBy': _auth.currentUser!.uid,
        });
      }
      return true;
    } catch (e) {
      print("Error deleting message: $e");
      return false;
    }
  }

  // Get chat room info
  Stream<DocumentSnapshot> getChatRoomInfo(String userID, String otherUserID) {
    String chatRoomID = buildChatRoomID(userID, otherUserID);
    return _firestore.collection("chat_room").doc(chatRoomID).snapshots();
  }

  // Update message delivery status
  Future<void> updateDeliveryStatus(String messageID, String senderID, String receiverID) async {
    try {
      String chatRoomID = buildChatRoomID(senderID, receiverID);
      await _firestore
          .collection("chat_room")
          .doc(chatRoomID)
          .collection("messages")
          .doc(messageID)
          .update({'isDelivered': true});
    } catch (e) {
      print("Error updating delivery status: $e");
    }
  }

  // Search messages in chat
  Future<List<Message>> searchMessages(String userID, String otherUserID, String query) async {
    try {
      String chatRoomID = buildChatRoomID(userID, otherUserID);
      QuerySnapshot snapshot = await _firestore
          .collection("chat_room")
          .doc(chatRoomID)
          .collection("messages")
          .where("message", isGreaterThanOrEqualTo: query)
          .where("message", isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      return messageListFromSnapshot(snapshot);
    } catch (e) {
      print("Error searching messages: $e");
      return [];
    }
  }
}
