import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/presentation/features/tag/bloc/tag_event.dart';
import 'package:sqflite/sqflite.dart';
import 'package:planmate_app/core/services/notification_service.dart';
import '../../../../core/services/database_service.dart';
import '../../../../injection.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../home/pages/home_page.dart';
import '../../tag/bloc/tag_bloc.dart';
import '../bloc/sync_bloc.dart';
import '../bloc/sync_event.dart';
import '../bloc/sync_state.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  @override
  void initState() {
    super.initState();
    _startSmartSync();
  }

  Future<void> _startSmartSync() async {
    final db = await getIt<DatabaseService>().database;
    final int negCalendars =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM calendars WHERE id < 0 OR is_synced = 0',
          ),
        ) ??
        0;
    final int negTags =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM tags WHERE id < 0 OR is_synced = 0',
          ),
        ) ??
        0;
    final int negTasks =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM tasks WHERE id < 0 OR is_synced = 0',
          ),
        ) ??
        0;
    final int queue =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_queue'),
        ) ??
        0;
    final bool needMerge = (negCalendars + negTags + negTasks + queue) > 0;

    // NEW: ensure no stale guest notifications remain; sync will reschedule
    await getIt<NotificationService>().cancelAllNotifications();

    if (mounted) {
      context.read<SyncBloc>().add(StartInitialSync(mergeGuest: needMerge));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<SyncBloc, SyncState>(
        listener: (context, state) {
          if (state is SyncSuccess) {
            // NEW: nạp lại tags ngay sau khi sync xong
            if (mounted) {
              // forceRemote để chắc chắn gọi remote khi token đã có
              context.read<TagBloc>().add(const FetchTags(forceRemote: true));
            }
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          } else if (state is SyncFailure) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Đồng bộ thất bại'),
                content: Text(state.message),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.read<SyncBloc>().add(
                        StartInitialSync(),
                      ); // thử lại
                    },
                    child: const Text('Thử lại'),
                  ),
                  TextButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(SignOutRequested());
                      Navigator.of(context).pop();
                    },
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            );
          }
        },
        child: BlocBuilder<SyncBloc, SyncState>(
          builder: (context, state) {
            double progress = 0.0;
            String message = 'Đang chuẩn bị...';

            if (state is SyncInProgress) {
              progress = state.progress;
              message = state.message;
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_download_outlined,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Đang đồng bộ dữ liệu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    const Text(
                      'Vui lòng không tắt ứng dụng...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
