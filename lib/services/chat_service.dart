// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class ChatService {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   String get currentUid {
//     final user = _auth.currentUser;
//     if (user == null) {
//       throw Exception('User not logged in');
//     }
//     return user.uid;
//   }

//   String supportChatId(String userId) {
//     return 'support_$userId';
//   }

//   String privateChatId(String uid1, String uid2) {
//     final ids = [uid1, uid2]..sort();
//     return '${ids[0]}_${ids[1]}';
//   }

//   Future<void> createOrOpenSupportChat({
//     required String userRole,
//   }) async {
//     final uid = currentUid;
//     final chatId = supportChatId(uid);

//     final chatRef = _db.collection('chats').doc(chatId);
//     final doc = await chatRef.get();

//     if (!doc.exists) {
//       await chatRef.set({
//         'type': 'support',
//         'userId': uid,
//         'participants': [uid],
//         'userRole': userRole,
//         'lastMessage': '',
//         'lastMessageAt': null,
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//     }
//   }

//   Future<void> sendSupportMessage({
//     required String text,
//     required String senderRole,
//   }) async {
//     final uid = currentUid;
//     final chatId = supportChatId(uid);

//     if (text.trim().isEmpty) return;

//     final chatRef = _db.collection('chats').doc(chatId);
//     final messageRef = chatRef.collection('messages').doc();

//     await _db.runTransaction((transaction) async {
//       final chatSnap = await transaction.get(chatRef);

//       if (!chatSnap.exists) {
//         transaction.set(chatRef, {
//           'type': 'support',
//           'userId': uid,
//           'participants': [uid],
//           'userRole': senderRole,
//           'createdAt': FieldValue.serverTimestamp(),
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
//       }

//       transaction.set(messageRef, {
//         'senderId': uid,
//         'senderRole': senderRole,
//         'text': text.trim(),
//         'isAdmin': false,
//         'isRead': false,
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       transaction.set(
//         chatRef,
//         {
//           'lastMessage': text.trim(),
//           'lastMessageAt': FieldValue.serverTimestamp(),
//           'updatedAt': FieldValue.serverTimestamp(),
//         },
//         SetOptions(merge: true),
//       );
//     });
//   }

//   Stream<QuerySnapshot<Map<String, dynamic>>> getSupportMessages() {
//     final uid = currentUid;
//     final chatId = supportChatId(uid);

//     return _db
//         .collection('chats')
//         .doc(chatId)
//         .collection('messages')
//         .orderBy('createdAt', descending: false)
//         .snapshots();
//   }

//   Stream<QuerySnapshot<Map<String, dynamic>>> getUserSupportChats() {
//     return _db
//         .collection('chats')
//         .where('type', isEqualTo: 'support')
//         .orderBy('updatedAt', descending: true)
//         .snapshots();
//   }

//   Future<void> sendPrivateMessage({
//     required String receiverId,
//     required String text,
//     required String senderRole,
//   }) async {
//     final senderId = currentUid;

//     if (text.trim().isEmpty) return;

//     final chatId = privateChatId(senderId, receiverId);
//     final chatRef = _db.collection('chats').doc(chatId);
//     final messageRef = chatRef.collection('messages').doc();

//     await _db.runTransaction((transaction) async {
//       final chatSnap = await transaction.get(chatRef);

//       if (!chatSnap.exists) {
//         transaction.set(chatRef, {
//           'type': 'donation',
//           'participants': [senderId, receiverId],
//           'createdAt': FieldValue.serverTimestamp(),
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
//       }

//       transaction.set(messageRef, {
//         'senderId': senderId,
//         'receiverId': receiverId,
//         'senderRole': senderRole,
//         'text': text.trim(),
//         'isRead': false,
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       transaction.set(
//         chatRef,
//         {
//           'lastMessage': text.trim(),
//           'lastMessageAt': FieldValue.serverTimestamp(),
//           'updatedAt': FieldValue.serverTimestamp(),
//         },
//         SetOptions(merge: true),
//       );
//     });
//   }

//   Stream<QuerySnapshot<Map<String, dynamic>>> getPrivateMessages({
//     required String otherUserId,
//   }) {
//     final uid = currentUid;
//     final chatId = privateChatId(uid, otherUserId);

//     return _db
//         .collection('chats')
//         .doc(chatId)
//         .collection('messages')
//         .orderBy('createdAt', descending: false)
//         .snapshots();
//   }

//   Stream<QuerySnapshot<Map<String, dynamic>>> getMyChats() {
//     final uid = currentUid;

//     return _db
//         .collection('chats')
//         .where('participants', arrayContains: uid)
//         .orderBy('updatedAt', descending: true)
//         .snapshots();
//   }
// }