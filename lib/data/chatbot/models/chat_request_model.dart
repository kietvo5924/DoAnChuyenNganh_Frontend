// lib/data/chatbot/models/chat_request_model.dart

import 'message_model.dart';

class ChatRequestModel {
  final String message;
  final List<MessageModel> history;

  ChatRequestModel({required this.message, required this.history});

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'history': history.map((e) => e.toJson()).toList(),
    };
  }
}
