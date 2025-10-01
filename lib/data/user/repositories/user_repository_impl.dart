import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../domain/user/entities/user_entity.dart';
import '../../../domain/user/repositories/user_repository.dart';
import '../datasources/user_local_data_source.dart';
import '../datasources/user_remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  final UserLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  UserRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, Unit>> syncUserProfile({
    bool forceRemote = false,
  }) async {
    try {
      if (!forceRemote) {
        final cached = await localDataSource.getUser();
        if (cached != null) {
          print('>>> USER SYNC: cache hit -> skip remote (forceRemote=false)');
          return Right(unit);
        } else {
          print('>>> USER SYNC: cache empty -> will fetch remote');
        }
      } else {
        print('>>> USER SYNC: forceRemote=true -> fetch remote');
      }
    } catch (e) {
      print('>>> USER SYNC: cache read error, fallback remote: $e');
    }

    bool connected = true;
    try {
      connected = await networkInfo.isConnected;
      print('>>> CONNECTIVITY CHECK (networkInfo.isConnected) = $connected');
    } catch (e) {
      print('>>> CONNECTIVITY CHECK ERROR: $e (giả định có mạng)');
      connected = true;
    }

    if (!connected) {
      print(
        '>>> Offline but forced remote fetch required? forceRemote=$forceRemote',
      );
    }

    try {
      print('>>> SYNC USER PROFILE REMOTE CALL');
      final remoteProfile = await remoteDataSource.getMyProfile();
      print('>>> REMOTE PROFILE RECEIVED: $remoteProfile');
      await localDataSource.cacheUser(remoteProfile);
      print('>>> USER SYNC: cached remote profile');
      return Right(unit);
    } catch (e, st) {
      print('>>> USER SYNC remote error: $e');
      if (e is DioException) {
        print('>>> DioException.status: ${e.response?.statusCode}');
      }
      print(st);
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCachedUser() async {
    try {
      final user = await localDataSource.getUser();
      return Right(user);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> clearCachedUser() async {
    try {
      await localDataSource.clearUser();
      return Right(unit);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, String>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmationPassword,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final message = await remoteDataSource.changePassword({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmationPassword': confirmationPassword,
        });
        return Right(message);
      } catch (e) {
        return Left(ServerFailure());
      }
    } else {
      return Left(NetworkFailure());
    }
  }
}
