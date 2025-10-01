import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/data/auth/datasources/auth_remote_data_source.dart';
import 'package:planmate_app/domain/auth/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAuthTokenKey = 'auth_token';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.sharedPreferences,
  });

  @override
  Future<Either<Failure, Unit>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final token = await remoteDataSource.signIn(
        email: email,
        password: password,
      );
      await sharedPreferences.setString(kAuthTokenKey, token);
      return Right(unit);
    } catch (_) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final message = await remoteDataSource.signUp(
        fullName: fullName,
        email: email,
        password: password,
      );
      return right(message);
    } catch (_) {
      return left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn() async {
    try {
      final token = sharedPreferences.getString(kAuthTokenKey);
      return Right(token != null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await sharedPreferences.remove(kAuthTokenKey);
      return right(unit);
    } catch (e) {
      return left(CacheFailure());
    }
  }
}
