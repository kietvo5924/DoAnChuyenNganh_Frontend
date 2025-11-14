import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/logger.dart';
import '../../../../domain/auth/usecases/check_auth_status.dart';
import '../../../../domain/auth/usecases/sign_in.dart';
import '../../../../domain/auth/usecases/sign_out.dart';
import '../../../../domain/auth/usecases/sign_up.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignIn _signInUseCase;
  final SignUp _signUpUseCase;
  final SignOut _signOutUseCase;
  final CheckAuthStatus _checkAuthStatus;

  AuthBloc({
    required SignIn signInUseCase,
    required SignUp signUpUseCase,
    required SignOut signOutUseCase,
    required CheckAuthStatus checkAuthStatus,
  }) : _signInUseCase = signInUseCase,
       _signUpUseCase = signUpUseCase,
       _signOutUseCase = signOutUseCase,
       _checkAuthStatus = checkAuthStatus,
       super(AuthInitial()) {
    on<AuthCheckStatusRequested>((event, emit) async {
      final result = await _checkAuthStatus();
      result.fold((failure) => emit(AuthSignedOut()), (isLoggedIn) {
        if (isLoggedIn)
          emit(AuthAlreadyLoggedIn());
        else
          emit(AuthSignedOut());
      });
    });

    on<SignInRequested>((event, emit) async {
      emit(AuthLoading());
      Logger.i('AUTH: SignInRequested email=${event.email}');
      final result = await _signInUseCase(
        email: event.email,
        password: event.password,
      );
      result.fold(
        (failure) {
          Logger.w('AUTH: SignIn FAILED -> $failure');
          emit(const AuthFailure(message: 'Email hoặc mật khẩu không đúng.'));
        },
        (_) {
          Logger.i('AUTH: SignIn SUCCESS -> emitting AuthJustLoggedIn');
          emit(AuthJustLoggedIn());
        },
      );
    });

    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      final result = await _signUpUseCase(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
      );
      result.fold(
        (failure) => emit(
          const AuthFailure(
            message: 'Đăng ký thất bại, email có thể đã tồn tại.',
          ),
        ),
        (message) => emit(AuthSignUpSuccess(message: message)),
      );
    });

    on<SignOutRequested>((event, emit) async {
      await _signOutUseCase();
      emit(AuthSignedOut());
    });

    on<GuestWantsToLogin>((event, emit) {
      emit(AuthSignedOut());
    });

    on<SignInAsGuestRequested>((event, emit) {
      emit(AuthGuestSuccess());
    });
  }
}
