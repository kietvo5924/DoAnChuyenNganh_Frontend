import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../models/user_profile_model.dart';

abstract class UserRemoteDataSource {
  Future<UserProfileModel> getMyProfile();
  Future<String> changePassword(Map<String, String> passwordData);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final Dio dio;
  UserRemoteDataSourceImpl({required this.dio});

  @override
  Future<UserProfileModel> getMyProfile() async {
    final response = await dio.get('${ApiConfig.baseUrl}/users/me');
    return UserProfileModel.fromJson(response.data);
  }

  @override
  Future<String> changePassword(Map<String, String> passwordData) async {
    final response = await dio.put(
      '${ApiConfig.baseUrl}/users/me/change-password',
      data: passwordData,
    );
    return response.data;
  }
}
