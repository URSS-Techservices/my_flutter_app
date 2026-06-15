import 'package:halo/chat/chat_service.dart' as legacy;

/// App-level chat service facade to keep profile pages and future modules
/// decoupled from the legacy chat implementation file path.
class AppChatService {
  final legacy.ChatService _delegate = legacy.ChatService();

  Future<String> getOrCreateChatId(String user1, String user2) {
    return _delegate.getOrCreateChatId(user1, user2);
  }
}
