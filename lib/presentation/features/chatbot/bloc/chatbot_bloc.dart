// lib/presentation/features/chatbot/bloc/chatbot_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/data/chatbot/models/chat_request_model.dart';
import 'package:planmate_app/data/chatbot/models/message_model.dart';
import 'package:planmate_app/domain/chatbot/usecases/send_chat_message.dart';
import 'chatbot_event.dart';
import 'chatbot_state.dart';

class ChatbotBloc extends Bloc<ChatbotEvent, ChatbotState> {
  final SendChatMessage sendChatMessage;

  ChatbotBloc({required this.sendChatMessage}) : super(ChatbotState()) {
    // SỬA TÊN
    on<SendChatMessageEvent>(_onSendChatMessage);
  }

  Future<void> _onSendChatMessage(
    SendChatMessageEvent event,
    Emitter<ChatbotState> emit,
  ) async {
    final userMessage = MessageModel(role: 'user', content: event.message);
    final currentHistory = List<MessageModel>.from(state.history);

    emit(
      state.copyWith(
        status: ChatbotStatus.loading,
        history: [...currentHistory, userMessage],
      ),
    );

    final request = ChatRequestModel(
      message: event.message,
      history: currentHistory,
    );

    // SỬA LOGIC GỌI API:
    final failureOrSuccess = await sendChatMessage(request); // GỌI USECASE

    failureOrSuccess.fold(
      (failure) {
        // Nếu thất bại
        emit(
          state.copyWith(
            status: ChatbotStatus.failure,
            error: failure.toString(), // (Bạn nên có hàm mapFailureToMessage)
          ),
        );
      },
      (assistantResponseContent) {
        // Nếu thành công
        final assistantMessage = MessageModel(
          role: 'assistant',
          content: assistantResponseContent,
        );
        emit(
          state.copyWith(
            status: ChatbotStatus.success,
            history: [...state.history, assistantMessage],
          ),
        );
      },
    );
  }
}
