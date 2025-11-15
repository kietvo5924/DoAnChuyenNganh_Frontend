// lib/domain/chatbot/repositories/chatbot_repository.dart
import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/data/chatbot/models/chat_request_model.dart';

abstract class ChatbotRepository {
  Future<Either<Failure, String>> sendChatMessage(ChatRequestModel request);
}
