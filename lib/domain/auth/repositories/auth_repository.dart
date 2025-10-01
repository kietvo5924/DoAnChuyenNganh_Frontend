import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, Unit>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, String>> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  Future<Either<Failure, bool>> isLoggedIn();

  Future<Either<Failure, Unit>> signOut();
}
