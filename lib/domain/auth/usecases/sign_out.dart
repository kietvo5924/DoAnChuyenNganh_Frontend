import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class SignOut {
  final AuthRepository repository;

  SignOut(this.repository);

  Future<Either<Failure, Unit>> call() async {
    return await repository.signOut();
  }
}
