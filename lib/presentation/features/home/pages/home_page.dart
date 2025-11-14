import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../widgets/app_drawer.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // Check if a task occurs on a specific calendar day.
  bool _occursOn(TaskEntity t, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    // Single task
    if (t.repeatType == RepeatType.NONE) {
      final start = (t.startTime ?? t.sortDate).toLocal();
      final end = (t.endTime ?? start).toLocal();
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      return !d.isBefore(s) && !d.isAfter(e);
    }

    // Recurring task
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
        // Parse repeatDays (JSON array of weekday ints)
        final List<int> days = _parseRepeatDays(t.repeatDays);
        if (!days.contains(d.weekday)) return false;
        final weeksDiff = d.difference(s).inDays ~/ 7;
        return weeksDiff % interval == 0;
      case RepeatType.MONTHLY:
        final int dom = t.repeatDayOfMonth ?? s.day;
        if (d.day != dom) return false;
        final monthsDiff = (d.year - s.year) * 12 + (d.month - s.month);
        return monthsDiff % interval == 0;
      case RepeatType.YEARLY:
        if (d.month != s.month || d.day != s.day) return false;
        final yearsDiff = d.year - s.year;
        return yearsDiff % interval == 0;
      case RepeatType.NONE:
        return false; // already handled
    }
  }

  List<int> _parseRepeatDays(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return const [];
    try {
      final raw = (json.decode(jsonStr) as List).cast<int>();
      return raw;
    } catch (_) {
      return const [];
    }
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    // Sẽ fallback sang toàn bộ tasks nếu mất calendar default
    context.read<HomeBloc>().add(FetchHomeData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: LoadingIndicator());
          }
          if (state is HomeLoaded) {
            List<TaskEntity> getEventsForDay(DateTime day) {
              return state.tasks.where((t) => _occursOn(t, day)).toList();
            }

            final selectedTasks = _selectedDay != null
                ? getEventsForDay(_selectedDay!)
                : const <TaskEntity>[];
            final displayTasks =
                selectedTasks; // chỉ hiển thị trong ngày đã chọn

            return Column(
              children: [
                TableCalendar<TaskEntity>(
                  locale: 'vi_VN',
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: getEventsForDay,
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();

                      // Build up to maxDots colored dots, one per task
                      const int maxDots = 6;
                      final int total = events.length;
                      final int shown = total > maxDots ? maxDots : total;

                      List<Widget> dots = [];
                      for (int i = 0; i < shown; i++) {
                        final t = events[i];
                        Color color;
                        if (t.tags.isNotEmpty) {
                          final firstTag = t.tags.first;
                          color = _hexToColor(
                            firstTag.color,
                          ).withValues(alpha: 0.95);
                        } else {
                          color = Theme.of(context).colorScheme.primary;
                        }
                        dots.add(
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 1,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 2,
                            runSpacing: 2,
                            children: dots,
                          ),
                        ),
                      );
                    },
                  ),
                  calendarStyle: const CalendarStyle(markersMaxCount: 6),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const Divider(height: 1),
                SectionHeader(
                  title: _selectedDay != null
                      ? 'Công việc ngày ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                      : 'Công việc trong ngày',
                  trailing: Text(
                    '(${displayTasks.length})',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: displayTasks.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Không có công việc',
                            message:
                                'Hãy thêm công việc mới hoặc chọn ngày khác.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: displayTasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final t = displayTasks[i];
                            final idx = state.calendars.indexWhere(
                              (c) => c.id == t.calendarId,
                            );
                            final safeCalName = idx >= 0
                                ? state.calendars[idx].name
                                : '(Lịch #${t.calendarId})';
                            return Card(
                              child: ListTile(
                                key: ValueKey(t.id),
                                leading: Icon(
                                  t.repeatType == RepeatType.NONE
                                      ? Icons.event
                                      : Icons.repeat,
                                  color: Colors.blue,
                                ),
                                title: Text(t.title),
                                subtitle: Text('Lịch: $safeCalName'),
                                onTap: () =>
                                    _showTaskDetailDialog(t, safeCalName),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          if (state is HomeError) {
            return Center(child: Text(state.message));
          }
          return const Center(
            child: Text(
              'Nội dung trang chủ (Lịch chính và các công việc) sẽ được hiển thị ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}

// Chi tiết công việc dạng bottom sheet (giống trang lịch chia sẻ)
extension _HomeTaskDetail on _HomePageState {
  void _showTaskDetailDialog(TaskEntity task, String calendarName) {
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
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      isSingle ? Icons.event_outlined : Icons.repeat,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(calendarName),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.35),
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
                                backgroundColor: Colors.orangeAccent.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            Chip(
                              avatar: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                              label: Text('Lịch: $calendarName'),
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
                            children: task.tags.map((tg) {
                              final color = _hexToColor(tg.color);
                              return Chip(
                                label: Text(
                                  tg.name.isEmpty ? 'Nhãn #${tg.id}' : tg.name,
                                ),
                                backgroundColor: color.withValues(alpha: 0.9),
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
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: const Text('Đã hiểu'),
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

  // Helpers reused from calendar detail view
  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final s = hex.replaceFirst('#', '');
    final value =
        int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16) ?? 0xFF808080;
    return Color(value);
  }

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
