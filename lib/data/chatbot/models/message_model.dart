// lib/data/chatbot/models/message_model.dart

class MessageModel {
  final String role;
  final String content;

  MessageModel({required this.role, required this.content});

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }
}
