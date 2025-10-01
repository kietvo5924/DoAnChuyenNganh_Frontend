import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/task/usecases/get_local_tasks_in_calendar.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  // Sửa lại tên các Use Case cho đúng
  final GetLocalCalendars _getLocalCalendars;
  final GetLocalTasksInCalendar _getLocalTasksInCalendar;

  HomeBloc({
    // Sửa lại tên các tham số cho đúng
    required GetLocalCalendars getLocalCalendars,
    required GetLocalTasksInCalendar getLocalTasksInCalendar,
  }) : _getLocalCalendars = getLocalCalendars,
       _getLocalTasksInCalendar = getLocalTasksInCalendar,
       super(HomeInitial()) {
    on<FetchHomeData>((event, emit) async {
      emit(HomeLoading());
      final calendarsResult = await _getLocalCalendars();
      await calendarsResult.fold(
        (failure) async =>
            emit(const HomeError(message: 'Không thể tải dữ liệu lịch')),
        (calendars) async {
          if (calendars.isEmpty) {
            emit(const HomeError(message: 'Bạn chưa có lịch nào.'));
            return;
          }
          CalendarEntity defaultCalendar;
          try {
            defaultCalendar = calendars.firstWhere((cal) => cal.isDefault);
          } catch (e) {
            defaultCalendar = calendars.first;
          }
          final tasksResult = await _getLocalTasksInCalendar(
            defaultCalendar.id,
          );
          tasksResult.fold(
            (failure) =>
                emit(const HomeError(message: 'Không thể tải công việc')),
            (tasks) {
              tasks.sort((a, b) => a.sortDate.compareTo(b.sortDate));
              emit(HomeLoaded(tasks: tasks, defaultCalendar: defaultCalendar));
            },
          );
        },
      );
    });
  }
}
