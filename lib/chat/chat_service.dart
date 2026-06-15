import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Get or create chatId between two users
  Future<String> getOrCreateChatId(String user1, String user2) async {
    try {
      // Check if a chat already exists between the two users
      final chatQuery = await _firestore
          .collection('chats')
          .where('members', arrayContains: user1)
          .get();

      for (var doc in chatQuery.docs) {
        final members = List<String>.from(doc['members']);
        if (members.contains(user2)) {
          return doc.id; // Chat already exists
        }
      }

      // Create new chat if none exists
      final newChat = await _firestore.collection('chats').add({
        'members': [user1, user2],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageSenderId': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'chatType': 'direct', // direct or group
        'isActive': true,
        'wallpaper': '', // Custom chat wallpaper
        'archived': false,
        'pinned': false,
        'muted': false,
        'typingUserId': null, // used by UI for typing indicator
      });

      return newChat.id;
    } catch (e) {
      print('❌ Error creating/getting chat: $e');
      rethrow;
    }
  }

  /// 🆕 Create group chat (WhatsApp style)
  Future<String> createGroupChat(
      List<String> members,
      String groupName,
      String createdBy, {
        String groupDescription = '',
        String groupImage = '',
      }) async {
    try {
      final newGroup = await _firestore.collection('chats').add({
        'members': members,
        'admins': [createdBy], // Group admins
        'groupName': groupName,
        'groupDescription': groupDescription,
        'groupImage': groupImage,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Group created',
        'lastMessageSenderId': 'system',
        'updatedAt': FieldValue.serverTimestamp(),
        'chatType': 'group',
        'isActive': true,
        'wallpaper': '',
        'archived': false,
        'pinned': false,
        'muted': false,
        'settings': {
          'whoCanMessage': 'all', // all, admins
          'whoCanEditInfo': 'admins',
          'disappearingMessages': false,
          'disappearingTime': 0, // in hours
        },
        'typingUserId': null,
      });

      // Send system message
      await sendSystemMessage(
        newGroup.id,
        'You created group "$groupName"',
        createdBy,
      );

      return newGroup.id;
    } catch (e) {
      print('❌ Error creating group chat: $e');
      rethrow;
    }
  }

  /// ✅ Enhanced send message with media support
  Future<void> sendMessage(
      String chatId,
      String senderId,
      String receiverId,
      String text, {
        String messageType =
        'text', // text, image, video, audio, document, location, sticker, gif, system
        Map<String, dynamic>? metadata,
        String? replyToMessageId, // For message replies
      }) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final serverTime = FieldValue.serverTimestamp();

      await messageRef.set({
        'id': messageRef.id,
        'text': text,
        'senderId': senderId,
        'receiverId': receiverId,
        // 🔹 For compatibility with UI: both fields
        'timestamp': serverTime,
        'createdAt': serverTime,
        'seen': false,
        'delivered': false,
        'type': messageType,
        'metadata': metadata ?? {},
        'reactions': {}, // Message reactions
        'replyTo': replyToMessageId, // Reply functionality
        'forwarded': false,
        'starred': false,
        'deleted': false,
        'edited': false,
        'editedAt': null,
      });

      // 🔹 Update lastMessage in chat doc
      String displayText = _getDisplayTextForType(messageType, text);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': displayText,
        'lastMessageSenderId': senderId,
        'updatedAt': serverTime,
      });

      // 🔹 Update delivery status (single tick -> delivered)
      _updateMessageStatus(chatId, messageRef.id, 'delivered');

      // 🔹 Create a notification for the receiver (best-effort)
      try {
        await _firestore
            .collection('users')
            .doc(receiverId)
            .collection('notifications')
            .add({
          'type': 'message',
          'fromUserId': senderId,
          'chatId': chatId,
          'messagePreview': displayText,
          'createdAt': serverTime,
          'read': false,
        });
      } catch (e) {
        // Best-effort: don't fail the message if notification write fails
        // print('Notification write failed: $e');
      }
    } catch (e) {
      print('❌ Error sending message: $e');
    }
  }

  /// 🆕 Send image message
  Future<void> sendImageMessage(
      String chatId,
      String senderId,
      String receiverId,
      String imageUrl,
      String caption,
      ) async {
    await sendMessage(
      chatId,
      senderId,
      receiverId,
      caption,
      messageType: 'image',
      metadata: {
        'imageUrl': imageUrl,
        'caption': caption,
        'fileName': '',
        'fileSize': 0,
      },
    );
  }

  /// 🆕 Send video message
  Future<void> sendVideoMessage(
      String chatId,
      String senderId,
      String receiverId,
      String videoUrl,
      String thumbnailUrl,
      String caption,
      int duration,
      ) async {
    await sendMessage(
      chatId,
      senderId,
      receiverId,
      caption,
      messageType: 'video',
      metadata: {
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'duration': duration,
        'fileName': '',
        'fileSize': 0,
      },
    );
  }

  /// 🆕 Send voice message
  Future<void> sendVoiceMessage(
      String chatId,
      String senderId,
      String receiverId,
      String audioUrl,
      int duration,
      ) async {
    await sendMessage(
      chatId,
      senderId,
      receiverId,
      '',
      messageType: 'audio',
      metadata: {
        'audioUrl': audioUrl,
        'duration': duration,
        'waveform': [], // Audio waveform data
      },
    );
  }

  /// 🆕 Send location
  Future<void> sendLocation(
      String chatId,
      String senderId,
      String receiverId,
      double latitude,
      double longitude,
      String address,
      ) async {
    await sendMessage(
      chatId,
      senderId,
      receiverId,
      'Location: $address',
      messageType: 'location',
      metadata: {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      },
    );
  }

  /// 🆕 Send document
  Future<void> sendDocument(
      String chatId,
      String senderId,
      String receiverId,
      String documentUrl,
      String fileName,
      int fileSize,
      ) async {
    await sendMessage(
      chatId,
      senderId,
      receiverId,
      fileName,
      messageType: 'document',
      metadata: {
        'documentUrl': documentUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'fileType': fileName.split('.').last,
      },
    );
  }

  /// 🆕 Forward message
  Future<void> forwardMessage(
      String originalChatId,
      String originalMessageId,
      String targetChatId,
      String senderId,
      String receiverId,
      ) async {
    try {
      final originalMessage = await _firestore
          .collection('chats')
          .doc(originalChatId)
          .collection('messages')
          .doc(originalMessageId)
          .get();

      if (originalMessage.exists) {
        final data = originalMessage.data()!;
        await sendMessage(
          targetChatId,
          senderId,
          receiverId,
          data['text'] ?? '',
          messageType: data['type'] ?? 'text',
          metadata: {
            ...Map<String, dynamic>.from(data['metadata'] ?? {}),
            'forwarded': true,
            'originalSender': data['senderId'],
          },
        );
      }
    } catch (e) {
      print('❌ Error forwarding message: $e');
    }
  }

  /// 🆕 Reply to message
  Future<void> replyToMessage(
      String chatId,
      String senderId,
      String receiverId,
      String replyText,
      String originalMessageId,
      ) async {
    await sendMessage(
      chatId,
      senderId,
      receiverId,
      replyText,
      replyToMessageId: originalMessageId,
    );
  }

  /// 🆕 Edit message
  Future<void> editMessage(
      String chatId,
      String messageId,
      String newText,
      ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': newText,
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error editing message: $e');
    }
  }

  /// 🆕 Delete message
  Future<void> deleteMessage(
      String chatId,
      String messageId, {
        bool deleteForEveryone = false,
      }) async {
    try {
      if (deleteForEveryone) {
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
          'deleted': true,
          'text': 'This message was deleted',
          'metadata': {},
        });
      } else {
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .delete();
      }
    } catch (e) {
      print('❌ Error deleting message: $e');
    }
  }

  /// 🆕 Star/unstar message
  Future<void> toggleStarMessage(
      String chatId,
      String messageId,
      bool starred,
      ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'starred': starred});
    } catch (e) {
      print('❌ Error starring message: $e');
    }
  }

  /// 🆕 Add reaction to message
  Future<void> addReaction(
      String chatId,
      String messageId,
      String userId,
      String reaction, // 😀😂❤️😮😢😡👍👎
      ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'reactions.$userId': reaction,
      });
    } catch (e) {
      print('❌ Error adding reaction: $e');
    }
  }

  /// 🆕 Remove reaction
  Future<void> removeReaction(
      String chatId,
      String messageId,
      String userId,
      ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'reactions.$userId': FieldValue.delete(),
      });
    } catch (e) {
      print('❌ Error removing reaction: $e');
    }
  }

  /// 🆕 Update typing status (map-based, if you need it later)
  Future<void> updateTypingStatus(
      String chatId,
      String userId,
      bool isTyping,
      ) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'typing.$userId':
        isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } catch (e) {
      print('❌ Error updating typing status: $e');
    }
  }

  /// 🆕 Get typing users (map-based)
  Stream<Map<String, dynamic>> getTypingUsers(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.data()?['typing'] ?? {});
  }

  /// 🆕 System message for group activities
  Future<void> sendSystemMessage(
      String chatId,
      String text,
      String userId,
      ) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final serverTime = FieldValue.serverTimestamp();

      await messageRef.set({
        'id': messageRef.id,
        'text': text,
        'senderId': 'system',
        'receiverId': '',
        'timestamp': serverTime,
        'createdAt': serverTime,
        'seen': true,
        'delivered': true,
        'type': 'system',
        'metadata': {'userId': userId},
        'reactions': {},
      });
    } catch (e) {
      print('❌ Error sending system message: $e');
    }
  }

  /// 🆕 Update message status (delivered, seen)
  Future<void> _updateMessageStatus(
      String chatId,
      String messageId,
      String status,
      ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({status: true});
    } catch (e) {
      print('❌ Error updating message status: $e');
    }
  }

  /// 🆕 Update online status (if you want to use isOnline flag)
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating online status: $e');
    }
  }

  /// 🆕 Mute/unmute chat
  Future<void> muteChat(String chatId, String userId, bool muted) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('chatSettings')
          .doc(chatId)
          .set({'muted': muted}, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error muting chat: $e');
    }
  }

  /// 🆕 Archive/unarchive chat
  Future<void> archiveChat(String chatId, bool archived) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'archived': archived,
      });
    } catch (e) {
      print('❌ Error archiving chat: $e');
    }
  }

  /// 🆕 Pin/unpin chat
  Future<void> pinChat(String chatId, bool pinned) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'pinned': pinned,
      });
    } catch (e) {
      print('❌ Error pinning chat: $e');
    }
  }

  /// ✅ Get latest messages in a chat (paged realtime window)
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
    String chatId, {
    int limit = 40,
  }) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// ✅ Fetch older messages page (non-realtime)
  Future<QuerySnapshot<Map<String, dynamic>>> getMessagesPage(
    String chatId, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 40,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// ✅ Get all chats for a user (with filters)
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserChats(
      String userId, {
        bool includeArchived = false,
      }) {
    var query = _firestore
        .collection('chats')
        .where('members', arrayContains: userId);

    if (!includeArchived) {
      query = query.where('archived', isEqualTo: false);
    }

    // Note: Avoid orderBy here to prevent requiring a composite index.
    // We'll sort client-side in the UI.
    return query.snapshots();
  }

  /// 🆕 Get starred messages
  Stream<QuerySnapshot<Map<String, dynamic>>> getStarredMessages(
      String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('starred', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// ✅ Mark messages as seen (double-tick blue in UI)
  Future<void> markMessagesAsSeen(String chatId, String userId) async {
    try {
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('seen', isEqualTo: false)
          .limit(100)
          .get();

      if (unreadMessages.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      int ops = 0;

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'seen': true});
        ops++;
        if (ops == 450) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }

      if (ops > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('❌ Error marking messages as seen: $e');
    }
  }

  /// 🆕 Search messages in chat
  Future<List<Map<String, dynamic>>> searchMessages(
      String chatId,
      String query,
      ) async {
    try {
      final results = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('type', isEqualTo: 'text')
          .orderBy('timestamp', descending: true)
          .get();

      return results.docs
          .where((doc) => doc['text']
          .toString()
          .toLowerCase()
          .contains(query.toLowerCase()))
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error searching messages: $e');
      return [];
    }
  }

  /// Helper method to get display text for different message types
  String _getDisplayTextForType(String messageType, String originalText) {
    switch (messageType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎵 Voice message';
      case 'document':
        return '📄 Document';
      case 'location':
        return '📍 Location';
      case 'sticker':
        return '🙂 Sticker';
      case 'gif':
        return '🎬 GIF';
      case 'system':
        return originalText;
      default:
        return originalText;
    }
  }
}
