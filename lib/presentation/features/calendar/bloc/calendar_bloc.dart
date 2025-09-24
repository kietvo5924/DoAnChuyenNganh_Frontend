import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/usecases/create_calendar.dart';
import '../../../../domain/calendar/usecases/delete_calendar.dart';
import '../../../../domain/calendar/usecases/get_all_calendars.dart';
import '../../../../domain/calendar/usecases/set_default_calendar.dart';
import '../../../../domain/calendar/usecases/update_calendar.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final GetAllCalendars _getAllCalendars;
  final CreateCalendar _createCalendar;
  final UpdateCalendar _updateCalendar;
  final DeleteCalendar _deleteCalendar;
  final SetDefaultCalendar _setDefaultCalendar;

  CalendarBloc({
    required GetAllCalendars getAllCalendars,
    required CreateCalendar createCalendar,
    required UpdateCalendar updateCalendar,
    required DeleteCalendar deleteCalendar,
    required SetDefaultCalendar setDefaultCalendar,
  }) : _getAllCalendars = getAllCalendars,
       _createCalendar = createCalendar,
       _updateCalendar = updateCalendar,
       _deleteCalendar = deleteCalendar,
       _setDefaultCalendar = setDefaultCalendar,
       super(CalendarInitial()) {
    on<FetchCalendars>((event, emit) async {
      emit(CalendarLoading());
      final result = await _getAllCalendars();
      result.fold(
        (failure) =>
            emit(const CalendarError(message: 'Tải danh sách lịch thất bại')),
        (calendars) => emit(CalendarLoaded(calendars: calendars)),
      );
    });

    on<AddCalendar>((event, emit) async {
      final result = await _createCalendar(event.name, event.description);
      result.fold(
        (failure) =>
            emit(const CalendarError(message: 'Thêm lịch mới thất bại')),
        (_) {
          emit(
            const CalendarOperationSuccess(message: 'Tạo lịch mới thành công!'),
          );
          add(FetchCalendars());
        },
      );
    });

    on<UpdateCalendarRequested>((event, emit) async {
      final result = await _updateCalendar(
        event.id,
        event.name,
        event.description,
      );
      result.fold(
        (failure) =>
            emit(const CalendarError(message: 'Cập nhật lịch thất bại')),
        (_) {
          emit(const CalendarOperationSuccess(message: 'Cập nhật thành công!'));
          add(FetchCalendars());
        },
      );
    });

    on<DeleteCalendarRequested>((event, emit) async {
      final result = await _deleteCalendar(event.id);
      result.fold(
        (failure) => emit(const CalendarError(message: 'Xóa lịch thất bại')),
        (_) {
          emit(const CalendarOperationSuccess(message: 'Đã xóa lịch!'));
          add(FetchCalendars());
        },
      );
    });

    on<SetDefaultCalendarRequested>((event, emit) async {
      final result = await _setDefaultCalendar(event.id);
      result.fold(
        (failure) =>
            emit(const CalendarError(message: 'Đặt làm mặc định thất bại')),
        (_) {
          emit(
            const CalendarOperationSuccess(
              message: 'Đã đặt làm lịch mặc định!',
            ),
          );
          add(FetchCalendars());
        },
      );
    });
  }
}
