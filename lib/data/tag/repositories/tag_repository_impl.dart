import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:planmate_app/data/auth/repositories/auth_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../domain/tag/entities/tag_entity.dart';
import '../../../domain/tag/repositories/tag_repository.dart';
import '../datasources/tag_local_data_source.dart';
import '../datasources/tag_remote_data_source.dart';
import '../../sync/datasources/sync_queue_local_data_source.dart';
import '../../sync/models/sync_queue_item_model.dart';
import '../models/tag_model.dart';

class TagRepositoryImpl implements TagRepository {
  final TagRemoteDataSource remoteDataSource;
  final TagLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final SyncQueueLocalDataSource syncQueueLocalDataSource;
  final SharedPreferences _prefs;

  TagRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.syncQueueLocalDataSource,
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  bool _hasToken() {
    final t = _prefs.getString(kAuthTokenKey);
    return t != null && t.isNotEmpty;
  }

  bool _isAuthRedirectOrUnauthorized(DioException e) {
    final c = e.response?.statusCode;
    return c == 302 || c == 401 || c == 403;
  }

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
    if (!_hasToken() || !connected) {
      return Right(unit);
    }
    try {
      final remoteTags = await remoteDataSource.getAllTags();
      await localDataSource.cacheTags(remoteTags);
      return Right(unit);
    } on DioException catch (e) {
      if (_isAuthRedirectOrUnauthorized(e)) {
        return Right(unit);
      }
      return Left(ServerFailure());
    } catch (_) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> saveTag(TagEntity tag) async {
    final connected = await networkInfo.isConnected;
    final onlineAndAuthed = connected && _hasToken();
    if (onlineAndAuthed) {
      try {
        TagModel saved = tag.id <= 0
            ? await remoteDataSource.createTag(tag.name, tag.color)
            : await remoteDataSource.updateTag(tag.id, tag.name, tag.color);
        await localDataSource.saveTag(saved, isSynced: true);
        return Right(unit);
      } on DioException catch (e) {
        if (_isAuthRedirectOrUnauthorized(e)) {
          // silent fallback
        } else {
          return Left(ServerFailure());
        }
      } catch (_) {
        return Left(ServerFailure());
      }
    }
    int localId = tag.id <= 0 ? -DateTime.now().millisecondsSinceEpoch : tag.id;
    final localModel = TagModel(id: localId, name: tag.name, color: tag.color);
    await localDataSource.saveTag(localModel, isSynced: false);
    await syncQueueLocalDataSource.addAction(
      SyncQueueItemModel(
        entityType: 'TAG',
        entityId: localId,
        action: 'UPSERT',
        payload: '{"name":"${tag.name}","color":"${tag.color}"}',
      ),
    );
    return Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteTag(int tagId) async {
    final connected = await networkInfo.isConnected;
    final onlineAndAuthed = connected && _hasToken();
    if (onlineAndAuthed && tagId > 0) {
      try {
        await remoteDataSource.deleteTag(tagId);
        await localDataSource.deleteTag(tagId);
        return Right(unit);
      } on DioException catch (e) {
        if (_isAuthRedirectOrUnauthorized(e)) {
          // silent
        } else {
          return Left(ServerFailure());
        }
      } catch (_) {
        return Left(ServerFailure());
      }
    }
    await localDataSource.deleteTag(tagId);
    await syncQueueLocalDataSource.addAction(
      SyncQueueItemModel(entityType: 'TAG', entityId: tagId, action: 'DELETE'),
    );
    return Right(unit);
  }
}
