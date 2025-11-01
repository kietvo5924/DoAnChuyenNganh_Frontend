import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/calendar/usecases/get_calendars_shared_with_me.dart';
import '../../../../domain/task/entities/task_with_calendar.dart';
import '../../../../domain/task/usecases/get_all_local_tasks.dart';
import 'all_tasks_event.dart';
import 'all_tasks_state.dart';

class AllTasksBloc extends Bloc<AllTasksEvent, AllTasksState> {
  final GetLocalCalendars _getLocalCalendars;
  final GetAllLocalTasks _getAllLocalTasks;
  final GetCalendarsSharedWithMe _getCalendarsSharedWithMe;

  AllTasksBloc({
    required GetLocalCalendars getLocalCalendars,
    required GetAllLocalTasks getAllLocalTasks,
    required GetCalendarsSharedWithMe getCalendarsSharedWithMe,
  }) : _getLocalCalendars = getLocalCalendars,
       _getAllLocalTasks = getAllLocalTasks,
       _getCalendarsSharedWithMe = getCalendarsSharedWithMe,
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

          // 2b. Lấy danh sách calendar được chia sẻ với tôi từ remote (nếu có)
          // Nếu không có mạng hoặc lỗi, ta tiếp tục với tập rỗng — this is best-effort.
          final sharedResult = await _getCalendarsSharedWithMe();
          final sharedIds = sharedResult.fold<List<int>>(
            (_) => [],
            (cals) => cals.map((c) => c.id).toList(),
          );

          // 3. Ánh xạ task -> calendar (tạo placeholder nếu thiếu)
          //    FILTER: exclude tasks that belong to calendars that are shared-with-me
          //    (i.e., calendars where permissionLevel != null). This prevents
          //    showing other people's shared calendars in the global "All tasks" view.
          final combined =
              tasks
                  .map((t) {
                    final cal =
                        calendarMap[t.calendarId] ??
                        CalendarEntity(
                          id: t.calendarId,
                          name: '(Lịch #${t.calendarId})',
                          description: null,
                          isDefault: false,
                        );
                    return TaskWithCalendar(task: t, calendar: cal);
                  })
                  // remove tasks whose calendar has a non-null permissionLevel (shared)
                  // or tasks that belong to calendars that appear in the "shared with me" list
                  .where(
                    (twc) =>
                        (twc.calendar.permissionLevel == null) &&
                        !sharedIds.contains(twc.calendar.id),
                  )
                  .toList()
                ..sort((a, b) => a.task.sortDate.compareTo(b.task.sortDate));

          emit(AllTasksLoaded(tasks: combined));
        },
      );
    });
  }
}
