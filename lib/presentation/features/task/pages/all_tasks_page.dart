import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
  }

  void _fetchAllTasks() {
    context.read<AllTasksBloc>().add(FetchAllTasks());
  }

  void _showCalendarSelectionDialog(BuildContext pageContext) {
    showDialog(
      context: pageContext,
      builder: (dialogContext) {
        return BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            if (state is CalendarLoaded) {
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
            return const Dialog(
              child: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
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

                  // Sử dụng getter `sortDate` đã được định nghĩa trong TaskEntity
                  final displayDate = task.sortDate;

                  return ListTile(
                    leading: Icon(
                      task.repeatType == RepeatType.NONE
                          ? Icons.check_box_outline_blank
                          : Icons.repeat,
                    ),
                    title: Text(task.title),
                    subtitle: Text(
                      'Lịch: ${calendar.name} • Bắt đầu: ${DateFormat('HH:mm dd/MM/yyyy').format(displayDate.toLocal())}',
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
