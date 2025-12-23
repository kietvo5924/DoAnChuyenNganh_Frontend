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
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/empty_state.dart';
import '../../../../core/services/logger.dart';
import '../../tag/bloc/tag_bloc.dart';
import '../../tag/bloc/tag_state.dart';
import '../../tag/bloc/tag_event.dart';
import '../../../../domain/tag/entities/tag_entity.dart';
import 'dart:convert';
import '../../home/bloc/home_bloc.dart';
import '../../home/bloc/home_event.dart';

class AllTasksPage extends StatefulWidget {
  const AllTasksPage({super.key});

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  DateTime? _filterDate;
  int? _selectedTagId;

  @override
  void initState() {
    super.initState();
    _fetchAllTasks();
    // NEW: đảm bảo có lịch sẵn cho dialog chọn
    final calBloc = context.read<CalendarBloc>();
    if (calBloc.state is! CalendarLoaded) {
      calBloc.add(FetchCalendars());
    }
    // NEW: nạp danh sách nhãn cho bộ lọc
    context.read<TagBloc>().add(const FetchTags());
  }

  void _fetchAllTasks() {
    // Nay dùng GetAllLocalTasks (đã sửa trong AllTasksBloc) -> tránh mất task sau khi sửa calendar
    context.read<AllTasksBloc>().add(FetchAllTasks(date: _filterDate));
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
                          if (created == true) {
                            _fetchAllTasks();
                            if (mounted) {
                              pageContext.read<HomeBloc>().add(FetchHomeData());
                            }
                          }
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
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: LoadingIndicator(),
                      ),
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

  // Helper: kiểm tra task có diễn ra vào một ngày d không
  bool _occursOn(TaskEntity t, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (t.repeatType == RepeatType.NONE) {
      final start = (t.startTime ?? t.sortDate).toLocal();
      final end = (t.endTime ?? start).toLocal();
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      return !d.isBefore(s) && !d.isAfter(e);
    }
    final start = (t.repeatStart ?? t.sortDate).toLocal();
    final end = (t.repeatEnd ?? DateTime(2100, 12, 31)).toLocal();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    if (d.isBefore(s) || d.isAfter(e)) return false;
    final interval = (t.repeatInterval ?? 1).clamp(1, 1000);
    switch (t.repeatType) {
      case RepeatType.DAILY:
        final daysDiff = d.difference(s).inDays;
        return daysDiff % interval == 0;
      case RepeatType.WEEKLY:
        final days = _parseRepeatDays(t.repeatDays);
        if (!days.contains(d.weekday)) return false;
        final weeksDiff = d.difference(s).inDays ~/ 7;
        return weeksDiff % interval == 0;
      case RepeatType.MONTHLY:
        final dom = t.repeatDayOfMonth ?? s.day;
        if (d.day != dom) return false;
        final monthsDiff = (d.year - s.year) * 12 + (d.month - s.month);
        return monthsDiff % interval == 0;
      case RepeatType.YEARLY:
        if (d.month != s.month || d.day != s.day) return false;
        final yearsDiff = d.year - s.year;
        return yearsDiff % interval == 0;
      case RepeatType.NONE:
        return false;
    }
  }

  List<int> _parseRepeatDays(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return const [];
    try {
      return (json.decode(jsonStr) as List).cast<int>();
    } catch (_) {
      return const [];
    }
  }

  String _buildStartDisplay(TaskEntity task) {
    // CHANGED: and add debug
    if (task.repeatType == RepeatType.NONE) {
      final d = (task.startTime ?? task.sortDate).toLocal();
      final txt = (task.isAllDay == true)
          ? DateFormat('dd/MM/yyyy').format(d)
          : DateFormat('HH:mm dd/MM/yyyy').format(d);
      Logger.d(
        '[AllTasks] task=${task.id} single isAllDay=${task.isAllDay} start="$txt"',
      );
      return txt;
    } else {
      final base = (task.repeatStart ?? task.sortDate).toLocal();
      final tod = task.repeatStartTime;
      if (tod == null) {
        final txt = DateFormat('dd/MM/yyyy').format(base);
        Logger.d(
          '[AllTasks] task=${task.id} recurring tod=null display="$txt"',
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
      Logger.d(
        '[AllTasks] task=${task.id} recurring tod=${tod.hour}:${tod.minute} display="$txt"',
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
              return const Center(
                child: EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Chưa có công việc',
                  message: 'Tạo công việc mới bằng nút + phía dưới.',
                ),
              );
            }
            // Áp dụng bộ lọc theo ngày và nhãn
            final filtered = state.tasks.where((twc) {
              final t = twc.task;
              final matchDate = _filterDate == null
                  ? true
                  : _occursOn(t, _filterDate!);
              final matchTag = _selectedTagId == null
                  ? true
                  : t.tags.any((tg) => tg.id == _selectedTagId);
              return matchDate && matchTag;
            }).toList();

            return Column(
              children: [
                // Khu vực bộ lọc
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      // Chọn ngày
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _filterDate == null
                                ? 'Lọc theo ngày'
                                : DateFormat(
                                    'EEEE, dd/MM/yyyy',
                                    'vi_VN',
                                  ).format(_filterDate!),
                          ),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _filterDate ?? now,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100, 12, 31),
                              locale: const Locale('vi', 'VN'),
                            );
                            if (picked != null) {
                              setState(() => _filterDate = picked);
                              _fetchAllTasks();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa ngày',
                        onPressed: _filterDate == null
                            ? null
                            : () {
                                setState(() => _filterDate = null);
                                _fetchAllTasks();
                              },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: BlocBuilder<TagBloc, TagState>(
                          builder: (context, tagState) {
                            List<TagEntity> tags = const [];
                            if (tagState is TagLoaded) tags = tagState.tags;
                            return DropdownButtonFormField<int?>(
                              value: _selectedTagId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Lọc theo nhãn',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Tất cả nhãn'),
                                ),
                                ...tags.map(
                                  (t) => DropdownMenuItem<int?>(
                                    value: t.id,
                                    child: Text(
                                      t.name.isEmpty ? 'Nhãn #${t.id}' : t.name,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedTagId = val);
                              },
                            );
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa nhãn',
                        onPressed: _selectedTagId == null
                            ? null
                            : () => setState(() => _selectedTagId = null),
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _fetchAllTasks(),
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final taskWithCalendar = filtered[index];
                        final task = taskWithCalendar.task;
                        final calendar = taskWithCalendar.calendar;

                        final day = (_filterDate ?? DateTime.now()).toLocal();
                        final occurs = _occursOn(task, day);
                        final canEdit = calendar.permissionLevel != 'VIEW_ONLY';
                        final taskType = (task.repeatType == RepeatType.NONE)
                            ? 'SINGLE'
                            : 'RECURRING';
                        final isCompleted = state.isCompleted(
                          taskType: taskType,
                          taskId: task.id,
                        );

                        // CHANGED: build display text correctly
                        final startStr = _buildStartDisplay(task);

                        return ListTile(
                          key: ValueKey(task.id),
                          leading: Checkbox(
                            value: occurs ? isCompleted : false,
                            onChanged: (!canEdit || !occurs)
                                ? null
                                : (v) {
                                    final checked = v ?? false;
                                    context.read<AllTasksBloc>().add(
                                      ToggleAllTasksCompletionForDate(
                                        calendarId: calendar.id,
                                        taskId: task.id,
                                        repeatType: task.repeatType,
                                        date: day,
                                        completed: checked,
                                      ),
                                    );
                                  },
                          ),
                          title: Text(task.title),
                          subtitle: Text(
                            'Lịch: ${calendar.name} • Bắt đầu: $startStr • ${!occurs ? 'Không diễn ra ngày này' : (isCompleted ? 'Đã hoàn thành' : 'Chưa hoàn thành')}',
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
                              if (updated == true) {
                                _fetchAllTasks();
                                if (mounted) {
                                  context.read<HomeBloc>().add(FetchHomeData());
                                }
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }
          if (state is AllTasksError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: LoadingIndicator());
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
