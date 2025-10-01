import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/user/repositories/user_repository.dart';

class SyncUserProfile {
  final UserRepository repository;
  SyncUserProfile(this.repository);

  Future<Either<Failure, Unit>> call({bool forceRemote = false}) {
    return repository.syncUserProfile(forceRemote: forceRemote);
  }
}
