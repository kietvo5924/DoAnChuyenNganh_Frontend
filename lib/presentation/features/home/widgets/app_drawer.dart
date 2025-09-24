import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../calendar/pages/calendar_management_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';

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
              if (state is AuthSignInSuccess) ...[
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
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Đăng xuất'),
                  onTap: () => context.read<AuthBloc>().add(SignOutRequested()),
                ),
              ],
              if (state is AuthGuestSuccess) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Đăng nhập'),
                  onTap: () =>
                      context.read<AuthBloc>().add(GuestWantsToLogin()),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
