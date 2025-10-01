import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/user/repositories/user_repository.dart';

class ClearCachedUser {
  final UserRepository repository;
  ClearCachedUser(this.repository);

  Future<Either<Failure, Unit>> call() async {
    return await repository.clearCachedUser();
  }
}
