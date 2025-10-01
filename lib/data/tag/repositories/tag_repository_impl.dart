import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../domain/tag/entities/tag_entity.dart';
import '../../../domain/tag/repositories/tag_repository.dart';
import '../datasources/tag_local_data_source.dart';
import '../datasources/tag_remote_data_source.dart';

class TagRepositoryImpl implements TagRepository {
  final TagRemoteDataSource remoteDataSource;
  final TagLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  TagRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<TagEntity>>> getLocalTags() async {
    try {
      final localTags = await localDataSource.getAllTags();
      return Right(localTags);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> syncRemoteTags() async {
    final connected = await networkInfo.isConnected;
    print(
      '[TagRepository] connectivityFlag=$connected -> start remote attempt',
    );
    try {
      final remoteTags = await remoteDataSource.getAllTags();
      print('[TagRepository] fetched ${remoteTags.length} tags');
      await localDataSource.cacheTags(remoteTags);
      print('[TagRepository] cached tags locally');
      return Right(unit);
    } catch (e) {
      print('[TagRepository] error: $e');
      if (e is DioException) {
        final netLike =
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown;
        if (!connected && netLike) {
          print('[TagRepository] treat as offline skip (no failure)');
          return Right(unit); // graceful skip
        }
      }
      return Left(ServerFailure());
    }
  }

  // Các hàm save, delete sẽ được triển khai ở bước xây dựng Sync Queue
  @override
  Future<Either<Failure, Unit>> saveTag(TagEntity tag) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> deleteTag(int tagId) async {
    throw UnimplementedError();
  }
}
