import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/tag/repositories/tag_repository.dart';

class SyncRemoteTags {
  final TagRepository repository;
  SyncRemoteTags(this.repository);

  Future<Either<Failure, Unit>> call() async {
    return await repository.syncRemoteTags();
  }
}
