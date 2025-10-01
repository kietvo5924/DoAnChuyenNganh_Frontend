import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_list_bloc.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_list_event.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_list_state.dart';
import 'package:planmate_app/presentation/features/task/pages/task_editor_page.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/task/entities/task_entity.dart';

class CalendarDetailPage extends StatefulWidget {
  final CalendarEntity calendar;
  const CalendarDetailPage({super.key, required this.calendar});

  @override
  State<CalendarDetailPage> createState() => _CalendarDetailPageState();
}

class _CalendarDetailPageState extends State<CalendarDetailPage> {
  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  void _fetchTasks() {
    context.read<TaskListBloc>().add(
      FetchTasksInCalendar(calendarId: widget.calendar.id),
    );
  }

  void _showDeleteConfirmationDialog(TaskEntity task) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa công việc "${task.title}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskListBloc>().add(
                DeleteTaskFromList(task: task, calendarId: widget.calendar.id),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.calendar.name)),
      body: BlocListener<TaskListBloc, TaskListState>(
        listener: (context, state) {
          if (state is TaskListOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TaskListError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<TaskListBloc, TaskListState>(
          builder: (context, state) {
            if (state is TaskListLoaded) {
              if (state.tasks.isEmpty) {
                return const Center(
                  child: Text('Lịch này chưa có công việc nào.'),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _fetchTasks(),
                child: ListView.builder(
                  itemCount: state.tasks.length,
                  itemBuilder: (context, index) {
                    final task = state.tasks[index];
                    return ListTile(
                      leading: Icon(
                        task.repeatType == RepeatType.NONE
                            ? Icons.check_box_outline_blank
                            : Icons.repeat,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        task.repeatType == RepeatType.NONE
                            ? 'Bắt đầu: ${DateFormat('HH:mm dd/MM/yyyy').format(task.startTime!.toLocal())}'
                            : 'Bắt đầu từ: ${DateFormat('dd/MM/yyyy').format(task.repeatStart!)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.grey,
                            ),
                            tooltip: 'Sửa',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaskEditorPage(
                                    calendar: widget.calendar,
                                    taskToEdit: task,
                                  ),
                                ),
                              ).then((result) {
                                if (result == true) _fetchTasks();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.grey,
                            ),
                            tooltip: 'Xóa',
                            onPressed: () =>
                                _showDeleteConfirmationDialog(task),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }
            if (state is TaskListError) {
              return Center(child: Text(state.message));
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskEditorPage(calendar: widget.calendar),
            ),
          ).then((result) {
            if (result == true) _fetchTasks();
          });
        },
        child: const Icon(Icons.add_task),
      ),
    );
  }
}
