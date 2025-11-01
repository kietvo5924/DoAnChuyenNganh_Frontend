// lib/presentation/features/calendar/pages/calendar_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_list_bloc.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_list_event.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_list_state.dart';
import 'package:planmate_app/presentation/features/task/pages/task_editor_page.dart';
import 'dart:convert';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/task/entities/task_entity.dart';
// Thêm các import cho CalendarBloc
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
// Thêm import cho UserEntity (nếu chưa có)
import '../../../../domain/user/entities/user_entity.dart';
// NEW: direct usecase + datasources fallback
import 'package:planmate_app/injection.dart';
import 'package:planmate_app/domain/calendar/usecases/get_users_sharing_calendar.dart';
import 'package:planmate_app/data/task/datasources/task_remote_data_source.dart';
import 'package:planmate_app/data/task/datasources/task_local_data_source.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class CalendarDetailPage extends StatelessWidget {
  final CalendarEntity calendar;
  const CalendarDetailPage({super.key, required this.calendar});

  @override
  Widget build(BuildContext context) {
    // Use the existing CalendarBloc from ancestor; do not create a new instance here.
    return _CalendarDetailPageView(calendar: calendar);
  }
}

// Tách view ra để sử dụng BlocProvider
class _CalendarDetailPageView extends StatefulWidget {
  final CalendarEntity calendar;
  const _CalendarDetailPageView({required this.calendar});

  @override
  State<_CalendarDetailPageView> createState() =>
      _CalendarDetailPageViewState();
}

class _CalendarDetailPageViewState extends State<_CalendarDetailPageView> {
  // NEW: local cache to show users list immediately even if bloc switches state
  List<UserEntity> _sharingUsersLocal = [];
  // NEW: cache owned calendar IDs to avoid race with bloc state changes
  final Set<int> _ownedCalendarIds = {};

  @override
  void initState() {
    super.initState();
    // Initialize detail state on existing CalendarBloc
    final calBloc = context.read<CalendarBloc>();
    calBloc.add(InitializeCalendarDetail(calendar: widget.calendar));

    // NEW: seed owned IDs immediately if calendars already loaded
    final st = calBloc.state;
    if (st is CalendarLoaded) {
      _ownedCalendarIds
        ..clear()
        ..addAll(st.calendars.map((c) => c.id));
    } else {
      calBloc.add(FetchCalendars());
    }

    _fetchTasks();

    // NEW: refresh sharing users right away (no need to wait for CalendarLoaded)
    _refreshSharingUsersIfOwned();

    // Ensure tasks pulled for shared-with-me calendars
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureRemoteTasksForSharedCalendar();
    });
  }

  void _fetchTasks() {
    context.read<TaskListBloc>().add(
      FetchTasksInCalendar(calendarId: widget.calendar.id),
    );
  }

  // Helper: ownership via cached IDs
  bool _isOwnedId(int id) => _ownedCalendarIds.contains(id);

  // NEW: compute canEdit = owned OR shared-can-edit
  bool get _canEditCurrentCalendar {
    if (_isOwnedId(widget.calendar.id)) return true;
    final p = (widget.calendar.permissionLevel ?? '').toString().toUpperCase();
    return p == 'EDIT';
  }

  // Fetch sharing users directly into local cache
  Future<void> _fetchSharingUsersDirect() async {
    try {
      final res = await getIt<GetUsersSharingCalendar>().call(
        widget.calendar.id,
      );
      res.fold((_) {}, (users) {
        if (!mounted) return;
        setState(() {
          _sharingUsersLocal = users;
        });
      });
    } catch (_) {
      // silent
    }
  }

  // Only fetch if owned; update both bloc and local cache for instant UI
  void _refreshSharingUsersIfOwned() {
    if (_isOwnedId(widget.calendar.id)) {
      context.read<CalendarBloc>().add(
        FetchSharingUsers(calendarId: widget.calendar.id),
      );
      _fetchSharingUsersDirect(); // show immediately
    }
  }

  // Ensure tasks are present for "shared-with-me" calendars
  Future<void> _ensureRemoteTasksForSharedCalendar() async {
    if (_isOwnedId(widget.calendar.id)) return;
    try {
      final remote = getIt<TaskRemoteDataSource>();
      final local = getIt<TaskLocalDataSource>();
      final models = await remote.getAllTasksInCalendar(widget.calendar.id);
      await local.cacheTasks(models);
      if (!mounted) return;
      _fetchTasks();
    } catch (_) {
      // silent
    }
  }

  // Hàm mới: Hiển thị dialog chia sẻ
  void _showShareDialog() {
    final emailController = TextEditingController();
    String selectedPermission = 'VIEW_ONLY'; // Mặc định

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          // Dùng StatefulBuilder để cập nhật Dropdown
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Chia sẻ "${widget.calendar.name}"'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email người nhận',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPermission,
                    items: const [
                      DropdownMenuItem(
                        value: 'VIEW_ONLY',
                        child: Text('Chỉ xem'),
                      ),
                      DropdownMenuItem(
                        value: 'EDIT',
                        child: Text('Xem và Chỉnh sửa'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          // Cập nhật state của dialog
                          selectedPermission = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () {
                    final email = emailController.text.trim();
                    if (email.isNotEmpty) {
                      // Gọi BLoC để thực hiện chia sẻ
                      // Dùng context của Scaffold (widget.context) thay vì context của dialog
                      context.read<CalendarBloc>().add(
                        ShareCalendarRequested(
                          calendarId: widget.calendar.id,
                          email: email,
                          permissionLevel: selectedPermission,
                        ),
                      );
                      Navigator.pop(dialogContext); // Đóng dialog
                    } else {
                      // Hiển thị lỗi email trống nếu cần
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập email'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Chia sẻ'),
                ),
              ],
            );
          },
        );
      },
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

  // REPLACE: richer bottom sheet detail (always show edit)
  void _showTaskDetailDialog(TaskEntity task) {
    // final canEdit = _canEditCurrentCalendar; // REMOVED
    final isSingle = task.repeatType == RepeatType.NONE;
    final hasDesc =
        (task.description != null && task.description!.trim().isNotEmpty);
    final tz = task.timezone;
    final exceptionsCount = (() {
      try {
        if (task.exceptions == null) return 0;
        final v = jsonDecode(task.exceptions!);
        if (v is List) return v.length;
        return 0;
      } catch (_) {
        return 0;
      }
    })();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: const [
                BoxShadow(blurRadius: 8, color: Colors.black26),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      isSingle ? Icons.event_outlined : Icons.repeat,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(widget.calendar.name),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDesc)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(task.description!.trim()),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.category_outlined,
                                size: 18,
                              ),
                              label: Text(_repeatSummary(task)),
                            ),
                            if (isSingle && task.isAllDay == true)
                              const Chip(
                                avatar: Icon(Icons.wb_sunny_outlined, size: 18),
                                label: Text('Cả ngày'),
                              ),
                            if (task.preDayNotify == true)
                              Chip(
                                avatar: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 18,
                                ),
                                label: const Text('Nhắc trước 1 ngày (18:00)'),
                                backgroundColor: Colors.orange.shade50,
                              ),
                            Chip(
                              avatar: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                              label: Text('Lịch: ${widget.calendar.name}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.access_time),
                          title: const Text('Thời gian'),
                          subtitle: Text(_formatTimeRange(task)),
                        ),
                        if (!isSingle &&
                            task.repeatDays != null &&
                            task.repeatDays!.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.view_week_outlined),
                            title: const Text('Ngày trong tuần'),
                            subtitle: Text(_formatRepeatDays(task.repeatDays)),
                          ),
                        if (!isSingle && (task.repeatEnd != null))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_send_outlined),
                            title: const Text('Kết thúc lặp'),
                            subtitle: Text(
                              DateFormat(
                                'dd/MM/yyyy',
                              ).format(task.repeatEnd!.toLocal()),
                            ),
                          ),
                        if (tz != null && tz.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.public_outlined),
                            title: const Text('Múi giờ'),
                            subtitle: Text(tz),
                          ),
                        if (exceptionsCount > 0)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.rule_folder_outlined),
                            title: const Text('Ngoại lệ'),
                            subtitle: Text('$exceptionsCount mục'),
                          ),
                        if (task.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Nhãn',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: task.tags.map((t) {
                              final color = _hexToColor(t.color);
                              return Chip(
                                label: Text(
                                  t.name.isEmpty ? 'Nhãn #${t.id}' : t.name,
                                ),
                                backgroundColor: color.withOpacity(0.9),
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    top: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Đóng'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Show edit button only when user can edit
                      if (_canEditCurrentCalendar)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
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
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Chỉnh sửa'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.calendar.name),
        actions: [
          // Hide share button for guest
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is AuthGuestSuccess) {
                return const SizedBox.shrink();
              }
              return BlocBuilder<CalendarBloc, CalendarState>(
                builder: (context, state) {
                  final owned = _isOwnedId(widget.calendar.id);
                  if (!owned) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: _showShareDialog,
                    tooltip: 'Chia sẻ lịch',
                  );
                },
              );
            },
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          // Listener cho TaskListBloc
          BlocListener<TaskListBloc, TaskListState>(
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
          ),
          // Listener cho CalendarBloc (để hiển thị thông báo chia sẻ thành công/thất bại)
          BlocListener<CalendarBloc, CalendarState>(
            listener: (context, state) {
              if (state is CalendarOperationSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.green,
                  ),
                );
                // Refresh users and tasks right away
                _refreshSharingUsersIfOwned();
                _fetchSharingUsersDirect(); // NEW: force immediate UI update
                _ensureRemoteTasksForSharedCalendar();
              } else if (state is CalendarError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }

              // Update owned IDs cache when calendars load, then fetch users/tasks
              if (state is CalendarLoaded) {
                _ownedCalendarIds
                  ..clear()
                  ..addAll(state.calendars.map((c) => c.id));
                if (_isOwnedId(widget.calendar.id)) {
                  context.read<CalendarBloc>().add(
                    FetchSharingUsers(calendarId: widget.calendar.id),
                  );
                  _fetchSharingUsersDirect(); // ensure UI fills immediately
                } else {
                  // NEW: re-check permission for shared-with-me when calendars list changes
                  _ensureRemoteTasksForSharedCalendar();
                }
              }

              // Keep local cache in sync when detail (optional)
              if (state is CalendarDetailLoaded &&
                  state.calendar.id == widget.calendar.id) {
                setState(() {
                  _sharingUsersLocal = List<UserEntity>.from(
                    state.sharingUsers,
                  );
                });
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            _fetchTasks();
            _refreshSharingUsersIfOwned(); // NEW: ensure instant refresh on pull
            await _ensureRemoteTasksForSharedCalendar();
          },
          child: CustomScrollView(
            slivers: [
              // Phần 1: Danh sách người được chia sẻ (ẩn ở chế độ khách)
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  if (authState is AuthGuestSuccess) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Được chia sẻ với',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  );
                },
              ),
              // CHANGED: Sharing users list respects ownership & guest
              _buildSharingUsersList(),

              // Phần 2: Danh sách công việc
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Công việc trong lịch',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              _buildTasksList(),
            ],
          ),
        ),
      ),
      // show Add FAB only if user can edit this calendar
      floatingActionButton: _canEditCurrentCalendar
          ? FloatingActionButton(
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
            )
          : null,
    );
  }

  // Widget mới: Hiển thị danh sách người dùng
  Widget _buildSharingUsersList() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthGuestSuccess) {
          // Guest mode: hide sharing section entirely
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            final owned = _isOwnedId(widget.calendar.id);
            if (!owned) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Text(
                    'Lịch được chia sẻ với bạn. Chỉ chủ sở hữu mới xem và chỉnh sửa chia sẻ.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            if (_sharingUsersLocal.isEmpty) {
              // Empty list (not shared) is also valid UI; show a hint
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Lịch này chưa được chia sẻ với ai.'),
                ),
              );
            }

            return _buildUsersSliver(_sharingUsersLocal);
          },
        );
      },
    );
  }

  // NEW: small helper to avoid duplication when rendering users
  Widget _buildUsersSliver(List<UserEntity> users) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0] : user.email[0],
            ),
          ),
          title: Text(user.fullName.isNotEmpty ? user.fullName : user.email),
          subtitle: Text(user.email),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () {
              context.read<CalendarBloc>().add(
                UnshareCalendarRequested(
                  calendarId: widget.calendar.id,
                  userId: user.id,
                ),
              );
            },
            tooltip: 'Bỏ chia sẻ',
          ),
        );
      }, childCount: users.length),
    );
  }

  // Widget mới: Hiển thị danh sách công việc (đã tách ra)
  Widget _buildTasksList() {
    return BlocBuilder<TaskListBloc, TaskListState>(
      builder: (context, state) {
        if (state is TaskListLoaded) {
          if (state.tasks.isEmpty) {
            return const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Lịch này chưa có công việc nào.'),
                ),
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
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
                      tooltip: 'Xem chi tiết',
                      icon: const Icon(Icons.info_outline, color: Colors.grey),
                      onPressed: () => _showTaskDetailDialog(task),
                    ),
                    if (_canEditCurrentCalendar) ...[
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
                        onPressed: () => _showDeleteConfirmationDialog(task),
                      ),
                    ],
                  ],
                ),
                onTap: () => _showTaskDetailDialog(task),
              );
            }, childCount: state.tasks.length),
          );
        }
        if (state is TaskListError) {
          return SliverToBoxAdapter(child: Center(child: Text(state.message)));
        }
        return const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  // NEW: hex -> Color helper for tag chips
  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final s = hex.replaceFirst('#', '');
    final value =
        int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16) ?? 0xFF808080;
    return Color(value);
  }

  // NEW: format weekday int -> Vietnamese short
  String _weekdayShort(int day) {
    const map = {
      DateTime.monday: 'T2',
      DateTime.tuesday: 'T3',
      DateTime.wednesday: 'T4',
      DateTime.thursday: 'T5',
      DateTime.friday: 'T6',
      DateTime.saturday: 'T7',
      DateTime.sunday: 'CN',
    };
    return map[day] ?? day.toString();
  }

  // NEW: parse repeatDays JSON string -> VN text
  String _formatRepeatDays(String? jsonDays) {
    if (jsonDays == null || jsonDays.trim().isEmpty) return '';
    try {
      final list = (jsonDecode(jsonDays) as List).cast<int>();
      if (list.isEmpty) return '';
      return list.map(_weekdayShort).join(' • ');
    } catch (_) {
      return '';
    }
  }

  // NEW: build time range string for single or recurring tasks
  String _formatTimeRange(TaskEntity t) {
    if (t.repeatType == RepeatType.NONE) {
      final isAllDay = t.isAllDay == true;
      final start = (t.startTime ?? t.sortDate).toLocal();
      final end = (t.endTime ?? start).toLocal();
      if (isAllDay) {
        final s = DateFormat('dd/MM/yyyy').format(start);
        final e = DateFormat('dd/MM/yyyy').format(end);
        return (s == e) ? s : '$s → $e';
      } else {
        final s = DateFormat('HH:mm dd/MM/yyyy').format(start);
        final e = DateFormat('HH:mm dd/MM/yyyy').format(end);
        return '$s → $e';
      }
    } else {
      final base = (t.repeatStart ?? t.sortDate).toLocal();
      final startDay = DateFormat('dd/MM/yyyy').format(base);
      final endDay = t.repeatEnd != null
          ? DateFormat('dd/MM/yyyy').format(t.repeatEnd!.toLocal())
          : 'Không giới hạn';
      final todStart = t.repeatStartTime != null
          ? TimeOfDay(
              hour: t.repeatStartTime!.hour,
              minute: t.repeatStartTime!.minute,
            ).format(context)
          : null;
      final todEnd = t.repeatEndTime != null
          ? TimeOfDay(
              hour: t.repeatEndTime!.hour,
              minute: t.repeatEndTime!.minute,
            ).format(context)
          : null;
      final tod = (todStart != null && todEnd != null)
          ? '$todStart – $todEnd'
          : (todStart ?? '');
      return '$startDay → $endDay${tod.isNotEmpty ? ' • $tod' : ''}';
    }
  }

  // NEW: repeat summary string
  String _repeatSummary(TaskEntity t) {
    switch (t.repeatType) {
      case RepeatType.DAILY:
        return 'Hàng ngày${(t.repeatInterval != null && t.repeatInterval! > 1) ? ' mỗi ${t.repeatInterval} ngày' : ''}';
      case RepeatType.WEEKLY:
        final days = _formatRepeatDays(t.repeatDays);
        final iv = (t.repeatInterval != null && t.repeatInterval! > 1)
            ? ' mỗi ${t.repeatInterval} tuần'
            : '';
        return 'Hàng tuần$iv${days.isNotEmpty ? ' • $days' : ''}';
      case RepeatType.MONTHLY:
        final iv = (t.repeatInterval != null && t.repeatInterval! > 1)
            ? ' mỗi ${t.repeatInterval} tháng'
            : 'Hàng tháng';
        final dom = (t.repeatDayOfMonth != null)
            ? ' • Ngày ${t.repeatDayOfMonth}'
            : '';
        return '$iv$dom';
      case RepeatType.YEARLY:
        return 'Hàng năm';
      case RepeatType.NONE:
        return 'Một lần';
    }
  }
}

// Bạn cũng cần thêm Event `InitializeCalendarDetail` vào file `calendar_event.dart`
// class InitializeCalendarDetail extends CalendarEvent {
//   final CalendarEntity calendar;
//   const InitializeCalendarDetail({required this.calendar});
//   @override
//   List<Object?> get props => [calendar];
// }

// Và xử lý nó trong `calendar_bloc.dart`
// Future<void> _onInitializeCalendarDetail(InitializeCalendarDetail event, Emitter<CalendarState> emit) async {
//   emit(CalendarDetailLoaded(calendar: event.calendar, sharingUsers: []));
//   // Không cần gọi fetch user ở đây vì initState của trang đã gọi rồi
// }
// ... và thêm vào constructor của bloc:
// on<InitializeCalendarDetail>(_onInitializeCalendarDetail);
