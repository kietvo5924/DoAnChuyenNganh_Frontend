import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/presentation/features/user/bloc/user_bloc.dart';
import 'package:planmate_app/presentation/features/user/bloc/user_event.dart';
import 'package:planmate_app/presentation/features/user/bloc/user_state.dart';
import '../widgets/change_password_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Chỉ lấy từ cache, KHÔNG force remote ở đây nữa
    context.read<UserBloc>().add(FetchCachedUserProfile());
    // context.read<UserBloc>().add(SyncRemoteUserProfile()); // removed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ & Cài đặt'),
        actions: [
          // Nút để làm mới thủ công
          IconButton(
            icon: const Icon(Icons.refresh),
            // Bấm mới gọi remote (force)
            onPressed: () =>
                context.read<UserBloc>().add(SyncRemoteUserProfile()),
          ),
        ],
      ),
      body: BlocListener<UserBloc, UserState>(
        listener: (context, state) {
          if (state is UserOperationSuccess) {
            if (Navigator.canPop(context))
              Navigator.pop(context); // Đóng dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is UserError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<UserBloc, UserState>(
          builder: (context, state) {
            if (state is UserLoaded) {
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text(
                    'Thông tin tài khoản',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Họ và tên'),
                    subtitle: Text(state.profile.fullName),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(state.profile.email),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Bảo mật',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ChangePasswordDialog(),
                      );
                    },
                  ),
                ],
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
