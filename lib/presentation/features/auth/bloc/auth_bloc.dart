import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/core/services/navigation_service.dart';
import 'package:planmate_app/presentation/features/auth/pages/signin_page.dart';
import 'package:planmate_app/presentation/features/home/pages/home_page.dart';
import '../../../../domain/auth/usecases/sign_in.dart';
import '../../../../domain/auth/usecases/sign_up.dart';
import '../../../../domain/auth/usecases/sign_out.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignIn _signInUseCase;
  final SignUp _signUpUseCase;
  final SignOut _signOutUseCase;

  AuthBloc({
    required SignIn signInUseCase,
    required SignUp signUpUseCase,
    required SignOut signOutUseCase,
  }) : _signInUseCase = signInUseCase,
       _signUpUseCase = signUpUseCase,
       _signOutUseCase = signOutUseCase,
       super(AuthInitial()) {
    // Trình xử lý sự kiện đăng nhập
    on<SignInRequested>((event, emit) async {
      emit(AuthLoading());
      final result = await _signInUseCase(
        email: event.email,
        password: event.password,
      );
      result.fold(
        (failure) =>
            emit(AuthFailure(message: 'Email hoặc mật khẩu không đúng.')),
        (_) {
          emit(AuthSignInSuccess());
          NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        },
      );
    });

    // Trình xử lý sự kiện đăng ký
    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      final result = await _signUpUseCase(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
      );
      result.fold(
        (failure) => emit(
          AuthFailure(message: 'Đăng ký thất bại, email có thể đã tồn tại.'),
        ),
        (message) => emit(AuthSignUpSuccess(message: message)),
      );
    });

    // Trình xử lý sự kiện đăng xuất
    on<SignOutRequested>((event, emit) async {
      await _signOutUseCase();

      emit(AuthSignOutSuccess());

      NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    });

    // Khi người dùng khách muốn đăng nhập
    on<GuestWantsToLogin>((event, emit) {
      NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    });

    on<SignInAsGuestRequested>((event, emit) {
      emit(AuthGuestSuccess());
      NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    });
  }
}
