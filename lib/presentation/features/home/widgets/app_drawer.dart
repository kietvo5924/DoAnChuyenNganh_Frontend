import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/presentation/features/tag/bloc/tag_bloc.dart';
import 'package:planmate_app/presentation/features/tag/bloc/tag_event.dart';
import 'package:planmate_app/presentation/features/tag/pages/tag_management_page.dart';
import 'package:planmate_app/presentation/features/task/pages/all_tasks_page.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../calendar/pages/calendar_management_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import 'package:planmate_app/injection.dart';
import 'package:planmate_app/core/services/database_service.dart';
import 'package:planmate_app/core/network/network_info.dart';
import 'package:planmate_app/domain/sync/usecases/process_sync_queue.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/pages/auth_wrapper.dart';
import 'package:planmate_app/core/services/navigation_service.dart';
import 'package:planmate_app/data/auth/repositories/auth_repository_impl.dart';
import 'package:planmate_app/core/services/notification_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
                  'MySchedule App',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Trang chủ'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Quản lý Lịch'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CalendarManagementPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_list_outlined),
                title: const Text('Xem công việc theo Lịch'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllTasksPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('Quản lý Nhãn'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TagManagementPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Bảng điều khiển'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardPage()),
                  );
                },
              ),

              // Kiểm tra xem người dùng đã đăng nhập (vừa xong hoặc từ trước)
              if (state is AuthJustLoggedIn ||
                  state is AuthAlreadyLoggedIn) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Hồ sơ & Cài đặt'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Đăng xuất'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _handleSignOutFlow(context);
                  },
                ),
              ],

              // Nếu người dùng là khách (Guest)
              if (state is AuthGuestSuccess) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Đăng nhập'),
                  onTap: () async {
                    Navigator.pop(context);
                    // NEW: clear notifications set in guest mode before switching to login
                    await getIt<NotificationService>().cancelAllNotifications();
                    context.read<AuthBloc>().add(GuestWantsToLogin());
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

Future<void> _handleSignOutFlow(BuildContext context) async {
  print('[SignOutFlow] START');
  // NEW: cancel all local notifications on sign out (guest or logged)
  await getIt<NotificationService>().cancelAllNotifications();
  final nav = NavigationService.navigatorKey.currentState;
  final db = await getIt<DatabaseService>().database;

  final unsyncedTasks =
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE is_synced = 0'),
      ) ??
      0;
  final queueCount =
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sync_queue'),
      ) ??
      0;
  final totalPending = unsyncedTasks + queueCount;
  print(
    '[SignOutFlow] pending: unsyncedTasks=$unsyncedTasks queue=$queueCount',
  );

  final prefs = getIt<SharedPreferences>();

  Future<void> _purgeTagsOnly() async {
    // NEW
    try {
      await db.delete('task_tags_local');
      await db.delete('tags');
      print('[SignOutFlow] Purged tags tables manually');
    } catch (e) {
      print('[SignOutFlow] Purge tags failed: $e');
    }
  }

  Future<void> forceNavigateToLogin({required bool cleared}) async {
    // Bảo đảm token bị xóa
    await prefs.remove(kAuthTokenKey);
    // Nếu chưa clear toàn bộ DB thì vẫn chủ động xóa riêng Tag (tránh giữ lại cho account mới)
    if (!cleared) {
      // NEW
      await _purgeTagsOnly();
    }
    context.read<AuthBloc>().add(SignOutRequested());
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (r) => false,
      );
    }
    // NEW: reset TagBloc state so guest không thấy tag cũ
    if (context.mounted) {
      context.read<TagBloc>().add(ResetTags());
    }
    // (Có thể làm tương tự cho các bloc khác nếu cần)

    if (NavigationService.navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(
        NavigationService.navigatorKey.currentContext!,
      ).showSnackBar(
        SnackBar(
          content: Text(
            cleared ? 'Đã đăng xuất & xóa dữ liệu.' : 'Đã đăng xuất.',
          ),
        ),
      );
    }
  }

  Future<void> backfillUnsyncedTasksToQueue() async {
    // Thêm các task is_synced=0 nhưng chưa có UPSERT vào sync_queue
    print('[SignOutFlow] Backfill unsynced tasks -> queue');
    final rows = await db.rawQuery('''
      SELECT t.*
      FROM tasks t
      LEFT JOIN sync_queue q
        ON q.entity_type = 'TASK' AND q.entity_id = t.id AND q.action = 'UPSERT'
      WHERE t.is_synced = 0 AND q.id IS NULL
    ''');
    if (rows.isEmpty) {
      print('[SignOutFlow] Backfill: nothing to add');
      return;
    }
    for (final r in rows) {
      final tagRows = await db.rawQuery(
        'SELECT tag_id FROM task_tags_local WHERE task_id = ?',
        [r['id']],
      );
      final tagIds = tagRows.map((e) => e['tag_id']).toList();
      final repeatType = r['repeat_type'] as String;
      final isSingle = repeatType == 'NONE';
      final payload = jsonEncode({
        'calendarId': r['calendar_id'],
        'taskData': {
          'title': r['title'],
          'description': r['description'],
          'tagIds': tagIds,
          'repeatType': repeatType,
          // SINGLE fields
          'startTime': isSingle ? r['start_time'] : null,
          'endTime': isSingle ? r['end_time'] : null,
          'allDay': isSingle ? (r['is_all_day'] == 1) : null,
          // RECURRING fields
          'repeatStartTime': !isSingle ? r['repeat_start_time'] : null,
          'repeatEndTime': !isSingle ? r['repeat_end_time'] : null,
          'repeatInterval': !isSingle ? r['repeat_interval'] : null,
          'repeatDays': !isSingle ? r['repeat_days'] : null,
          'repeatDayOfMonth': !isSingle ? r['repeat_day_of_month'] : null,
          'repeatWeekOfMonth': !isSingle ? r['repeat_week_of_month'] : null,
          'repeatDayOfWeek': !isSingle ? r['repeat_day_of_week'] : null,
          'repeatStart': !isSingle ? r['repeat_start'] : null,
          'repeatEnd': !isSingle ? r['repeat_end'] : null,
          'exceptions': !isSingle ? r['exceptions'] : null,
        },
      });
      await db.insert('sync_queue', {
        'entity_type': 'TASK',
        'entity_id': r['id'],
        'action': 'UPSERT',
        'payload': payload,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    print(
      '[SignOutFlow] Backfill added ${rows.length} UPSERT actions to queue',
    );
  }

  if (totalPending == 0) {
    print('[SignOutFlow] No pending -> clear & logout');
    await getIt<DatabaseService>().clearAllTables();
    await forceNavigateToLogin(cleared: true);
    return;
  }

  final hasNet = await getIt<NetworkInfo>().isConnected;
  print('[SignOutFlow] hasNet=$hasNet');

  if (hasNet) {
    // Online: backfill rồi sync
    await backfillUnsyncedTasksToQueue();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    bool syncOk = true;
    try {
      final result = await getIt<ProcessSyncQueue>()();
      result.fold((l) {
        syncOk = false;
        print('[SignOutFlow] Queue sync FAILED');
      }, (_) => print('[SignOutFlow] Queue sync OK'));
    } catch (e) {
      syncOk = false;
      print('[SignOutFlow] Queue sync exception: $e');
    } finally {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }

    if (!syncOk) {
      final proceed =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Không đồng bộ hết'),
              content: Text(
                'Một số thay đổi chưa được đẩy lên server (Tasks:$unsyncedTasks, Queue:$queueCount). Vẫn đăng xuất và xóa dữ liệu?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Tiếp tục',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ) ??
          false;
      if (!proceed) {
        print('[SignOutFlow] User cancelled after sync failure');
        return;
      }
    }

    await getIt<DatabaseService>().clearAllTables();
    await forceNavigateToLogin(cleared: true);
  } else {
    // Offline: hỏi user
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Dữ liệu chưa đồng bộ'),
            content: Text(
              'Có $totalPending thay đổi chưa đồng bộ (Tasks:$unsyncedTasks, Queue:$queueCount).\nKhông có mạng. Xóa dữ liệu local và đăng xuất?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Xóa & Đăng xuất',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) {
      print('[SignOutFlow] User cancelled offline logout');
      return;
    }
    await getIt<DatabaseService>().clearAllTables();
    await forceNavigateToLogin(cleared: true);
  }
}
