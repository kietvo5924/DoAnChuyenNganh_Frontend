import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/pages/home_page.dart';
import '../../sync/pages/sync_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'signin_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AuthCheckStatusRequested());
  }

  @override
  Widget build(BuildContext context) {
    // Dùng BlocBuilder để quyết định hiển thị trang nào dựa trên trạng thái
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Vừa mới đăng nhập -> Cần đồng bộ
        if (state is AuthJustLoggedIn) {
          return const SyncPage();
        }
        // Đã đăng nhập sẵn hoặc là khách -> Vào thẳng trang chủ
        if (state is AuthAlreadyLoggedIn || state is AuthGuestSuccess) {
          return const HomePage();
        }
        // Chưa đăng nhập, đã đăng xuất, hoặc có lỗi -> Về trang đăng nhập
        if (state is AuthSignedOut ||
            state is AuthFailure ||
            state is AuthInitial) {
          return const SignInPage();
        }
        // Các trạng thái khác (ví dụ: AuthLoading) -> Hiển thị màn hình chờ
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
