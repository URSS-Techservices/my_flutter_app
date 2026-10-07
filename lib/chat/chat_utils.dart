// lib/chat/chat_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Deterministic chatId from two UIDs (same pair => same chatId)
String chatIdFromUids(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}_${list[1]}';
}

/// Ensure a chat document exists with the correct schema
Future<void> ensureChatExists(String chatId, List<String> users) async {
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
  final doc = await chatRef.get();

  if (!doc.exists) {
    await chatRef.set({
      'members': users,                       // ✅ match ChatService + ChatListPage
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageSenderId': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'chatType': 'direct',                  // direct or group
      'isActive': true,
      'wallpaper': '',
      'archived': false,
      'pinned': false,
      'muted': false,
      'typingUserId': null,                  // used by typing indicator
      // optional: keep old map-style typing if you ever use it
      'typing': {},                          // map<userId, lastTypingTimestamp>
    });
  }
}

/// Convenience: create chat for 1–1 if not exists, return chatId
Future<String> createChatIfNotExists(String uidA, String uidB) async {
  final chatId = chatIdFromUids(uidA, uidB);
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
  final doc = await chatRef.get();

  if (!doc.exists) {
    await chatRef.set({
      'members': [uidA, uidB],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageSenderId': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'chatType': 'direct',
      'isActive': true,
      'wallpaper': '',
      'archived': false,
      'pinned': false,
      'muted': false,
      'typingUserId': null,
      'typing': {},
    });
  }

  return chatId;
}
