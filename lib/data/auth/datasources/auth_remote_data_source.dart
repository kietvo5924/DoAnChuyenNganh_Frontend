import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';

abstract class AuthRemoteDataSource {
  Future<String> signIn({required String email, required String password});

  Future<String> signUp({
    required String fullName,
    required String email,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final response = await dio.post(
      '${ApiConfig.baseUrl}${ApiConfig.signInEndpoint}',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      return response.data['token'];
    } else {
      throw Exception('Failed to sign in');
    }
  }

  @override
  Future<String> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await dio.post(
      '${ApiConfig.baseUrl}${ApiConfig.signUpEndpoint}',
      data: {'fullName': fullName, 'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Đăng ký thất bại');
    }
  }
}
