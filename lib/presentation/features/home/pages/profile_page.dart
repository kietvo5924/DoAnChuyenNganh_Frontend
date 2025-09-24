import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../user/bloc/user_bloc.dart';
import '../../user/bloc/user_event.dart';
import '../../user/bloc/user_state.dart';
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
    context.read<UserBloc>().add(FetchUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ & Cài đặt')),
      body: BlocListener<UserBloc, UserState>(
        listener: (context, state) {
          if (state is UserOperationSuccess) {
            if (Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is UserOperationFailure) {
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
            if (state is UserProfileLoaded) {
              return _buildProfileView(context, state);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildProfileView(BuildContext context, UserProfileLoaded state) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Thông tin tài khoản',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const Text('Email'),
          subtitle: Text(state.profile.email),
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Vai trò'),
          subtitle: Text(state.profile.role),
        ),
        ListTile(
          leading: const Icon(Icons.date_range_outlined),
          title: const Text('Ngày tham gia'),
          subtitle: Text(state.profile.createdAt),
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
}
