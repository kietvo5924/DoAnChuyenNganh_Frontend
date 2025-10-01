import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:planmate_app/injection.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/tag/entities/tag_entity.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../calendar/bloc/calendar_bloc.dart';
import '../../calendar/bloc/calendar_event.dart';
import '../../calendar/bloc/calendar_state.dart';
import '../../tag/bloc/tag_bloc.dart';
import '../../tag/bloc/tag_event.dart';
import '../../tag/bloc/tag_state.dart';
import '../bloc/task_editor_bloc.dart';
import '../bloc/task_editor_event.dart';
import '../bloc/task_editor_state.dart';

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
    super.dispose();
  }

  // -- HÀM SAVE ĐÃ ĐƯỢC SỬA LỖI --
  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    // Tạo Event với đầy đủ các tham số được yêu cầu
    context.read<TaskEditorBloc>().add(
      SaveTaskSubmitted(
        taskId: _isEditing ? widget.taskToEdit!.id : null,
        calendarId: _selectedCalendar!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tagIds: _selectedTags.map((t) => t.id).toSet(),
        repeatType: RepeatType.values.byName(_selectedRepeatOption.name),
        // Dữ liệu cho task thường
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
        // Dữ liệu cho task lặp lại
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

  @override
  Widget build(BuildContext context) {
    _ensureCalendarsLoaded();
    return BlocProvider(
      create: (_) => getIt<TaskEditorBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Sửa công việc' : 'Tạo công việc mới'),
          actions: [
            BlocBuilder<TaskEditorBloc, TaskEditorState>(
              builder: (context, state) {
                if (state is TaskEditorLoading) {
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
              Navigator.of(context).pop(true);
            } else if (state is TaskEditorFailure) {
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
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'Tiêu đề không được trống' : null,
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
                SwitchListTile(
                  title: const Text('Cả ngày'),
                  value: _isAllDay,
                  onChanged: (value) => setState(() => _isAllDay = value),
                ),
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
                  // -- SỬA LỖI Ở ĐÂY: `onChanged` viết hoa chữ `C` --
                  onChanged: (value) =>
                      setState(() => _selectedRepeatOption = value!),
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
                      tileColor: Colors.blue.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.blue.shade100),
                      ),
                    ),
                  ),
                _buildTagSelector(),
              ],
            ),
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
          return DropdownButtonFormField<CalendarEntity>(
            value: _selectedCalendar,
            decoration: const InputDecoration(
              labelText: 'Lịch',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: state.calendars
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
          leading: CircularProgressIndicator(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text(
          'Nhãn',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _selectedTags.map((tag) {
            return Chip(
              label: Text(tag.name),
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
      ],
    );
  }

  void _showTagSelectionDialog() {
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
                        CircularProgressIndicator(),
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
