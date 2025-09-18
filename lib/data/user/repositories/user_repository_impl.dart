import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../core/error/failures.dart';
import 'package:planmate_app/data/user/datasources/user_remote_data_source.dart';
import 'package:planmate_app/domain/user/entities/user_profile.dart';
import '../../../domain/user/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  UserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, UserProfile>> getMyProfile() async {
    try {
      final userProfile = await remoteDataSource.getMyProfile();
      return Right(userProfile);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmationPassword,
  }) async {
    try {
      final message = await remoteDataSource.changePassword({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmationPassword': confirmationPassword,
      });
      return Right(message);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          message: e.response?.data.toString() ?? 'Lỗi không xác định',
        ),
      );
    }
  }
}
