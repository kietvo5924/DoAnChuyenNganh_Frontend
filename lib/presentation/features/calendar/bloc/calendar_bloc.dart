// lib/presentation/features/calendar/bloc/calendar_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart'; // Thêm import
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/calendar/usecases/sync_remote_calendars.dart';
import '../../../../domain/calendar/usecases/save_calendar.dart';
import '../../../../domain/calendar/usecases/delete_calendar.dart';
import '../../../../domain/calendar/usecases/set_default_calendar.dart';
import '../../../../domain/task/usecases/sync_all_remote_tasks.dart';
// THÊM CÁC USECASE MỚI
import '../../../../domain/calendar/usecases/share_calendar.dart';
import '../../../../domain/calendar/usecases/unshare_calendar.dart';
import '../../../../domain/calendar/usecases/get_users_sharing_calendar.dart';
import '../../../../domain/calendar/usecases/get_calendars_shared_with_me.dart';
// THÊM ENTITY
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  // Use cases cũ
  final GetLocalCalendars _getLocalCalendars;
  final SyncRemoteCalendars _syncRemoteCalendars;
  final SaveCalendar _saveCalendar;
  final DeleteCalendar _deleteCalendar;
  final SetDefaultCalendar _setDefaultCalendar;
  final SyncAllRemoteTasks _syncAllRemoteTasks;

  // Use cases MỚI
  final ShareCalendar _shareCalendar;
  final UnshareCalendar _unshareCalendar;
  final GetUsersSharingCalendar _getUsersSharingCalendar;
  final GetCalendarsSharedWithMe _getCalendarsSharedWithMe;

  CalendarBloc({
    // Cũ
    required GetLocalCalendars getLocalCalendars,
    required SyncRemoteCalendars syncRemoteCalendars,
    required SaveCalendar saveCalendar,
    required DeleteCalendar deleteCalendar,
    required SetDefaultCalendar setDefaultCalendar,
    required SyncAllRemoteTasks syncAllRemoteTasks,
    // MỚI
    required ShareCalendar shareCalendar,
    required UnshareCalendar unshareCalendar,
    required GetUsersSharingCalendar getUsersSharingCalendar,
    required GetCalendarsSharedWithMe getCalendarsSharedWithMe,
  }) : _getLocalCalendars = getLocalCalendars,
       _syncRemoteCalendars = syncRemoteCalendars,
       _saveCalendar = saveCalendar,
       _deleteCalendar = deleteCalendar,
       _setDefaultCalendar = setDefaultCalendar,
       _syncAllRemoteTasks = syncAllRemoteTasks,
       // Gán MỚI
       _shareCalendar = shareCalendar,
       _unshareCalendar = unshareCalendar,
       _getUsersSharingCalendar = getUsersSharingCalendar,
       _getCalendarsSharedWithMe = getCalendarsSharedWithMe,
       super(CalendarInitial()) {
    // Các handler cũ
    on<FetchCalendars>(_onFetchCalendars);
    on<SaveCalendarSubmitted>(_onSaveCalendarSubmitted);
    on<DeleteCalendarSubmitted>(_onDeleteCalendarSubmitted);
    on<SetDefaultCalendarSubmitted>(_onSetDefaultCalendarSubmitted);

    // Các handler MỚI
    on<InitializeCalendarDetail>(_onInitializeCalendarDetail);
    on<ShareCalendarRequested>(_onShareCalendar);
    on<UnshareCalendarRequested>(_onUnshareCalendar);
    on<FetchSharingUsers>(_onFetchSharingUsers);
    on<FetchSharedWithMeCalendars>(_onFetchSharedWithMeCalendars);
  }

  // --- HÀM XỬ LÝ EVENT CŨ ---

  Future<void> _onFetchCalendars(
    FetchCalendars event,
    Emitter<CalendarState> emit,
  ) async {
    // Giữ lại state cũ (nếu có)
    if (state is CalendarLoaded && !event.forceRemote) {
      final local = await _getLocalCalendars();
      local.fold((f) => null, (cals) {
        if (!emit.isDone) {
          emit(CalendarLoaded(calendars: cals)); // Chỉ emit CalendarLoaded
        }
      });
      return;
    }

    emit(CalendarLoading());

    // 1. Lấy local
    List calendarsLocal = [];
    final localResult = await _getLocalCalendars();
    await localResult.fold(
      (f) async =>
          emit(const CalendarError(message: 'Không thể tải lịch local')),
      (cals) async {
        calendarsLocal = cals;
        emit(CalendarLoaded(calendars: cals)); // Chỉ emit CalendarLoaded
      },
    );

    final needRemote = event.forceRemote || calendarsLocal.isEmpty;

    if (!needRemote) {
      return; // Không cần gọi remote
    }

    // 2. Đồng bộ remote
    final syncResult = await _syncRemoteCalendars();
    syncResult.fold(
      (f) => print('[CalendarBloc] Skip remote or failure: ${f.runtimeType}'),
      (_) => print('[CalendarBloc] Remote sync success'),
    );

    // 3. Refresh sau sync
    final refreshed = await _getLocalCalendars();
    refreshed.fold((f) => print('[CalendarBloc] Refresh after sync failed'), (
      cals,
    ) {
      if (!emit.isDone) {
        emit(CalendarLoaded(calendars: cals)); // Chỉ emit CalendarLoaded
      }
    });
  }

  Future<void> _onSaveCalendarSubmitted(
    SaveCalendarSubmitted event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarOperationInProgress());
    final result = await _saveCalendar(event.calendar);
    await result.fold(
      (f) async => emit(const CalendarError(message: 'Lưu lịch thất bại')),
      (_) async {
        emit(const CalendarOperationSuccess(message: 'Đã lưu lịch'));
        add(FetchCalendars());
        await _syncAllRemoteTasks();
      },
    );
  }

  Future<void> _onDeleteCalendarSubmitted(
    DeleteCalendarSubmitted event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarOperationInProgress());
    final result = await _deleteCalendar(event.calendarId);
    await result.fold(
      (f) async => emit(const CalendarError(message: 'Xóa lịch thất bại')),
      (_) async {
        emit(const CalendarOperationSuccess(message: 'Đã xóa lịch'));
        add(FetchCalendars());
        await _syncAllRemoteTasks();
      },
    );
  }

  Future<void> _onSetDefaultCalendarSubmitted(
    SetDefaultCalendarSubmitted event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarOperationInProgress());
    final result = await _setDefaultCalendar(event.calendarId);
    await result.fold(
      (f) async => emit(const CalendarError(message: 'Đặt mặc định thất bại')),
      (_) async {
        emit(const CalendarOperationSuccess(message: 'Đã đặt làm mặc định'));
        add(FetchCalendars());
        await _syncAllRemoteTasks();
      },
    );
  }

  // --- HÀM XỬ LÝ EVENT MỚI ---

  Future<void> _onInitializeCalendarDetail(
    InitializeCalendarDetail event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarDetailLoaded(calendar: event.calendar, sharingUsers: []));
  }

  Future<void> _onShareCalendar(
    ShareCalendarRequested event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarOperationInProgress());
    final result = await _shareCalendar(
      calendarId: event.calendarId,
      email: event.email,
      permissionLevel: event.permissionLevel,
    );
    result.fold(
      (failure) => emit(
        CalendarError(
          message: failure is ServerFailure
              ? failure.message ?? 'Chia sẻ thất bại'
              : 'Chia sẻ thất bại',
        ),
      ),
      (_) {
        emit(const CalendarOperationSuccess(message: 'Đã chia sẻ lịch'));
        add(FetchSharingUsers(calendarId: event.calendarId));
      },
    );
  }

  Future<void> _onUnshareCalendar(
    UnshareCalendarRequested event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarOperationInProgress());
    final result = await _unshareCalendar(
      calendarId: event.calendarId,
      userId: event.userId,
    );
    result.fold(
      (failure) => emit(const CalendarError(message: 'Bỏ chia sẻ thất bại')),
      (_) {
        emit(const CalendarOperationSuccess(message: 'Đã bỏ chia sẻ lịch'));
        add(FetchSharingUsers(calendarId: event.calendarId));
      },
    );
  }

  Future<void> _onFetchSharingUsers(
    FetchSharingUsers event,
    Emitter<CalendarState> emit,
  ) async {
    final currentState = state;
    final result = await _getUsersSharingCalendar(event.calendarId);

    result.fold(
      (failure) {
        if (currentState is CalendarDetailLoaded) {
          emit(const CalendarError(message: 'Lỗi tải danh sách chia sẻ'));
          emit(currentState.copyWith(sharingUsers: []));
        }
      },
      (users) {
        if (currentState is CalendarDetailLoaded) {
          emit(currentState.copyWith(sharingUsers: users));
        }
      },
    );
  }

  Future<void> _onFetchSharedWithMeCalendars(
    FetchSharedWithMeCalendars event,
    Emitter<CalendarState> emit,
  ) async {
    // Không emit Loading để tránh làm tab "Lịch của tôi" bị giật
    final result = await _getCalendarsSharedWithMe();
    result.fold(
      (failure) =>
          emit(const CalendarError(message: 'Lỗi tải lịch được chia sẻ')),
      (calendars) {
        // SỬA ĐỔI: Chỉ emit state riêng cho tab "Được chia sẻ"
        emit(CalendarSharedWithMeLoaded(calendars: calendars));
      },
    );
  }
}
