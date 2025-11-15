// lib/presentation/features/chatbot/bloc/chatbot_state.dart

import 'package:planmate_app/data/chatbot/models/message_model.dart';

enum ChatbotStatus { initial, loading, success, failure }

class ChatbotState {
  final List<MessageModel> history; // <-- "TRÍ NHỚ" NẰM Ở ĐÂY
  final ChatbotStatus status;
  final String? error;

  ChatbotState({
    this.history = const [],
    this.status = ChatbotStatus.initial,
    this.error,
  });

  ChatbotState copyWith({
    List<MessageModel>? history,
    ChatbotStatus? status,
    String? error,
  }) {
    return ChatbotState(
      history: history ?? this.history,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
