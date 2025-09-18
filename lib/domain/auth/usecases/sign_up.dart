import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/auth/repositories/auth_repository.dart';

class SignUp {
  final AuthRepository repository;

  SignUp(this.repository);

  Future<Either<Failure, String>> call({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return await repository.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
  }
}
