// lib/domain/chatbot/usecases/send_chat_message.dart
import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/data/chatbot/models/chat_request_model.dart';
import 'package:planmate_app/domain/chatbot/repositories/chatbot_repository.dart';

class SendChatMessage {
  final ChatbotRepository repository;

  SendChatMessage(this.repository);

  Future<Either<Failure, String>> call(ChatRequestModel request) async {
    return await repository.sendChatMessage(request);
  }
}
