import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/tag/usecases/delete_tag.dart';
import '../../../../domain/tag/usecases/get_local_tags.dart';
import '../../../../domain/tag/usecases/save_tag.dart';
import '../../../../domain/tag/usecases/sync_remote_tags.dart';
import 'tag_event.dart';
import 'tag_state.dart';

class TagBloc extends Bloc<TagEvent, TagState> {
  final GetLocalTags _getLocalTags;
  final SyncRemoteTags _syncRemoteTags;
  final SaveTag _saveTag;
  final DeleteTag _deleteTag;

  TagBloc({
    required GetLocalTags getLocalTags,
    required SyncRemoteTags syncRemoteTags,
    required SaveTag saveTag,
    required DeleteTag deleteTag,
  }) : _getLocalTags = getLocalTags,
       _syncRemoteTags = syncRemoteTags,
       _saveTag = saveTag,
       _deleteTag = deleteTag,
       super(TagInitial()) {
    on<FetchTags>((event, emit) async {
      // Nếu đã load và không ép refresh -> reload local nhẹ (phòng có thay đổi khác) rồi return
      if (state is TagLoaded && !event.forceRemote) {
        final localResult = await _getLocalTags();
        localResult.fold((_) => null, (tags) {
          emit(TagLoaded(tags: tags));
        });
        return;
      }

      emit(TagLoading());

      final localResult = await _getLocalTags();
      List localTags = [];
      localResult.fold(
        (f) => emit(const TagError(message: 'Lỗi tải dữ liệu local')),
        (tags) {
          localTags = tags;
          emit(TagLoaded(tags: tags));
        },
      );

      final needRemote =
          event.forceRemote || localTags.isEmpty; // NEW điều kiện

      if (!needRemote) return;

      final syncResult = await _syncRemoteTags();
      syncResult.fold(
        (f) => print('[TagBloc] Remote sync failed: ${f.runtimeType}'),
        (_) => print('[TagBloc] Remote sync success'),
      );

      final refreshed = await _getLocalTags();
      refreshed.fold((_) => null, (tags) => emit(TagLoaded(tags: tags)));
    });

    on<SaveTagSubmitted>((event, emit) async {
      await _saveTag(event.tag);
      emit(const TagOperationSuccess(message: 'Đã lưu nhãn!'));
      add(FetchTags());
    });

    on<DeleteTagSubmitted>((event, emit) async {
      await _deleteTag(event.tagId);
      emit(const TagOperationSuccess(message: 'Đã xóa nhãn!'));
      add(FetchTags());
    });
  }
}
