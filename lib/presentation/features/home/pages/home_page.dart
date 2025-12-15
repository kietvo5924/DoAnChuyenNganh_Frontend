import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // keep: needed for timeout on stream await
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:planmate_app/injection.dart';
import '../widgets/app_drawer.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../../../domain/task/usecases/get_task_occurrence_completions.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';
// NEW: tag bloc for filtering
import '../../tag/bloc/tag_bloc.dart';
import '../../tag/bloc/tag_state.dart';
import '../../tag/bloc/tag_event.dart';
// NEW: calendar bloc to include shared calendars in filter
import '../../calendar/bloc/calendar_bloc.dart';
import '../../calendar/bloc/calendar_event.dart';
import '../../calendar/bloc/calendar_state.dart';
// Auth bloc to trigger reload after login
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
// Chatbot page
import '../../chatbot/pages/chatbot_page.dart';
// Sync bloc để đồng bộ lại dữ liệu (bao gồm công việc AI vừa tạo)
import '../../sync/bloc/sync_bloc.dart';
import '../../sync/bloc/sync_event.dart';
import '../../sync/bloc/sync_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // Read-only completion status for selected day on Home
  final Set<String> _completedKeys = {};
  String? _loadedCompletionsKey; // `${yyyy-MM-dd}|${sortedCalendarIds}`
  bool _loadingCompletions = false;

  // NEW: filter selections
  int? _selectedCalendarId;
  int? _selectedTagId;
  bool _calendarCollapsed = false; // Collapse the calendar grid, not filters
  bool _postLoginReloadDone = false; // đảm bảo chỉ reload 1 lần sau đăng nhập

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

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toLocal());

  String _completionKey({
    required String taskType,
    required int taskId,
    required String dateKey,
  }) {
    return '${taskType.toUpperCase()}|$taskId|$dateKey';
  }

  void _maybeLoadCompletionsForSelection({
    required DateTime day,
    required Set<int> calendarIds,
  }) {
    final dateKey = _dateKey(day);
    final ids = calendarIds.toList()..sort();
    final desiredKey = '$dateKey|${ids.join(",")}';
    if (_loadingCompletions) return;
    if (_loadedCompletionsKey == desiredKey) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadCompletionsForDay(
        day: day,
        calendarIds: calendarIds,
        desiredKey: desiredKey,
      );
    });
  }

  Future<void> _loadCompletionsForDay({
    required DateTime day,
    required Set<int> calendarIds,
    required String desiredKey,
  }) async {
    if (calendarIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _completedKeys.clear();
        _loadedCompletionsKey = desiredKey;
        _loadingCompletions = false;
      });
      return;
    }

    setState(() {
      _loadingCompletions = true;
      _completedKeys.clear();
    });

    final keys = <String>{};
    final getCompletions = getIt<GetTaskOccurrenceCompletions>();
    for (final calId in calendarIds) {
      final res = await getCompletions(calendarId: calId, from: day, to: day);
      res.fold((_) {}, (list) {
        for (final c in list) {
          if (c.completed != true) continue;
          keys.add(
            '${c.taskType.toUpperCase()}|${c.taskId}|${c.occurrenceDate}',
          );
        }
      });
    }

    if (!mounted) return;
    setState(() {
      _completedKeys
        ..clear()
        ..addAll(keys);
      _loadedCompletionsKey = desiredKey;
      _loadingCompletions = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    // Thực hiện tuần tự: tải lịch chia sẻ (kèm task) rồi mới fetch HomeData
    // tránh tình trạng phải ấn lại trang chủ mới thấy task lịch chia sẻ.
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Trigger fetch lịch chia sẻ (không chờ) để tăng tốc hiển thị ban đầu
    final calBloc = context.read<CalendarBloc>();
    calBloc.add(FetchSharedWithMeCalendars());
    // 2. Fetch HomeData ngay lập tức với dữ liệu hiện có (sẽ refetch lại khi shared load listener kích hoạt)
    if (mounted) {
      context.read<HomeBloc>().add(FetchHomeData());
    }
    // 3. Fetch tags nếu cần (song song không cần chờ)
    final tagBloc = context.read<TagBloc>();
    if (tagBloc.state is TagInitial) {
      tagBloc.add(const FetchTags());
    }
    // 4. Khi lịch chia sẻ load xong listener bên dưới sẽ refetch nên không chờ ở đây.
  }

  // NEW: filter bar widget (instance method so we can use setState)
  Widget _buildFilterBar(HomeLoaded state) {
    // Merge & deduplicate calendars (allow duplicates silently, we only show unique items)
    final List<CalendarEntity> merged = [
      ...state.calendars,
      if (context.watch<CalendarBloc>().state is CalendarSharedWithMeLoaded)
        ...((context.watch<CalendarBloc>().state as CalendarSharedWithMeLoaded)
            .calendars),
    ];
    final Map<int, CalendarEntity> byId = {for (final c in merged) c.id: c};
    final List<CalendarEntity> allCalendars = byId.values.toList();

    // Ensure selected id exists after dedup; do NOT reset on duplicates anymore
    int? effectiveSelected = _selectedCalendarId;
    if (effectiveSelected != null) {
      final exists = byId.containsKey(effectiveSelected);
      if (!exists) {
        effectiveSelected = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedCalendarId != null) {
            setState(() => _selectedCalendarId = null);
          }
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: effectiveSelected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Lịch',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tất cả lịch'),
                ),
                ...allCalendars.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Row(
                      children: [
                        if (c.permissionLevel != null)
                          const Icon(Icons.folder_shared_outlined, size: 16),
                        if (c.permissionLevel != null) const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            c.name, // removed '(chia sẻ)' suffix per request
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedCalendarId = val),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BlocBuilder<TagBloc, TagState>(
              builder: (context, tagState) {
                if (tagState is TagLoaded) {
                  return DropdownButtonFormField<int?>(
                    value: _selectedTagId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nhãn',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả nhãn'),
                      ),
                      ...tagState.tags.map(
                        (tg) => DropdownMenuItem<int?>(
                          value: tg.id,
                          child: Text(
                            tg.name.isEmpty ? 'Nhãn #${tg.id}' : tg.name,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedTagId = val),
                  );
                }
                if (tagState is TagError) return const SizedBox();
                return const SizedBox(
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Xóa bộ lọc',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () {
              if (_selectedCalendarId != null || _selectedTagId != null) {
                setState(() {
                  _selectedCalendarId = null;
                  _selectedTagId = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              // Logic: Kiểm tra xem có phải là User thật (đã đăng nhập) hay không
              // Dựa trên file auth_state.dart của bạn:
              final bool isLoggedIn =
                  state is AuthJustLoggedIn || state is AuthAlreadyLoggedIn;

              if (isLoggedIn) {
                // Nếu đã đăng nhập -> Hiển thị nút Chatbot
                return IconButton(
                  tooltip: 'Trợ lý AI',
                  icon: const Icon(Icons.smart_toy_outlined),
                  onPressed: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ChatbotPage()))
                        .then((_) async {
                          if (!mounted) return;
                          // Logic đồng bộ cũ của bạn giữ nguyên
                          final syncState = context.read<SyncBloc>().state;
                          if (syncState is! SyncInProgress) {
                            context.read<SyncBloc>().add(
                              const StartInitialSync(),
                            );
                          }
                        });
                  },
                );
              }

              // Nếu là Khách (AuthGuestSuccess) hoặc trạng thái khác -> Ẩn nút (trả về widget rỗng)
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: MultiBlocListener(
        listeners: [
          // Sau khi login: chỉ fetch calendars chia sẻ trước, rồi Home sẽ refetch khi shared load xong
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (prev, curr) =>
                curr is AuthJustLoggedIn || curr is AuthAlreadyLoggedIn,
            listener: (context, authState) async {
              final calBloc = context.read<CalendarBloc>();
              calBloc.add(FetchSharedWithMeCalendars());
              // Chờ shared calendars hoặc timeout 2s
              try {
                await calBloc.stream
                    .firstWhere((s) => s is CalendarSharedWithMeLoaded)
                    .timeout(const Duration(seconds: 2));
              } catch (_) {
                // timeout hoặc lỗi: vẫn tiếp tục
              }
              if (!mounted) return;
              if (!_postLoginReloadDone) {
                context.read<HomeBloc>().add(FetchHomeData());
                _postLoginReloadDone = true; // đánh dấu đã reload 1 lần
              }
              // Nếu đang chọn một calendar đã biến mất sau login thì reset
              if (_selectedCalendarId != null) {
                final homeState = context.read<HomeBloc>().state;
                if (homeState is HomeLoaded) {
                  final hasId = homeState.calendars.any(
                    (c) => c.id == _selectedCalendarId,
                  );
                  if (!hasId) setState(() => _selectedCalendarId = null);
                }
              }
            },
          ),
          // Khi lịch chia sẻ (và tasks của chúng) đã được cache: refetch HomeData để hiển thị ngay
          BlocListener<CalendarBloc, CalendarState>(
            listenWhen: (prev, curr) => curr is CalendarSharedWithMeLoaded,
            listener: (context, calState) {
              // Tránh refetch thừa nếu Home đang loading
              final homeBloc = context.read<HomeBloc>();
              // Chỉ refetch nếu chưa từng reload sau đăng nhập (lần đầu) hoặc không phải do login
              if (!_postLoginReloadDone && homeBloc.state is! HomeLoading) {
                homeBloc.add(FetchHomeData());
                _postLoginReloadDone = true;
              }
            },
          ),
          // Khi đồng bộ hoàn tất, reload Home để hiển thị công việc mới (bao gồm AI tạo)
          BlocListener<SyncBloc, SyncState>(
            listenWhen: (prev, curr) => curr is SyncSuccess,
            listener: (context, syncState) {
              if (!mounted) return;
              context.read<HomeBloc>().add(FetchHomeData());
            },
          ),
        ],
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const Center(child: LoadingIndicator());
            }
            if (state is HomeLoaded) {
              // Merge calendar names (my + shared) for lookup
              final List<CalendarEntity> merged = List.from(state.calendars);
              final calState = context.watch<CalendarBloc>().state;
              if (calState is CalendarSharedWithMeLoaded) {
                for (final sc in calState.calendars) {
                  if (!merged.any((c) => c.id == sc.id)) merged.add(sc);
                }
              }
              final nameMap = {for (final c in merged) c.id: c.name};

              // Apply filters
              List<TaskEntity> filtered = state.tasks;
              if (_selectedCalendarId != null) {
                filtered = filtered
                    .where((t) => t.calendarId == _selectedCalendarId!)
                    .toList();
              }
              if (_selectedTagId != null) {
                filtered = filtered
                    .where((t) => t.tags.any((tg) => tg.id == _selectedTagId!))
                    .toList();
              }

              List<TaskEntity> getEventsForDay(DateTime day) =>
                  filtered.where((t) => _occursOn(t, day)).toList();

              final selectedTasks = _selectedDay != null
                  ? getEventsForDay(_selectedDay!)
                  : const <TaskEntity>[];
              final displayTasks = selectedTasks;

              final selectedDayLocal = (_selectedDay ?? _focusedDay).toLocal();
              final calendarIdsForDay = displayTasks
                  .map((t) => t.calendarId)
                  .toSet();
              _maybeLoadCompletionsForSelection(
                day: selectedDayLocal,
                calendarIds: calendarIdsForDay,
              );

              return Column(
                children: [
                  _buildFilterBar(state),
                  if (_calendarCollapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDay ?? _focusedDay)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Mở lịch',
                            icon: const Icon(Icons.unfold_more),
                            onPressed: () =>
                                setState(() => _calendarCollapsed = false),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4, top: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Thu gọn lịch',
                              icon: const Icon(Icons.unfold_less),
                              onPressed: () =>
                                  setState(() => _calendarCollapsed = true),
                            ),
                          ),
                        ),
                        TableCalendar<TaskEntity>(
                          locale: 'vi_VN',
                          focusedDay: _focusedDay,
                          firstDay: DateTime.utc(2000, 1, 1),
                          lastDay: DateTime.utc(2100, 12, 31),
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          eventLoader: getEventsForDay,
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (events.isEmpty)
                                return const SizedBox.shrink();
                              const int maxDots = 6;
                              final int shown = events.length > maxDots
                                  ? maxDots
                                  : events.length;
                              final dots = List.generate(shown, (i) {
                                final t = events[i];
                                Color color;
                                if (t.tags.isNotEmpty) {
                                  color = _hexToColor(
                                    t.tags.first.color,
                                  ).withValues(alpha: 0.95);
                                } else {
                                  color = Theme.of(context).colorScheme.primary;
                                }
                                return Container(
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
                                );
                              });
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
                          calendarStyle: const CalendarStyle(
                            markersMaxCount: 6,
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                        ),
                      ],
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
                            padding: EdgeInsets.fromLTRB(
                              12,
                              8,
                              12,
                              MediaQuery.of(context).padding.bottom + 88,
                            ),
                            itemCount: displayTasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final t = displayTasks[i];
                              final safeCalName =
                                  nameMap[t.calendarId] ??
                                  '(Lịch #${t.calendarId})';
                              final taskType = (t.repeatType == RepeatType.NONE)
                                  ? 'SINGLE'
                                  : 'RECURRING';
                              final key = _completionKey(
                                taskType: taskType,
                                taskId: t.id,
                                dateKey: _dateKey(selectedDayLocal),
                              );
                              final isCompleted = _completedKeys.contains(key);
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
                                  subtitle: Text(
                                    'Lịch: $safeCalName • ${isCompleted ? 'Đã hoàn thành' : 'Chưa hoàn thành'}',
                                  ),
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
