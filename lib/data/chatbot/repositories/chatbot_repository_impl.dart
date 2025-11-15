// lib/data/chatbot/repositories/chatbot_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/data/chatbot/datasources/chatbot_remote_data_source.dart';
import 'package:planmate_app/data/chatbot/models/chat_request_model.dart';
import 'package:planmate_app/domain/chatbot/repositories/chatbot_repository.dart';

class ChatbotRepositoryImpl implements ChatbotRepository {
  final ChatbotRemoteDataSource remoteDataSource;

  ChatbotRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> sendChatMessage(
    ChatRequestModel request,
  ) async {
    try {
      final result = await remoteDataSource.sendChatMessage(request);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
