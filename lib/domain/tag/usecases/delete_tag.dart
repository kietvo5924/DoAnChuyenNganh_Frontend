import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/tag/repositories/tag_repository.dart';

class DeleteTag {
  final TagRepository repository;
  DeleteTag(this.repository);

  Future<Either<Failure, Unit>> call(int id) async {
    return await repository.deleteTag(id);
  }
}
