import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/presentation/features/home/bloc/home_bloc.dart';
import 'package:planmate_app/presentation/features/home/bloc/home_event.dart';
import 'package:planmate_app/presentation/features/task/bloc/all_tasks_bloc.dart';
import 'package:planmate_app/presentation/features/task/bloc/all_tasks_event.dart';
import 'calendar_detail_page.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import 'add_calendar_page.dart';
import 'edit_calendar_page.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';

class CalendarManagementPage extends StatefulWidget {
  const CalendarManagementPage({super.key});
  @override
  State<CalendarManagementPage> createState() => _CalendarManagementPageState();
}

class _CalendarManagementPageState extends State<CalendarManagementPage> {
  List<CalendarEntity> _cachedCalendars = [];

  @override
  void initState() {
    super.initState();
    context.read<CalendarBloc>().add(FetchCalendars());
  }

  void _showDeleteConfirmationDialog(BuildContext context, int calendarId) {
    // NEW: guard trước khi mở dialog
    final list = _cachedCalendars;
    if (list.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa bộ lịch cuối cùng của bạn.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // CHANGED: dùng indexWhere để tránh lỗi kiểu generic với orElse
    final idx = list.indexWhere((c) => c.id == calendarId);
    final cal = idx >= 0 ? list[idx] : null;
    if (cal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy lịch để xóa.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (cal.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể xóa lịch mặc định. Hãy đặt lịch khác làm mặc định trước.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa lịch này không? Mọi công việc bên trong cũng sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              context.read<CalendarBloc>().add(
                DeleteCalendarSubmitted(calendarId: calendarId),
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
      appBar: AppBar(title: const Text('Quản lý Lịch')),
      body: BlocListener<CalendarBloc, CalendarState>(
        listener: (context, state) {
          if (state is CalendarOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            context.read<HomeBloc>().add(FetchHomeData());
            context.read<AllTasksBloc>().add(FetchAllTasks());
          } else if (state is CalendarError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            if (state is CalendarLoaded) {
              _cachedCalendars = state.calendars;
            }

            final isBusy =
                state is CalendarLoading ||
                state is CalendarOperationInProgress;

            if (_cachedCalendars.isEmpty && state is! CalendarLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_cachedCalendars.isEmpty) {
              return const Center(child: Text('Bạn chưa có lịch nào.'));
            }

            final listView = RefreshIndicator(
              onRefresh: () async {
                context.read<CalendarBloc>().add(
                  FetchCalendars(forceRemote: true),
                );
              },
              child: ListView.builder(
                itemCount: _cachedCalendars.length,
                itemBuilder: (context, index) {
                  final calendar = _cachedCalendars[index];
                  return ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(calendar.name),
                    subtitle: Text(
                      calendar.description ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CalendarDetailPage(calendar: calendar),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (calendar.isDefault)
                          const Icon(Icons.star, color: Colors.amber)
                        else
                          IconButton(
                            tooltip: 'Đặt làm mặc định',
                            icon: const Icon(Icons.star_border_outlined),
                            onPressed: () => context.read<CalendarBloc>().add(
                              SetDefaultCalendarSubmitted(
                                calendarId: calendar.id,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.grey,
                          ),
                          tooltip: 'Sửa',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditCalendarPage(calendar: calendar),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.grey,
                          ),
                          tooltip: 'Xóa',
                          onPressed: () => _showDeleteConfirmationDialog(
                            context,
                            calendar.id,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );

            return Stack(
              children: [
                listView,
                if (isBusy)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.05),
                      child: const Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddCalendarPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
