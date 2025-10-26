import 'package:dartz/dartz.dart';
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
          return Right(unit);
        }
      }
    } catch (e) {
      print('>>> USER SYNC: cache read error, fallback remote: $e');
    }

    bool connected = true;
    try {
      connected = await networkInfo.isConnected;
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
      final remoteProfile = await remoteDataSource.getMyProfile();
      await localDataSource.cacheUser(remoteProfile);
      return Right(unit);
    } catch (_) {
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
