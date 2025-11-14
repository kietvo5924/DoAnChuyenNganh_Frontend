import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/logger.dart';
import '../../../../domain/calendar/usecases/sync_remote_calendars.dart';
import '../../../../domain/tag/usecases/sync_remote_tags.dart';
import '../../../../domain/task/usecases/sync_all_remote_tasks.dart';
import '../../../../domain/user/usecases/sync_user_profile.dart';
import '../../../../domain/user/usecases/get_cached_user.dart';
import '../../../../domain/sync/usecases/merge_guest_data.dart'; // NEW
import '../../../../domain/sync/usecases/process_sync_queue.dart';
import '../../../../domain/sync/usecases/upload_guest_data.dart'; // NEW
import 'sync_event.dart';
import 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final GetCachedUser _getCachedUser;
  final SyncUserProfile _syncUserProfile;
  final SyncRemoteCalendars _syncRemoteCalendars;
  final SyncRemoteTags _syncRemoteTags;
  final SyncAllRemoteTasks _syncAllRemoteTasks;
  final MergeGuestData _mergeGuestData; // NEW
  final ProcessSyncQueue _processSyncQueue; // NEW
  final UploadGuestData _uploadGuestData; // NEW

  SyncBloc({
    required GetCachedUser getCachedUser,
    required SyncUserProfile syncUserProfile,
    required SyncRemoteCalendars syncRemoteCalendars,
    required SyncRemoteTags syncRemoteTags,
    required SyncAllRemoteTasks syncAllRemoteTasks,
    required MergeGuestData mergeGuestData, // NEW
    required ProcessSyncQueue processSyncQueue, // NEW
    required UploadGuestData uploadGuestData, // NEW
  }) : _getCachedUser = getCachedUser,
       _syncUserProfile = syncUserProfile,
       _syncRemoteCalendars = syncRemoteCalendars,
       _syncRemoteTags = syncRemoteTags,
       _syncAllRemoteTasks = syncAllRemoteTasks,
       _mergeGuestData = mergeGuestData, // NEW
       _processSyncQueue = processSyncQueue, // NEW
       _uploadGuestData = uploadGuestData, // NEW
       super(SyncInitial()) {
    on<StartInitialSync>((event, emit) async {
      try {
        emit(
          const SyncInProgress(progress: 0.0, message: 'Bắt đầu đồng bộ...'),
        );
        if (event.mergeGuest) {
          emit(
            const SyncInProgress(
              progress: 0.05,
              message: 'Đang chuẩn bị dữ liệu...',
            ),
          );
          await _mergeGuestData();
          await _uploadGuestData();
        }
        emit(const SyncInProgress(progress: 0.15, message: 'Người dùng...'));
        bool hasCachedUser = false;
        final cachedResult = await _getCachedUser();
        await cachedResult.fold(
          (f) async => Logger.w('STEP1: cache read failure'),
          (user) async {
            if (user != null && !event.forceUserRemote) {
              hasCachedUser = true;
              Logger.d('STEP1: cache hit -> skip remote');
            }
          },
        );
        if (!hasCachedUser || event.forceUserRemote) {
          final remoteResult = await _syncUserProfile();
          if (remoteResult.isLeft()) {
            emit(const SyncFailure(message: 'Lỗi tải thông tin người dùng.'));
            return;
          }
        }

        emit(
          const SyncInProgress(
            progress: 0.30,
            message: 'Đang tải các bộ lịch...',
          ),
        );
        final calRes = await _syncRemoteCalendars();
        if (calRes.isLeft()) {
          emit(const SyncFailure(message: 'Lỗi tải các bộ lịch.'));
          return;
        }
        emit(
          const SyncInProgress(progress: 0.45, message: 'Đang tải các nhãn...'),
        );
        final tagRes = await _syncRemoteTags();
        if (tagRes.isLeft()) {
          emit(const SyncFailure(message: 'Lỗi tải các nhãn.'));
          return;
        }

        emit(
          const SyncInProgress(progress: 0.7, message: 'Đang tải công việc...'),
        );
        final taskRes = await _syncAllRemoteTasks();
        if (taskRes.isLeft()) {
          bool fatal = true;
          taskRes.fold((f) {
            if (f.runtimeType.toString() == 'NetworkFailure') fatal = false;
          }, (_) {});
          if (fatal) {
            emit(const SyncFailure(message: 'Lỗi tải các công việc.'));
            return;
          }
        }

        if (!event.mergeGuest) {
          emit(
            const SyncInProgress(
              progress: 0.85,
              message: 'Đồng bộ thay đổi offline...',
            ),
          );
          await _processSyncQueue();
        } else {
          await _syncAllRemoteTasks();
        }

        emit(const SyncInProgress(progress: 1.0, message: 'Hoàn tất!'));
        await Future.delayed(const Duration(milliseconds: 200));
        emit(SyncSuccess());
      } catch (_) {
        emit(
          const SyncFailure(
            message: 'Đồng bộ dữ liệu thất bại. Vui lòng thử lại.',
          ),
        );
      }
    });
  }
}
