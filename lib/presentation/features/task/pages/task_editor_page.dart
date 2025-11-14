import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:planmate_app/injection.dart';
import 'package:planmate_app/presentation/features/tag/bloc/tag_state.dart';
import '../../../../core/services/database_service.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/tag/entities/tag_entity.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../calendar/bloc/calendar_bloc.dart';
import '../../calendar/bloc/calendar_event.dart';
import '../../calendar/bloc/calendar_state.dart';
import '../../tag/bloc/tag_bloc.dart';
import '../../tag/bloc/tag_event.dart';
import '../bloc/task_editor_bloc.dart';
import '../bloc/task_editor_event.dart';
import '../bloc/task_editor_state.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../../core/services/logger.dart';

enum RepeatOption { none, daily, weekly, monthly, yearly }

Color _hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class TaskEditorPage extends StatefulWidget {
  final CalendarEntity calendar;
  final TaskEntity? taskToEdit;

  const TaskEditorPage({super.key, required this.calendar, this.taskToEdit});

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _repeatIntervalController = TextEditingController(text: '1');
  int? _selectedDayOfMonth;

  bool get _isEditing => widget.taskToEdit != null;

  CalendarEntity? _selectedCalendar;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _endTime = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(hours: 1)),
  );
  bool _isAllDay = false;
  RepeatOption _selectedRepeatOption = RepeatOption.none;
  final Set<TagEntity> _selectedTags = {};
  DateTime? _repeatEndDate;
  final Map<int, bool> _weeklyRepeatDays = {
    DateTime.monday: false,
    DateTime.tuesday: false,
    DateTime.wednesday: false,
    DateTime.thursday: false,
    DateTime.friday: false,
    DateTime.saturday: false,
    DateTime.sunday: false,
  };

  bool _calendarFetchRequested = false;
  bool _submitting = false; // NEW
  bool _tagResolving = false; // NEW
  bool _tagResolvedOnce = false; // NEW
  bool _preDayNotify = false; // NEW: per-task toggle

  // NEW: Global notification preferences (applies to all tasks)
  // ignore: unused_field
  final _leadMinutesCtl = TextEditingController(text: '15');
  // ignore: unused_field
  bool _preDayEnabled = true;
  // ignore: unused_field
  TimeOfDay _preDayTime = const TimeOfDay(hour: 18, minute: 0);

  // ignore: unused_field
  static const _kLeadMinutesKey = 'notify_lead_minutes';
  // ignore: unused_field
  static const _kPreDayEnabledKey = 'notify_preday_enabled';
  // ignore: unused_field
  static const _kPreDayHourKey = 'notify_preday_hour';
  // ignore: unused_field
  static const _kPreDayMinuteKey = 'notify_preday_minute';

  @override
  void initState() {
    super.initState();
    _selectedCalendar = widget.calendar;
    _ensureCalendarsLoaded();
    if (_isEditing) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
      _selectedTags.addAll(task.tags);
      _scheduleResolveTags(task.id); // NEW (thay vì chỉ _resolveTagsLocally)

      _selectedRepeatOption = RepeatOption.values.firstWhere(
        (e) => e.name == task.repeatType.name.toLowerCase(),
        orElse: () => RepeatOption.none,
      );

      if (task.repeatType == RepeatType.NONE) {
        _startDate = task.startTime?.toLocal() ?? DateTime.now();
        _startTime = TimeOfDay.fromDateTime(
          task.startTime?.toLocal() ?? DateTime.now(),
        );
        _endDate =
            task.endTime?.toLocal() ?? _startDate.add(const Duration(hours: 1));
        _endTime = TimeOfDay.fromDateTime(
          task.endTime?.toLocal() ?? _startDate.add(const Duration(hours: 1)),
        );
        _isAllDay = task.isAllDay ?? false;
      } else {
        _startDate = task.repeatStart ?? DateTime.now();
        _startTime = task.repeatStartTime ?? TimeOfDay.now();
        _endTime =
            task.repeatEndTime ??
            TimeOfDay.fromDateTime(
              DateTime.now().add(const Duration(hours: 1)),
            );
        _endDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _endTime.hour,
          _endTime.minute,
        );
        _repeatIntervalController.text = (task.repeatInterval ?? 1).toString();
        _repeatEndDate = task.repeatEnd;
        _selectedDayOfMonth = task.repeatDayOfMonth;
        if (task.repeatDays != null) {
          try {
            List<dynamic> days = jsonDecode(task.repeatDays!);
            for (var day in days) {
              if (_weeklyRepeatDays.containsKey(day))
                _weeklyRepeatDays[day] = true;
            }
          } catch (e) {}
        }
      }
      _preDayNotify = task.preDayNotify == true; // NEW
    }
    // REMOVE: _loadNotifyPrefs();
  }

  void _scheduleResolveTags(int taskId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTagsFromMapping(taskId);
    });
  }

  Future<void> _loadTagsFromMapping(int taskId) async {
    if (_tagResolving || !_isEditing) return;
    _tagResolving = true;
    try {
      final db = await getIt<DatabaseService>().database;
      final rows = await db.rawQuery(
        '''
        SELECT T.id, T.name, T.color
        FROM task_tags_local TT
        INNER JOIN tags T ON T.id = TT.tag_id
        WHERE TT.task_id = ?
        ORDER BY T.id ASC
        ''',
        [taskId],
      );
      if (mounted) {
        if (rows.isNotEmpty) {
          final updated = rows
              .map(
                (r) => TagEntity(
                  id: r['id'] as int,
                  name: (r['name'] as String?) ?? '',
                  color: r['color'] as String?,
                ),
              )
              .toSet();
          setState(() {
            _selectedTags
              ..clear()
              ..addAll(updated);
          });
        } else {
          // NEW: không còn mapping -> xóa nhãn đã chọn (tránh hiển thị nhãn đã xóa)
          setState(() {
            _selectedTags.clear();
          });
        }
      }
    } catch (e) {
      Logger.w('[TaskEditor] Error load tag mapping: $e');
    } finally {
      _tagResolving = false;
      _tagResolvedOnce = true;
    }
  }

  // NEW: chỉ cố gắng lấy metadata tag từ local nếu tên trống (không gọi remote)
  // ignore: unused_element
  Future<void> _resolveTagsLocally() async {
    if (_selectedTags.isEmpty) return;
    final need = _selectedTags.any((t) => t.name.isEmpty);
    if (!need) return;
    try {
      final db = await getIt<DatabaseService>().database;
      final ids = _selectedTags.map((t) => t.id).toList();
      final rows = await db.query(
        'tags',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
      if (rows.isEmpty) return;
      final map = {
        for (final r in rows)
          r['id'] as int: TagEntity(
            id: r['id'] as int,
            name: (r['name'] as String?) ?? '',
            color: r['color'] as String?,
          ),
      };
      setState(() {
        final updated = <TagEntity>{};
        for (final t in _selectedTags) {
          updated.add(map[t.id] ?? t);
        }
        _selectedTags
          ..clear()
          ..addAll(updated);
      });
    } catch (_) {
      // silent
    }
  }

  void _ensureCalendarsLoaded() {
    if (_calendarFetchRequested) return;
    final calBloc = context.read<CalendarBloc>();
    if (calBloc.state is! CalendarLoaded) {
      calBloc.add(FetchCalendars());
      _calendarFetchRequested = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _repeatIntervalController.dispose();
    // REMOVE: _leadMinutesCtl.dispose();
    super.dispose();
  }

  // -- HÀM SAVE ĐÃ ĐƯỢC SỬA LỖI --
  void _saveTask() {
    if (_submitting) return; // NEW: chặn double tap
    if (!_formKey.currentState!.validate()) return;

    // NEW: map RepeatOption -> RepeatType (tránh lỗi byName case-sensitive)
    final repeatType = {
      RepeatOption.none: RepeatType.NONE,
      RepeatOption.daily: RepeatType.DAILY,
      RepeatOption.weekly: RepeatType.WEEKLY,
      RepeatOption.monthly: RepeatType.MONTHLY,
      RepeatOption.yearly: RepeatType.YEARLY,
    }[_selectedRepeatOption]!;

    setState(() => _submitting = true); // NEW
    // REMOVE: _persistNotifyPrefs();

    context.read<TaskEditorBloc>().add(
      SaveTaskSubmitted(
        taskId: _isEditing ? widget.taskToEdit!.id : null,
        calendarId: _selectedCalendar!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tagIds: _selectedTags.map((t) => t.id).toSet(),
        repeatType: repeatType,
        startTime: DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _startTime.hour,
          _startTime.minute,
        ),
        endTime: DateTime(
          _endDate.year,
          _endDate.month,
          _endDate.day,
          _endTime.hour,
          _endTime.minute,
        ),
        isAllDay: _isAllDay,
        repeatStartTime: _startTime,
        repeatEndTime: _endTime,
        repeatInterval: int.tryParse(_repeatIntervalController.text),
        repeatStart: _startDate,
        repeatEnd: _repeatEndDate,
        repeatDays: _selectedRepeatOption == RepeatOption.weekly
            ? jsonEncode(
                _weeklyRepeatDays.entries
                    .where((e) => e.value)
                    .map((e) => e.key)
                    .toList(),
              )
            : null,
        repeatDayOfMonth: _selectedDayOfMonth,
        preDayNotify: _preDayNotify, // NEW
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;
    if (_isAllDay) {
      setState(() {
        if (isStart)
          _startDate = date;
        else
          _endDate = date;
      });
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      if (isStart) {
        _startDate = date;
        _startTime = time;
      } else {
        _endDate = date;
        _endTime = time;
      }
    });
  }

  // NEW: time-only picker for recurring tasks
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      if (isStart) {
        _startTime = time;
        // keep _startDate as anchor date; no date change here
      } else {
        _endTime = time;
        // keep _endDate aligned hour/min if needed
        _endDate = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _endTime.hour,
          _endTime.minute,
        );
      }
    });
  }

  void _confirmDeleteTask() async {
    if (!_isEditing || widget.taskToEdit == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: const Text('Bạn có chắc muốn xóa công việc này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    context.read<TaskEditorBloc>().add(
      DeleteTaskSubmitted(
        taskId: widget.taskToEdit!.id,
        repeatType: widget.taskToEdit!.repeatType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureCalendarsLoaded();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa công việc' : 'Tạo công việc mới'),
        actions: [
          if (_isEditing)
            BlocBuilder<TaskEditorBloc, TaskEditorState>(
              builder: (context, state) {
                final busy = state is TaskEditorLoading || _submitting;
                return IconButton(
                  tooltip: 'Xóa',
                  onPressed: busy ? null : _confirmDeleteTask,
                  icon: const Icon(Icons.delete_outline),
                );
              },
            ),
          BlocBuilder<TaskEditorBloc, TaskEditorState>(
            builder: (context, state) {
              if (state is TaskEditorLoading || _submitting) {
                return const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                );
              }
              return IconButton(
                onPressed: _saveTask,
                icon: const Icon(Icons.save),
              );
            },
          ),
        ],
      ),
      body: BlocListener<TaskEditorBloc, TaskEditorState>(
        listener: (context, state) {
          if (state is TaskEditorSuccess) {
            setState(() => _submitting = false);
            Navigator.of(context).pop(true);
          } else if (state is TaskEditorFailure) {
            setState(() => _submitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppTextField(
                controller: _titleController,
                label: 'Tiêu đề',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Tiêu đề không được trống'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildCalendarSelector(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // CHANGED: hide "Cả ngày" when repeating
              if (_selectedRepeatOption == RepeatOption.none)
                SwitchListTile(
                  title: const Text('Cả ngày'),
                  value: _isAllDay,
                  onChanged: (value) => setState(() => _isAllDay = value),
                ),
              // CHANGED: start/end pickers depend on repeat option
              if (_selectedRepeatOption == RepeatOption.none) ...[
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(
                    _isAllDay
                        ? 'Bắt đầu: ${DateFormat('dd/MM/yyyy').format(_startDate)}'
                        : 'Bắt đầu: ${DateFormat('dd/MM/yyyy').format(_startDate)} ${_startTime.format(context)}',
                  ),
                  onTap: () => _selectDateTime(context, true),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time_filled),
                  title: Text(
                    _isAllDay
                        ? 'Kết thúc: ${DateFormat('dd/MM/yyyy').format(_endDate)}'
                        : 'Kết thúc: ${DateFormat('dd/MM/yyyy').format(_endDate)} ${_endTime.format(context)}',
                  ),
                  onTap: () => _selectDateTime(context, false),
                ),
              ] else ...[
                // Recurring: time-only (no date dialog)
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text('Giờ bắt đầu: ${_startTime.format(context)}'),
                  onTap: () => _selectTime(context, true),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_send),
                  title: Text('Giờ kết thúc: ${_endTime.format(context)}'),
                  onTap: () => _selectTime(context, false),
                ),
              ],
              const Divider(height: 32),
              DropdownButtonFormField<RepeatOption>(
                value: _selectedRepeatOption,
                decoration: const InputDecoration(
                  labelText: 'Lặp lại',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: RepeatOption.none,
                    child: Text('Không lặp lại'),
                  ),
                  DropdownMenuItem(
                    value: RepeatOption.daily,
                    child: Text('Hàng ngày'),
                  ),
                  DropdownMenuItem(
                    value: RepeatOption.weekly,
                    child: Text('Hàng tuần'),
                  ),
                  DropdownMenuItem(
                    value: RepeatOption.monthly,
                    child: Text('Hàng tháng'),
                  ),
                  DropdownMenuItem(
                    value: RepeatOption.yearly,
                    child: Text('Hàng năm'),
                  ),
                ],
                // CHANGED: force isAllDay=false when switching to repeating
                onChanged: (value) => setState(() {
                  _selectedRepeatOption = value!;
                  if (_selectedRepeatOption != RepeatOption.none) {
                    _isAllDay = false;
                  }
                }),
              ),
              if (_selectedRepeatOption != RepeatOption.none) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _repeatIntervalController,
                  decoration: InputDecoration(
                    labelText: 'Lặp lại mỗi',
                    border: const OutlineInputBorder(),
                    suffixText: _getRepeatIntervalUnit(_selectedRepeatOption),
                    hintText: 'Mặc định là 1',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (_selectedRepeatOption == RepeatOption.weekly)
                _buildWeeklySelector(),
              if (_selectedRepeatOption == RepeatOption.monthly)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: DropdownButtonFormField<int>(
                    value: _selectedDayOfMonth,
                    decoration: const InputDecoration(
                      labelText: 'Vào ngày trong tháng',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(31, (index) => index + 1)
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text(day.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedDayOfMonth = value),
                    validator: (value) =>
                        value == null ? 'Vui lòng chọn ngày' : null,
                  ),
                ),
              if (_selectedRepeatOption == RepeatOption.yearly)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.blue),
                    title: Text(
                      'Sẽ lặp lại vào ngày ${DateFormat('d MMMM', 'vi_VN').format(_startDate)} mỗi năm.',
                    ),
                    tileColor: Colors.blue.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blue.shade100),
                    ),
                  ),
                ),
              // Show pre-day notify toggle and tag selector only for personal/owned calendars
              if ((_selectedCalendar?.permissionLevel ?? '').isEmpty) ...[
                // Per-task pre-day toggle (always visible for personal calendars)
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Nhắc trước 1 ngày (18:00)'),
                  subtitle: const Text('Áp dụng riêng cho công việc này'),
                  value: _preDayNotify,
                  onChanged: (v) => setState(() => _preDayNotify = v),
                ),

                // Tag selector is only editable for personal calendars
                _buildTagSelector(),
              ] else ...[
                // For shared calendars (permissionLevel != null) hide tags and pre-day toggle
                const SizedBox.shrink(),
              ],
              // NEW: bottom spacer to avoid overlap with system home bar
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getRepeatIntervalUnit(RepeatOption option) {
    switch (option) {
      case RepeatOption.daily:
        return 'ngày';
      case RepeatOption.weekly:
        return 'tuần';
      case RepeatOption.monthly:
        return 'tháng';
      case RepeatOption.yearly:
        return 'năm';
      default:
        return '';
    }
  }

  Widget _buildCalendarSelector() {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        if (state is CalendarLoaded) {
          // NEW: loại bỏ trùng bằng id (map giữ phần tử cuối cùng)
          final Map<int, CalendarEntity> byId = {
            for (final c in state.calendars) c.id: c,
          };
          final uniqueCalendars = byId.values.toList();

          // IMPORTANT: ensure the calendar passed into this editor (widget.calendar)
          // is present in the selector list. For shared-with-me calendars the global
          // CalendarBloc list may not include them, which caused selection to fall
          // back to the user's default calendar. Insert it if missing.
          final containsCurrent = uniqueCalendars.any(
            (c) => c.id == widget.calendar.id,
          );
          if (!containsCurrent) {
            // insert at front so it's obvious to the user
            uniqueCalendars.insert(0, widget.calendar);
          }

          // NEW: đồng bộ lại _selectedCalendar để tham chiếu đúng instance trong danh sách hiện tại
          if (_selectedCalendar == null && uniqueCalendars.isNotEmpty) {
            // prefer the calendar passed into the page when creating a new task
            _selectedCalendar = uniqueCalendars.firstWhere(
              (c) => c.id == widget.calendar.id,
              orElse: () => uniqueCalendars.first,
            );
          } else if (_selectedCalendar != null) {
            final match = uniqueCalendars
                .where((c) => c.id == _selectedCalendar!.id)
                .toList();
            if (match.isEmpty) {
              // Nếu lịch đã biến mất -> chọn lịch đầu
              if (uniqueCalendars.isNotEmpty) {
                _selectedCalendar = uniqueCalendars.first;
              } else {
                _selectedCalendar = null;
              }
            } else {
              // Gán đúng instance trong list (tránh instance cũ gây trùng value)
              _selectedCalendar = match.first;
            }
          }

          return DropdownButtonFormField<CalendarEntity>(
            value: _selectedCalendar,
            decoration: const InputDecoration(
              labelText: 'Lịch',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: uniqueCalendars
                .map(
                  (cal) => DropdownMenuItem(value: cal, child: Text(cal.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedCalendar = value),
            validator: (value) =>
                value == null ? 'Vui lòng chọn một lịch' : null,
          );
        }
        return const ListTile(
          leading: SizedBox(width: 20, height: 20, child: LoadingIndicator()),
          title: Text('Đang tải danh sách lịch...'),
        );
      },
    );
  }

  Widget _buildWeeklySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lặp lại vào các ngày:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 4,
            children: _weeklyRepeatDays.keys.map((day) {
              return ChoiceChip(
                label: Text(_dayToVietnamese(day)),
                selectedColor: Theme.of(context).primaryColor,
                labelStyle: TextStyle(
                  color: _weeklyRepeatDays[day]! ? Colors.white : Colors.black,
                ),
                selected: _weeklyRepeatDays[day]!,
                // Sửa onChanged thành onSelected
                onSelected: (selected) {
                  setState(() => _weeklyRepeatDays[day] = selected);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _dayToVietnamese(int day) {
    const days = {
      DateTime.monday: 'T2',
      DateTime.tuesday: 'T3',
      DateTime.wednesday: 'T4',
      DateTime.thursday: 'T5',
      DateTime.friday: 'T6',
      DateTime.saturday: 'T7',
      DateTime.sunday: 'CN',
    };
    return days[day] ?? '';
  }

  Widget _buildTagSelector() {
    // SIMPLIFIED: không BlocListener tự reload nữa
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text(
          'Nhãn',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (_isEditing && !_tagResolvedOnce && _selectedTags.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Đang tải nhãn từ dữ liệu cục bộ...',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _selectedTags.map((tag) {
            return Chip(
              label: Text(tag.name.isEmpty ? '(chưa có tên)' : tag.name),
              backgroundColor: _hexToColor(tag.color ?? '#808080'),
              labelStyle: const TextStyle(color: Colors.white),
              onDeleted: () => setState(() => _selectedTags.remove(tag)),
              deleteIconColor: Colors.white70,
            );
          }).toList(),
        ),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Thêm nhãn'),
          onPressed: _showTagSelectionDialog,
        ),
        if (_isEditing)
          TextButton(
            onPressed: () {
              if (widget.taskToEdit != null) {
                _loadTagsFromMapping(widget.taskToEdit!.id);
              }
            },
            child: const Text('Tải lại nhãn (debug)'),
          ),
      ],
    );
  }

  void _showTagSelectionDialog() {
    // CHỈ fetch khi user mở dialog chọn nhãn
    context.read<TagBloc>().add(FetchTags());
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            return BlocBuilder<TagBloc, TagState>(
              builder: (context, state) {
                if (state is TagLoaded) {
                  return AlertDialog(
                    title: const Text('Chọn nhãn'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.tags.length,
                        itemBuilder: (ctx, index) {
                          final tag = state.tags[index];
                          final isSelected = _selectedTags.any(
                            (t) => t.id == tag.id,
                          );
                          return CheckboxListTile(
                            title: Text(tag.name),
                            value: isSelected,
                            onChanged: (selected) {
                              dialogSetState(() {
                                setState(() {
                                  if (selected ?? false) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.removeWhere(
                                      (t) => t.id == tag.id,
                                    );
                                  }
                                });
                              });
                            },
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                }
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
                        SizedBox(width: 20),
                        Text("Đang tải nhãn..."),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
