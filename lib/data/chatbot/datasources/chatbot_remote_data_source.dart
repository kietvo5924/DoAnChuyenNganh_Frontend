// lib/data/chatbot/datasources/chatbot_remote_data_source.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:planmate_app/core/config/api_config.dart'; // Giả sử bạn có file này
import 'package:planmate_app/data/chatbot/models/chat_request_model.dart';

abstract class ChatbotRemoteDataSource {
  Future<String> sendChatMessage(ChatRequestModel request);
}

class ChatbotRemoteDataSourceImpl implements ChatbotRemoteDataSource {
  final Dio dio;

  ChatbotRemoteDataSourceImpl({required this.dio});

  @override
  Future<String> sendChatMessage(ChatRequestModel request) async {
    try {
      final response = await dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.chatbotUrl}',
        data: request.toJson(),
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          // Backend returns plain text (String). Avoid JSON decode errors.
          responseType: ResponseType.plain,
          // Allow handling 3xx/4xx here instead of throwing
          validateStatus: (code) => code != null && code < 500,
          followRedirects: false,
        ),
      );

      // Handle common auth misconfigs (302 to /login, 401, 403)
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is String) {
          final trimmed = data.trim();
          // If backend ever returns JSON object with {"message": ...}
          if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
            try {
              final decoded = jsonDecode(trimmed);
              if (decoded is Map && decoded['message'] is String) {
                return decoded['message'] as String;
              }
            } catch (_) {
              // fall through to return raw string
            }
          }
          return data;
        }
        // In case some middleware already decoded JSON
        if (data is Map && data['message'] is String)
          return data['message'] as String;
        throw Exception('Lỗi API: Dữ liệu phản hồi không hợp lệ');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Không được phép (${response.statusCode}). Vui lòng đăng nhập lại.',
        );
      }

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is String) return data;
        if (data is Map && data['message'] is String)
          return data['message'] as String;
        throw Exception('Lỗi API: Dữ liệu phản hồi không hợp lệ');
      }

      throw Exception('Lỗi API: ${response.statusCode}');
    } on DioException catch (e) {
      // Xử lý lỗi Dio (ví dụ: 404, 500)
      throw Exception('Lỗi Dio: ${e.message}');
    }
  }
}
