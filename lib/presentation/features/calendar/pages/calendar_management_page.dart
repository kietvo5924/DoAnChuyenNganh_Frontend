import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'calendar_detail_page.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import 'add_calendar_page.dart';
import 'edit_calendar_page.dart';

class CalendarManagementPage extends StatefulWidget {
  const CalendarManagementPage({super.key});
  @override
  State<CalendarManagementPage> createState() => _CalendarManagementPageState();
}

class _CalendarManagementPageState extends State<CalendarManagementPage> {
  @override
  void initState() {
    super.initState();
    context.read<CalendarBloc>().add(FetchCalendars());
  }

  void _showDeleteConfirmationDialog(BuildContext context, int calendarId) {
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
              if (state.calendars.isEmpty) {
                return const Center(child: Text('Bạn chưa có lịch nào.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<CalendarBloc>().add(FetchCalendars());
                },
                child: ListView.builder(
                  itemCount: state.calendars.length,
                  itemBuilder: (context, index) {
                    final calendar = state.calendars[index];
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
                            const Icon(Icons.star, color: Colors.amber),
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
            }
            return const Center(child: CircularProgressIndicator());
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
