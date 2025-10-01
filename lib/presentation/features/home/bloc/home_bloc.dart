import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/task/usecases/get_local_tasks_in_calendar.dart';
import '../../../../domain/task/usecases/get_all_local_tasks.dart'; // NEW
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetLocalCalendars _getLocalCalendars;
  final GetLocalTasksInCalendar _getLocalTasksInCalendar;
  final GetAllLocalTasks? _getAllLocalTasksOpt; // NEW (optional injected)

  HomeBloc({
    required GetLocalCalendars getLocalCalendars,
    required GetLocalTasksInCalendar getLocalTasksInCalendar,
    GetAllLocalTasks? getAllLocalTasks, // NEW optional param
  }) : _getLocalCalendars = getLocalCalendars,
       _getLocalTasksInCalendar = getLocalTasksInCalendar,
       _getAllLocalTasksOpt = getAllLocalTasks,
       super(HomeInitial()) {
    on<FetchHomeData>((event, emit) async {
      emit(HomeLoading());

      final calendarsResult = await _getLocalCalendars();
      await calendarsResult.fold(
        (failure) async {
          // Thay vì lỗi -> thử fallback qua toàn bộ task (nếu có)
          if (_getAllLocalTasksOpt != null) {
            final allTasksRes = await _getAllLocalTasksOpt!();
            allTasksRes.fold(
              (f) =>
                  emit(const HomeError(message: 'Không thể tải dữ liệu lịch')),
              (tasks) {
                if (tasks.isEmpty) {
                  emit(
                    const HomeError(
                      message: 'Bạn chưa có lịch hoặc công việc nào.',
                    ),
                  );
                } else {
                  // Chọn calendar giả định từ task đầu
                  final placeholderCal = CalendarEntity(
                    id: tasks.first.calendarId,
                    name: '(Lịch #${tasks.first.calendarId})',
                    description: null,
                    isDefault: true,
                  );
                  tasks.sort((a, b) => a.sortDate.compareTo(b.sortDate));
                  emit(
                    HomeLoaded(tasks: tasks, defaultCalendar: placeholderCal),
                  );
                }
              },
            );
          } else {
            emit(const HomeError(message: 'Không thể tải dữ liệu lịch'));
          }
        },
        (calendars) async {
          if (calendars.isEmpty) {
            // Fallback: thử lấy tasks không cần calendar nếu có use case
            if (_getAllLocalTasksOpt != null) {
              final allTasksRes = await _getAllLocalTasksOpt!();
              allTasksRes.fold(
                (f) => emit(const HomeError(message: 'Bạn chưa có lịch nào.')),
                (tasks) {
                  if (tasks.isEmpty) {
                    emit(const HomeError(message: 'Bạn chưa có lịch nào.'));
                    return;
                  }
                  final placeholderCal = CalendarEntity(
                    id: tasks.first.calendarId,
                    name: '(Lịch #${tasks.first.calendarId})',
                    description: null,
                    isDefault: true,
                  );
                  tasks.sort((a, b) => a.sortDate.compareTo(b.sortDate));
                  emit(
                    HomeLoaded(tasks: tasks, defaultCalendar: placeholderCal),
                  );
                },
              );
            } else {
              emit(const HomeError(message: 'Bạn chưa có lịch nào.'));
            }
            return;
          }

          // Tìm default, nếu không có dùng calendar đầu (KHÔNG báo lỗi)
          CalendarEntity defaultCalendar;
          try {
            defaultCalendar = calendars.firstWhere((c) => c.isDefault);
          } catch (_) {
            defaultCalendar = calendars.first;
          }

          final tasksResult = await _getLocalTasksInCalendar(
            defaultCalendar.id,
          );
          tasksResult.fold(
            (failure) async {
              // Fallback thử toàn bộ tasks
              if (_getAllLocalTasksOpt != null) {
                final allTasksRes = await _getAllLocalTasksOpt!();
                allTasksRes.fold(
                  (f) =>
                      emit(const HomeError(message: 'Không thể tải công việc')),
                  (tasks) {
                    tasks.sort((a, b) => a.sortDate.compareTo(b.sortDate));
                    emit(
                      HomeLoaded(
                        tasks: tasks,
                        defaultCalendar: defaultCalendar,
                      ),
                    );
                  },
                );
              } else {
                emit(const HomeError(message: 'Không thể tải công việc'));
              }
            },
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
