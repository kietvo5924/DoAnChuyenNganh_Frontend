import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../pages/dashboard_page.dart';
import '../pages/profile_page.dart';

// Giải thích: AppDrawer chứa các menu điều hướng chính.
// Nó sử dụng callback `onPageSelected` để báo cho HomePage biết cần hiển thị trang nào.
class AppDrawer extends StatelessWidget {
  final Function(String, Widget) onPageSelected;
  const AppDrawer({super.key, required this.onPageSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'PlanMate App',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Trang chủ'),
            onTap: () {
              onPageSelected('Trang chủ', Container());
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Bảng điều khiển'),
            onTap: () {
              onPageSelected('Bảng điều khiển', const DashboardPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Hồ sơ & Cài đặt'),
            onTap: () {
              onPageSelected('Hồ sơ & Cài đặt', const ProfilePage());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () {
              context.read<AuthBloc>().add(SignOutRequested());
            },
          ),
        ],
      ),
    );
  }
}
