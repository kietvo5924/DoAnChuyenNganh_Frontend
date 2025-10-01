import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/tag/entities/tag_entity.dart';
import 'package:planmate_app/domain/tag/repositories/tag_repository.dart';

class GetLocalTags {
  final TagRepository repository;
  GetLocalTags(this.repository);

  Future<Either<Failure, List<TagEntity>>> call() async {
    return await repository.getLocalTags();
  }
}
