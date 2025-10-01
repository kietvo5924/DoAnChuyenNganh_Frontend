import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/calendar/usecases/sync_remote_calendars.dart';
import '../../../../domain/calendar/usecases/save_calendar.dart';
import '../../../../domain/calendar/usecases/delete_calendar.dart';
import '../../../../domain/calendar/usecases/set_default_calendar.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final GetLocalCalendars _getLocalCalendars;
  final SyncRemoteCalendars _syncRemoteCalendars;
  final SaveCalendar _saveCalendar;
  final DeleteCalendar _deleteCalendar;
  final SetDefaultCalendar _setDefaultCalendar;

  CalendarBloc({
    required GetLocalCalendars getLocalCalendars,
    required SyncRemoteCalendars syncRemoteCalendars,
    required SaveCalendar saveCalendar,
    required DeleteCalendar deleteCalendar,
    required SetDefaultCalendar setDefaultCalendar,
  }) : _getLocalCalendars = getLocalCalendars,
       _syncRemoteCalendars = syncRemoteCalendars,
       _saveCalendar = saveCalendar,
       _deleteCalendar = deleteCalendar,
       _setDefaultCalendar = setDefaultCalendar,
       super(CalendarInitial()) {
    on<FetchCalendars>((event, emit) async {
      // Nếu đã có dữ liệu và không ép làm mới -> chỉ reload local nhanh rồi thoát
      if (state is CalendarLoaded && !event.forceRemote) {
        final local = await _getLocalCalendars();
        local.fold((f) => null, (cals) {
          if (!emit.isDone) emit(CalendarLoaded(calendars: cals));
        });
        return;
      }

      emit(CalendarLoading());

      // 1. Lấy local
      final localResult = await _getLocalCalendars();
      List calendarsLocal = [];
      await localResult.fold(
        (f) async =>
            emit(const CalendarError(message: 'Không thể tải lịch local')),
        (cals) async {
          calendarsLocal = cals;
          emit(CalendarLoaded(calendars: cals));
        },
      );

      final needRemote =
          event.forceRemote || calendarsLocal.isEmpty; // NEW điều kiện

      if (!needRemote) {
        // Không cần gọi remote
        return;
      }

      // 2. Đồng bộ remote (im lặng nếu lỗi)
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
        if (!emit.isDone) emit(CalendarLoaded(calendars: cals));
      });
    });

    on<SaveCalendarSubmitted>((event, emit) async {
      emit(CalendarOperationInProgress());
      final result = await _saveCalendar(event.calendar);
      result.fold(
        (f) => emit(const CalendarError(message: 'Lưu lịch thất bại')),
        (_) {
          add(FetchCalendars());
          emit(const CalendarOperationSuccess(message: 'Đã lưu lịch'));
        },
      );
    });

    on<DeleteCalendarSubmitted>((event, emit) async {
      emit(CalendarOperationInProgress());
      final result = await _deleteCalendar(event.calendarId);
      result.fold(
        (f) => emit(const CalendarError(message: 'Xóa lịch thất bại')),
        (_) {
          add(FetchCalendars());
          emit(const CalendarOperationSuccess(message: 'Đã xóa lịch'));
        },
      );
    });

    on<SetDefaultCalendarSubmitted>((event, emit) async {
      emit(CalendarOperationInProgress());
      final result = await _setDefaultCalendar(event.calendarId);
      result.fold(
        (f) => emit(const CalendarError(message: 'Đặt mặc định thất bại')),
        (_) {
          add(FetchCalendars());
          emit(const CalendarOperationSuccess(message: 'Đã đặt làm mặc định'));
        },
      );
    });
  }
}
