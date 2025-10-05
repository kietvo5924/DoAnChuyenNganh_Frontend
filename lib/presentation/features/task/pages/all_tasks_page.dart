import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:planmate_app/presentation/features/calendar/bloc/calendar_event.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../calendar/bloc/calendar_bloc.dart';
import '../../calendar/bloc/calendar_state.dart';
import '../bloc/all_tasks_bloc.dart';
import '../bloc/all_tasks_event.dart';
import '../bloc/all_tasks_state.dart';
import 'task_editor_page.dart';

class AllTasksPage extends StatefulWidget {
  const AllTasksPage({super.key});

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  @override
  void initState() {
    super.initState();
    _fetchAllTasks();
    // NEW: đảm bảo có lịch sẵn cho dialog chọn
    final calBloc = context.read<CalendarBloc>();
    if (calBloc.state is! CalendarLoaded) {
      calBloc.add(FetchCalendars());
    }
  }

  void _fetchAllTasks() {
    // Nay dùng GetAllLocalTasks (đã sửa trong AllTasksBloc) -> tránh mất task sau khi sửa calendar
    context.read<AllTasksBloc>().add(FetchAllTasks());
  }

  void _showCalendarSelectionDialog(BuildContext pageContext) {
    // NEW: kích hoạt load lịch nếu chưa có
    final calBloc = pageContext.read<CalendarBloc>();
    if (calBloc.state is! CalendarLoaded) {
      calBloc.add(FetchCalendars());
    }

    showDialog(
      context: pageContext,
      builder: (dialogContext) {
        // NEW: đảm bảo dialog dùng đúng instance CalendarBloc
        return BlocProvider.value(
          value: calBloc,
          child: BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              if (state is CalendarLoaded) {
                if (state.calendars.isEmpty) {
                  return AlertDialog(
                    title: const Text('Chọn lịch'),
                    content: const Text(
                      'Chưa có lịch nào. Hãy tạo lịch trước.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Đóng'),
                      ),
                    ],
                  );
                }
                return SimpleDialog(
                  title: const Text('Chọn một lịch để thêm công việc'),
                  children: state.calendars.map((calendar) {
                    return SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          pageContext,
                          MaterialPageRoute(
                            builder: (_) => TaskEditorPage(calendar: calendar),
                          ),
                        ).then((created) {
                          if (created == true) _fetchAllTasks();
                        });
                      },
                      child: Text(calendar.name),
                    );
                  }).toList(),
                );
              }
              // Loading hoặc state khác
              return const Dialog(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Đang tải danh sách lịch...'),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _buildStartDisplay(TaskEntity task) {
    // CHANGED: and add debug
    if (task.repeatType == RepeatType.NONE) {
      final d = (task.startTime ?? task.sortDate).toLocal();
      final txt = (task.isAllDay == true)
          ? DateFormat('dd/MM/yyyy').format(d)
          : DateFormat('HH:mm dd/MM/yyyy').format(d);
      print(
        '[AllTasks][DBG] task=${task.id} single isAllDay=${task.isAllDay} start="$txt"',
      );
      return txt;
    } else {
      final base = (task.repeatStart ?? task.sortDate).toLocal();
      final tod = task.repeatStartTime;
      if (tod == null) {
        final txt = DateFormat('dd/MM/yyyy').format(base);
        print(
          '[AllTasks][DBG] task=${task.id} recurring tod=null display="$txt"',
        );
        return txt;
      }
      final dt = DateTime(
        base.year,
        base.month,
        base.day,
        tod.hour,
        tod.minute,
      );
      final txt = DateFormat('HH:mm dd/MM/yyyy').format(dt);
      print(
        '[AllTasks][DBG] task=${task.id} recurring tod=${tod.hour}:${tod.minute} display="$txt"',
      );
      return txt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả Công việc')),
      body: BlocBuilder<AllTasksBloc, AllTasksState>(
        builder: (context, state) {
          if (state is AllTasksLoaded) {
            if (state.tasks.isEmpty) {
              return const Center(child: Text('Bạn không có công việc nào.'));
            }
            return RefreshIndicator(
              onRefresh: () async => _fetchAllTasks(),
              child: ListView.builder(
                itemCount: state.tasks.length,
                itemBuilder: (context, index) {
                  final taskWithCalendar = state.tasks[index];
                  final task = taskWithCalendar.task;
                  final calendar = taskWithCalendar.calendar;

                  // CHANGED: build display text correctly
                  final startStr = _buildStartDisplay(task);

                  return ListTile(
                    leading: Icon(
                      task.repeatType == RepeatType.NONE
                          ? Icons.check_box_outline_blank
                          : Icons.repeat,
                    ),
                    title: Text(task.title),
                    subtitle: Text(
                      'Lịch: ${calendar.name} • Bắt đầu: $startStr',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskEditorPage(
                            calendar: calendar,
                            taskToEdit: task,
                          ),
                        ),
                      ).then((updated) {
                        if (updated == true) _fetchAllTasks();
                      });
                    },
                  );
                },
              ),
            );
          }
          if (state is AllTasksError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tạo công việc mới',
        onPressed: () => _showCalendarSelectionDialog(context),
        child: const Icon(Icons.add_task),
      ),
    );
  }
}
