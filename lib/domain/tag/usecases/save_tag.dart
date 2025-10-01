import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/tag/entities/tag_entity.dart';
import 'package:planmate_app/domain/tag/repositories/tag_repository.dart';

class SaveTag {
  final TagRepository repository;

  SaveTag(this.repository);

  Future<Either<Failure, Unit>> call(TagEntity tag) async {
    return await repository.saveTag(tag);
  }
}
