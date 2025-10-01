import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/user/entities/user_entity.dart';
import 'package:planmate_app/domain/user/repositories/user_repository.dart';

class GetCachedUser {
  final UserRepository repository;

  GetCachedUser(this.repository);

  Future<Either<Failure, UserEntity?>> call() async {
    return await repository.getCachedUser();
  }
}
