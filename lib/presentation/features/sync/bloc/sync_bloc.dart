import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/usecases/sync_remote_calendars.dart';
import '../../../../domain/tag/usecases/sync_remote_tags.dart';
import '../../../../domain/task/usecases/sync_all_remote_tasks.dart';
import '../../../../domain/user/usecases/sync_user_profile.dart';
import '../../../../domain/user/usecases/get_cached_user.dart';
import 'sync_event.dart';
import 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final GetCachedUser _getCachedUser;
  final SyncUserProfile _syncUserProfile;
  final SyncRemoteCalendars _syncRemoteCalendars;
  final SyncRemoteTags _syncRemoteTags;
  final SyncAllRemoteTasks _syncAllRemoteTasks;

  SyncBloc({
    required GetCachedUser getCachedUser,
    required SyncUserProfile syncUserProfile,
    required SyncRemoteCalendars syncRemoteCalendars,
    required SyncRemoteTags syncRemoteTags,
    required SyncAllRemoteTasks syncAllRemoteTasks,
  }) : _getCachedUser = getCachedUser,
       _syncUserProfile = syncUserProfile,
       _syncRemoteCalendars = syncRemoteCalendars,
       _syncRemoteTags = syncRemoteTags,
       _syncAllRemoteTasks = syncAllRemoteTasks,
       super(SyncInitial()) {
    on<StartInitialSync>((event, emit) async {
      try {
        print('>>> SYNC: START');
        emit(
          const SyncInProgress(progress: 0.0, message: 'Bắt đầu đồng bộ...'),
        );

        // 1. User Profile (cache-first, fetch remote nếu chưa có)
        print('>>> SYNC STEP 1: User Profile (cache-first, fetch-if-missing)');
        emit(
          const SyncInProgress(
            progress: 0.1,
            message: 'Đang tải thông tin người dùng...',
          ),
        );

        bool hasCachedUser = false;
        final cachedResult = await _getCachedUser();
        await cachedResult.fold(
          (f) async {
            print('>>> SYNC STEP 1: Cache read failure -> sẽ thử remote');
          },
          (user) async {
            if (user != null) {
              hasCachedUser = true;
              print(
                '>>> SYNC STEP 1: FOUND cached user id=${user.id} email=${user.email} -> skip remote',
              );
            } else {
              print('>>> SYNC STEP 1: Cache EMPTY -> need remote fetch');
            }
          },
        );

        if (!hasCachedUser) {
          final remoteResult =
              await _syncUserProfile(); // forceRemote=false đủ vì cache rỗng
          if (remoteResult.isLeft()) {
            print('>>> SYNC STEP 1 FAILED (remote fetch user profile)');
            emit(const SyncFailure(message: 'Lỗi tải thông tin người dùng.'));
            return;
          } else {
            print('>>> SYNC STEP 1 DONE (remote fetched & cached)');
          }
        } else {
          print('>>> SYNC STEP 1 DONE (cache only)');
        }

        // 2. Calendars
        print('>>> SYNC STEP 2: Calendars');
        emit(
          const SyncInProgress(
            progress: 0.3,
            message: 'Đang tải các bộ lịch...',
          ),
        );
        var result = await _syncRemoteCalendars();
        if (result.isLeft()) {
          result.fold(
            (f) => print('>>> SYNC STEP 2 FAILURE TYPE: ${f.runtimeType}'),
            (_) {},
          );
          emit(const SyncFailure(message: 'Lỗi tải các bộ lịch.'));
          return;
        }
        print('>>> SYNC STEP 2 DONE');

        // 3. Tags
        print('>>> SYNC STEP 3: Tags');
        emit(
          const SyncInProgress(progress: 0.5, message: 'Đang tải các nhãn...'),
        );
        result = await _syncRemoteTags();
        if (result.isLeft()) {
          result.fold(
            (f) => print('>>> SYNC STEP 3 FAILURE TYPE: ${f.runtimeType}'),
            (_) {},
          );
          print('>>> GỢI Ý: kiểm tra TagRemoteDataSource headers / cache.');
          emit(const SyncFailure(message: 'Lỗi tải các nhãn.'));
          return;
        }
        print('>>> SYNC STEP 3 DONE');

        // 4. Tasks
        print('>>> SYNC STEP 4: Tasks');
        emit(
          const SyncInProgress(progress: 0.7, message: 'Đang tải công việc...'),
        );
        result = await _syncAllRemoteTasks();
        if (result.isLeft()) {
          bool isNetworkFailure = false;
          result.fold((f) {
            print('>>> SYNC STEP 4 FAILURE TYPE: ${f.runtimeType}');
            isNetworkFailure = f.runtimeType.toString() == 'NetworkFailure';
          }, (_) {});
          if (!isNetworkFailure) {
            emit(const SyncFailure(message: 'Lỗi tải các công việc.'));
            return;
          } else {
            print('>>> SYNC STEP 4: NetworkFailure ignored (offline skip)');
          }
        }
        print('>>> SYNC STEP 4 DONE');

        emit(const SyncInProgress(progress: 1.0, message: 'Hoàn tất!'));
        await Future.delayed(const Duration(milliseconds: 300));
        print('>>> SYNC: SUCCESS');
        emit(SyncSuccess());
      } catch (e) {
        print('>>> SYNC: UNCAUGHT ERROR $e');
        emit(
          const SyncFailure(
            message: 'Đồng bộ dữ liệu thất bại. Vui lòng thử lại.',
          ),
        );
      }
    });
  }
}
