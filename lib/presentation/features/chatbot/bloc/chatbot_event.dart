// lib/presentation/features/chatbot/bloc/chatbot_event.dart

abstract class ChatbotEvent {}

class SendChatMessageEvent extends ChatbotEvent {
  final String message;
  SendChatMessageEvent(this.message);
}
