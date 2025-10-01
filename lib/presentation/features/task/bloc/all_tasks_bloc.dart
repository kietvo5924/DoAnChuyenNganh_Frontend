import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/task/entities/task_with_calendar.dart';
import '../../../../domain/task/usecases/get_all_local_tasks.dart';
import 'all_tasks_event.dart';
import 'all_tasks_state.dart';

class AllTasksBloc extends Bloc<AllTasksEvent, AllTasksState> {
  final GetLocalCalendars _getLocalCalendars;
  final GetAllLocalTasks _getAllLocalTasks;

  AllTasksBloc({
    required GetLocalCalendars getLocalCalendars,
    required GetAllLocalTasks getAllLocalTasks,
  }) : _getLocalCalendars = getLocalCalendars,
       _getAllLocalTasks = getAllLocalTasks,
       super(AllTasksInitial()) {
    on<FetchAllTasks>((event, emit) async {
      emit(AllTasksLoading());

      // 1. Lấy tất cả tasks (KHÔNG phụ thuộc calendars)
      final tasksResult = await _getAllLocalTasks();
      await tasksResult.fold(
        (f) async =>
            emit(const AllTasksError(message: 'Không thể tải công việc')),
        (tasks) async {
          // 2. Lấy calendars nếu có (có thể rỗng tạm thời)
          final calendarsResult = await _getLocalCalendars();

          // CHANGED: fold đồng bộ (không async) trả về Map ngay
          final calendarMap = calendarsResult.fold<Map<int, CalendarEntity>>(
            (_) => <int, CalendarEntity>{},
            (cals) => {for (final c in cals) c.id: c},
          );

          // 3. Ánh xạ task -> calendar (tạo placeholder nếu thiếu)
          final combined =
              tasks.map((t) {
                  final cal =
                      calendarMap[t.calendarId] ??
                      CalendarEntity(
                        id: t.calendarId,
                        name: '(Lịch #${t.calendarId})',
                        description: null,
                        isDefault: false,
                      );
                  return TaskWithCalendar(task: t, calendar: cal);
                }).toList()
                ..sort((a, b) => a.task.sortDate.compareTo(b.task.sortDate));

          emit(AllTasksLoaded(tasks: combined));
        },
      );
    });
  }
}
