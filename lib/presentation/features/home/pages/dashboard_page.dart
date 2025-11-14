import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_state.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../../widgets/loading_indicator.dart';
import '../widgets/app_drawer.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: LoadingIndicator());
          }
          if (state is! HomeLoaded) {
            return const Center(
              child: Text('Không có dữ liệu bảng điều khiển'),
            );
          }

          final tasks = state.tasks;
          final calendars = state.calendars;
          final today = DateTime.now();
          final todayTasks = tasks.where((t) => _occursOn(t, today)).toList();

          final weekStart = today.subtract(
            Duration(days: (today.weekday + 6) % 7),
          );
          final weekDays = List.generate(
            7,
            (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
          );
          final tasksPerDay = weekDays
              .map((d) => tasks.where((t) => _occursOn(t, d)).length)
              .toList();

          final Map<int, int> byCalendar = {};
          for (final t in tasks.where((t) => _occursOn(t, today))) {
            byCalendar.update(t.calendarId, (v) => v + 1, ifAbsent: () => 1);
          }

          final Map<String, int> byTag = {};
          for (final t in todayTasks) {
            for (final tag in t.tags) {
              final key = tag.name.isEmpty ? '#${tag.id}' : tag.name;
              byTag.update(key, (v) => v + 1, ifAbsent: () => 1);
            }
          }
          final tagEntries = byTag.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topTags = tagEntries.take(6).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng quan hôm nay',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Công việc hôm nay',
                        value: '${todayTasks.length}',
                        icon: Icons.list_alt_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SummaryCard(
                        title: 'Bộ lịch',
                        value: '${calendars.length}',
                        icon: Icons.calendar_today_outlined,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Số công việc theo ngày (tuần này)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 != 0)
                                return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= weekDays.length)
                                return const SizedBox.shrink();
                              const labels = [
                                'T2',
                                'T3',
                                'T4',
                                'T5',
                                'T6',
                                'T7',
                                'CN',
                              ];
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      labels[idx],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tasksPerDay[idx].toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(7, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: tasksPerDay[i].toDouble(),
                              color: Colors.teal,
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DonutChart(
                      title: 'Phân bố theo lịch (hôm nay)',
                      sections: byCalendar.entries.map((e) {
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          title: e.value.toString(),
                          color: Colors
                              .primaries[e.key.abs() % Colors.primaries.length],
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _DonutChart(
                      title: 'Nhãn phổ biến (hôm nay)',
                      sections: topTags.map((e) {
                        final idx = topTags.indexOf(e);
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          title: e.value.toString(),
                          color:
                              Colors.primaries[idx % Colors.primaries.length],
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final String title;
  final List<PieChartSectionData> sections;
  const _DonutChart({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (sections.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('Không có dữ liệu')),
              )
            else
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 36,
                    sectionsSpace: 3,
                    borderData: FlBorderData(show: false),
                    pieTouchData: PieTouchData(enabled: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
