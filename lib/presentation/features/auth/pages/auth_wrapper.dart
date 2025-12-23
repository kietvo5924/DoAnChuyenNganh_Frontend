import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/data/auth/repositories/auth_repository_impl.dart';
import 'package:planmate_app/domain/user/usecases/sync_user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/pages/home_page.dart';
import '../../sync/pages/sync_page.dart';
import '../../../../core/network/network_info.dart';
import '../../../../injection.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'signin_page.dart';
import '../../../widgets/loading_indicator.dart';

import 'dart:async';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Timer? _sessionGuardTimer;
  bool _pingRunning = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AuthCheckStatusRequested());
  }

  @override
  void dispose() {
    _sessionGuardTimer?.cancel();
    super.dispose();
  }

  void _startSessionGuardIfNeeded() {
    if (_sessionGuardTimer != null) return;
    _sessionGuardTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (_pingRunning) return;
      _pingRunning = true;
      try {
        final prefs = getIt<SharedPreferences>();
        final token = prefs.getString(kAuthTokenKey);
        if (token == null || token.isEmpty) {
          _sessionGuardTimer?.cancel();
          _sessionGuardTimer = null;
          return;
        }

        final connected = await getIt<NetworkInfo>().isConnected;
        if (!connected) return;

        // Lightweight ping: if server says 401 (locked/expired), DioInterceptor will forceLogout.
        await getIt<SyncUserProfile>()(forceRemote: true);
      } finally {
        _pingRunning = false;
      }
    });
  }

  void _stopSessionGuard() {
    _sessionGuardTimer?.cancel();
    _sessionGuardTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAlreadyLoggedIn || state is AuthJustLoggedIn) {
          _startSessionGuardIfNeeded();
        }
        if (state is AuthSignedOut ||
            state is AuthFailure ||
            state is AuthInitial) {
          _stopSessionGuard();
        }
      },
      builder: (context, state) {
        // Vừa mới đăng nhập -> Cần đồng bộ
        if (state is AuthJustLoggedIn) {
          return const SyncPage();
        }
        // Đã đăng nhập sẵn hoặc là khách -> Vào thẳng trang chủ
        if (state is AuthAlreadyLoggedIn || state is AuthGuestSuccess) {
          return const HomePage();
        }
        // Chưa đăng nhập, đã đăng xuất, đăng ký thành công (về trang đăng nhập), hoặc có lỗi -> Về trang đăng nhập
        if (state is AuthSignedOut ||
            state is AuthFailure ||
            state is AuthInitial ||
            state is AuthSignUpSuccess) {
          return const SignInPage();
        }
        // Các trạng thái khác (ví dụ: AuthLoading) -> Hiển thị màn hình chờ
        return const Scaffold(body: Center(child: LoadingIndicator()));
      },
    );
  }
}
