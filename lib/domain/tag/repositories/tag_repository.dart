import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/tag_entity.dart';

abstract class TagRepository {
  Future<Either<Failure, List<TagEntity>>> getLocalTags();
  Future<Either<Failure, Unit>> syncRemoteTags();
  Future<Either<Failure, Unit>> saveTag(TagEntity tag);
  Future<Either<Failure, Unit>> deleteTag(int tagId);
}
