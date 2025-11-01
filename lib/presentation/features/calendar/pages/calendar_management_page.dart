// lib/presentation/features/calendar/pages/calendar_management_page.dart
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
// NEW: auth state to detect guest mode
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class CalendarManagementPage extends StatefulWidget {
  const CalendarManagementPage({super.key});
  @override
  State<CalendarManagementPage> createState() => _CalendarManagementPageState();
}

class _CalendarManagementPageState extends State<CalendarManagementPage> {
  // Cache riêng cho 2 danh sách
  List<CalendarEntity> _myCalendars = [];
  List<CalendarEntity> _sharedCalendars = [];

  @override
  void initState() {
    super.initState();
    // Fetch lịch khi vào trang
    context.read<CalendarBloc>().add(FetchCalendars());
    // Chỉ fetch lịch được chia sẻ nếu KHÔNG ở chế độ khách
    final isGuest = context.read<AuthBloc>().state is AuthGuestSuccess;
    if (!isGuest) {
      context.read<CalendarBloc>().add(FetchSharedWithMeCalendars());
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, int calendarId) {
    // SỬA LỖI: Dùng cache _myCalendars thay vì state
    final listToCheck = _myCalendars;

    if (listToCheck.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa bộ lịch cuối cùng của bạn.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final idx = listToCheck.indexWhere((c) => c.id == calendarId);
    final cal = idx >= 0 ? listToCheck[idx] : null;
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
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isGuest = authState is AuthGuestSuccess;
        final tabLength = isGuest ? 1 : 2;

        return DefaultTabController(
          length: tabLength,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Quản lý Lịch'),
              bottom: TabBar(
                tabs: [
                  const Tab(text: 'Lịch của tôi'),
                  if (!isGuest) const Tab(text: 'Được chia sẻ'),
                ],
              ),
            ),
            body: BlocListener<CalendarBloc, CalendarState>(
              listener: (context, state) {
                if (state is CalendarOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Fetch lại cả 2 danh sách khi có thao tác thành công
                  context.read<CalendarBloc>().add(FetchCalendars());
                  context.read<CalendarBloc>().add(
                    FetchSharedWithMeCalendars(),
                  );
                  // Cập nhật home và tasks
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
                  // Cập nhật cache khi state thay đổi
                  // SỬA ĐỔI QUAN TRỌNG:
                  if (state is CalendarLoaded) {
                    _myCalendars = state.calendars; // Đọc từ state.calendars
                  } else if (state is CalendarSharedWithMeLoaded) {
                    _sharedCalendars =
                        state.calendars; // Đọc từ state.calendars
                  }

                  final isBusy =
                      state is CalendarLoading ||
                      state is CalendarOperationInProgress;

                  return Stack(
                    children: [
                      TabBarView(
                        children: [
                          // Tab 1: Lịch của tôi (dùng cache _myCalendars)
                          _buildMyCalendarsList(
                            context,
                            _myCalendars,
                            isBusy,
                            state,
                          ),
                          if (!isGuest)
                            // Tab 2: Lịch được chia sẻ (dùng cache _sharedCalendars)
                            _buildSharedCalendarsList(
                              context,
                              _sharedCalendars,
                              isBusy,
                              state,
                            ),
                        ],
                      ),
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
          ),
        );
      },
    );
  }

  // Widget cho Tab "Lịch của tôi"
  Widget _buildMyCalendarsList(
    BuildContext context,
    List<CalendarEntity> calendars,
    bool isBusy,
    CalendarState state,
  ) {
    if (calendars.isEmpty && !isBusy && state is! CalendarLoading) {
      return const Center(child: Text('Bạn chưa có lịch nào.'));
    }

    if (calendars.isEmpty && state is CalendarLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CalendarBloc>().add(FetchCalendars(forceRemote: true));
      },
      child: ListView.builder(
        itemCount: calendars.length,
        itemBuilder: (context, index) {
          final calendar = calendars[index];
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
                  builder: (_) => CalendarDetailPage(calendar: calendar),
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
                      SetDefaultCalendarSubmitted(calendarId: calendar.id),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                  tooltip: 'Sửa',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditCalendarPage(calendar: calendar),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  tooltip: 'Xóa',
                  onPressed: () =>
                      _showDeleteConfirmationDialog(context, calendar.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget cho Tab "Được chia sẻ"
  Widget _buildSharedCalendarsList(
    BuildContext context,
    List<CalendarEntity> calendars,
    bool isBusy,
    CalendarState state,
  ) {
    if (calendars.isEmpty && !isBusy && state is! CalendarLoading) {
      return const Center(
        child: Text('Chưa có lịch nào được chia sẻ với bạn.'),
      );
    }

    if (calendars.isEmpty && state is CalendarLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CalendarBloc>().add(FetchSharedWithMeCalendars());
      },
      child: ListView.builder(
        itemCount: calendars.length,
        itemBuilder: (context, index) {
          final calendar = calendars[index];
          return ListTile(
            leading: Icon(
              Icons.folder_shared_outlined,
              color: Theme.of(context).primaryColor,
            ),
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
                  builder: (_) => CalendarDetailPage(calendar: calendar),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
