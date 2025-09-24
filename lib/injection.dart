import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import 'core/api/dio_interceptor.dart';
import 'core/services/navigation_service.dart';

// Data Layer
import 'data/auth/datasources/auth_remote_data_source.dart';
import 'data/auth/repositories/auth_repository_impl.dart';
import 'data/calendar/datasources/calendar_remote_data_source.dart';
import 'data/calendar/repositories/calendar_repository_impl.dart';
import 'data/user/datasources/user_remote_data_source.dart';
import 'data/user/repositories/user_repository_impl.dart';

// Domain Layer
import 'domain/auth/repositories/auth_repository.dart';
import 'domain/auth/usecases/sign_in.dart';
import 'domain/auth/usecases/sign_out.dart';
import 'domain/auth/usecases/sign_up.dart';
import 'domain/calendar/repositories/calendar_repository.dart';
import 'domain/calendar/usecases/create_calendar.dart';
import 'domain/calendar/usecases/delete_calendar.dart';
import 'domain/calendar/usecases/get_all_calendars.dart';
import 'domain/calendar/usecases/set_default_calendar.dart';
import 'domain/calendar/usecases/update_calendar.dart';
import 'domain/user/repositories/user_repository.dart';
import 'domain/user/usecases/change_password.dart';
import 'domain/user/usecases/get_user_profile.dart';

// Presentation Layer (BLoCs)
import 'presentation/features/auth/bloc/auth_bloc.dart';
import 'presentation/features/calendar/bloc/calendar_bloc.dart';
import 'presentation/features/user/bloc/user_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // == External ==
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton(() => sharedPreferences);
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
  getIt.registerLazySingleton<CalendarRemoteDataSource>(
    () => CalendarRemoteDataSourceImpl(dio: getIt()),
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
  getIt.registerLazySingleton<CalendarRepository>(
    () => CalendarRepositoryImpl(remoteDataSource: getIt()),
  );

  // == Use Cases ==
  // Auth
  getIt.registerLazySingleton(() => SignIn(getIt()));
  getIt.registerLazySingleton(() => SignUp(getIt()));
  getIt.registerLazySingleton(() => SignOut(getIt()));
  // User
  getIt.registerLazySingleton(() => GetUserProfile(getIt()));
  getIt.registerLazySingleton(() => ChangePassword(getIt()));
  // Calendar
  getIt.registerLazySingleton(() => GetAllCalendars(getIt()));
  getIt.registerLazySingleton(() => CreateCalendar(getIt()));
  getIt.registerLazySingleton(() => UpdateCalendar(getIt()));
  getIt.registerLazySingleton(() => DeleteCalendar(getIt()));
  getIt.registerLazySingleton(() => SetDefaultCalendar(getIt()));

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
  getIt.registerFactory(
    () => CalendarBloc(
      getAllCalendars: getIt(),
      createCalendar: getIt(),
      updateCalendar: getIt(),
      deleteCalendar: getIt(),
      setDefaultCalendar: getIt(),
    ),
  );
}
