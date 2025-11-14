import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/task/usecases/get_local_tasks_in_calendar.dart';
import '../../../../domain/task/usecases/get_all_local_tasks.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetLocalCalendars _getLocalCalendars;
  // Removed calendar-scoped fetch on Home, we show all tasks
  // final GetLocalTasksInCalendar _getLocalTasksInCalendar;
  final GetAllLocalTasks? _getAllLocalTasksOpt;

  HomeBloc({
    required GetLocalCalendars getLocalCalendars,
    required GetLocalTasksInCalendar getLocalTasksInCalendar,
    GetAllLocalTasks? getAllLocalTasks,
  }) : _getLocalCalendars = getLocalCalendars,
       // _getLocalTasksInCalendar = getLocalTasksInCalendar,
       _getAllLocalTasksOpt = getAllLocalTasks,
       super(HomeInitial()) {
    on<FetchHomeData>((event, emit) async {
      emit(HomeLoading());

      // Lấy danh sách calendars (nếu lỗi, xem như rỗng để vẫn hiển thị task)
      List<CalendarEntity> calendars = [];
      final calendarsResult = await _getLocalCalendars();
      calendarsResult.fold((_) {}, (cals) => calendars = cals);

      // Luôn hiển thị tất cả task trên trang Home
      if (_getAllLocalTasksOpt == null) {
        emit(const HomeError(message: 'Không thể tải công việc'));
        return;
      }

      final allTasksRes = await _getAllLocalTasksOpt();
      allTasksRes.fold(
        (f) {
          emit(const HomeError(message: 'Không thể tải công việc'));
        },
        (tasks) {
          tasks.sort((a, b) => a.sortDate.compareTo(b.sortDate));
          emit(HomeLoaded(tasks: tasks, calendars: calendars));
        },
      );
    });
  }
}
