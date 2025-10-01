import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../home/pages/home_page.dart';
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
    context.read<SyncBloc>().add(StartInitialSync());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<SyncBloc, SyncState>(
        listener: (context, state) {
          if (state is SyncSuccess) {
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
