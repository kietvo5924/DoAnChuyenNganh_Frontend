import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import 'core/api/dio_interceptor.dart';

// Data Layer
import 'data/auth/datasources/auth_remote_data_source.dart';
import 'data/auth/repositories/auth_repository_impl.dart';
import 'data/user/datasources/user_remote_data_source.dart';
import 'data/user/repositories/user_repository_impl.dart';

// Domain Layer
import 'domain/auth/repositories/auth_repository.dart';
import 'domain/auth/usecases/sign_in.dart';
import 'domain/auth/usecases/sign_up.dart';
import 'domain/auth/usecases/sign_out.dart';
import 'domain/user/repositories/user_repository.dart';
import 'domain/user/usecases/change_password.dart';
import 'domain/user/usecases/get_user_profile.dart';

// Presentation Layer (BLoCs)
import 'presentation/features/auth/bloc/auth_bloc.dart';
import 'presentation/features/user/bloc/user_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // == External ==
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton(() => sharedPreferences);
  // Cấu hình Dio để sử dụng Interceptor, tự động thêm token vào header
  getIt.registerLazySingleton(
    () => Dio()..interceptors.add(DioInterceptor(sharedPreferences: getIt())),
  );

  // == Data Sources ==
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: getIt()),
  );
  getIt.registerLazySingleton<UserRemoteDataSource>(
    () => UserRemoteDataSourceImpl(dio: getIt()),
  );

  // == Repositories ==
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      sharedPreferences: getIt(),
    ),
  );
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(remoteDataSource: getIt()),
  );

  // == Use Cases ==
  getIt.registerLazySingleton(() => SignIn(getIt()));
  getIt.registerLazySingleton(() => SignUp(getIt()));
  getIt.registerLazySingleton(
    () => SignOut(getIt()),
  ); // Đảm bảo đã đăng ký SignOut
  getIt.registerLazySingleton(() => GetUserProfile(getIt()));
  getIt.registerLazySingleton(() => ChangePassword(getIt()));

  // == BLoCs ==
  getIt.registerFactory(
    () => AuthBloc(
      signInUseCase: getIt(),
      signUpUseCase: getIt(),
      signOutUseCase: getIt(),
    ),
  );

  getIt.registerFactory(
    () => UserBloc(
      getUserProfileUseCase: getIt(),
      changePasswordUseCase: getIt(),
    ),
  );
}
