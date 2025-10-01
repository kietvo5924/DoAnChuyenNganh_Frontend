import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import 'core/api/dio_interceptor.dart';
import 'core/network/network_info.dart';
import 'core/services/database_service.dart';

// Data Layer
import 'data/auth/datasources/auth_remote_data_source.dart';
import 'data/auth/repositories/auth_repository_impl.dart';
import 'data/calendar/datasources/calendar_local_data_source.dart';
import 'data/calendar/datasources/calendar_remote_data_source.dart';
import 'data/calendar/repositories/calendar_repository_impl.dart';
import 'data/sync/datasources/sync_queue_local_data_source.dart';
import 'data/tag/datasources/tag_local_data_source.dart';
import 'data/tag/datasources/tag_remote_data_source.dart';
import 'data/tag/repositories/tag_repository_impl.dart';
import 'data/task/datasources/task_local_data_source.dart';
import 'data/task/datasources/task_remote_data_source.dart';
import 'data/task/repositories/task_repository_impl.dart';
import 'data/user/datasources/user_local_data_source.dart';
import 'data/user/datasources/user_remote_data_source.dart';
import 'data/user/repositories/user_repository_impl.dart';

// Domain Layer
import 'domain/auth/repositories/auth_repository.dart';
import 'domain/auth/usecases/check_auth_status.dart';
import 'domain/auth/usecases/sign_in.dart';
import 'domain/auth/usecases/sign_out.dart';
import 'domain/auth/usecases/sign_up.dart';
import 'domain/calendar/repositories/calendar_repository.dart';
import 'domain/calendar/usecases/delete_calendar.dart';
import 'domain/calendar/usecases/get_local_calendars.dart';
import 'domain/calendar/usecases/save_calendar.dart';
import 'domain/calendar/usecases/set_default_calendar.dart';
import 'domain/calendar/usecases/sync_remote_calendars.dart';
import 'domain/sync/usecases/process_sync_queue.dart';
import 'domain/sync/usecases/merge_guest_data.dart'; // NEW
import 'domain/sync/usecases/upload_guest_data.dart'; // NEW
import 'domain/tag/repositories/tag_repository.dart';
import 'domain/tag/usecases/delete_tag.dart';
import 'domain/tag/usecases/get_local_tags.dart';
import 'domain/tag/usecases/save_tag.dart';
import 'domain/tag/usecases/sync_remote_tags.dart';
import 'domain/task/repositories/task_repository.dart';
import 'domain/task/usecases/delete_task.dart';
import 'domain/task/usecases/get_all_local_tasks.dart';
import 'domain/task/usecases/get_local_tasks_in_calendar.dart';
import 'domain/task/usecases/save_task.dart';
import 'domain/task/usecases/sync_all_remote_tasks.dart';
import 'domain/user/repositories/user_repository.dart';
import 'domain/user/usecases/change_password.dart';
import 'domain/user/usecases/get_cached_user.dart';
import 'domain/user/usecases/sync_user_profile.dart';

// Presentation Layer (BLoCs)
import 'presentation/features/auth/bloc/auth_bloc.dart';
import 'presentation/features/calendar/bloc/calendar_bloc.dart';
import 'presentation/features/home/bloc/home_bloc.dart';
import 'presentation/features/sync/bloc/sync_bloc.dart';
import 'presentation/features/tag/bloc/tag_bloc.dart';
import 'presentation/features/task/bloc/all_tasks_bloc.dart';
import 'presentation/features/task/bloc/task_editor_bloc.dart';
import 'presentation/features/task/bloc/task_list_bloc.dart';
import 'presentation/features/user/bloc/user_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // == External ==
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton(() => sharedPreferences);
  getIt.registerLazySingleton(
    () => Dio()
      ..interceptors.add(
        DioInterceptor(sharedPreferences: getIt()),
      ) // Interceptor thêm token
      ..interceptors.add(
        LogInterceptor(
          // Interceptor để ghi log (hộp đen)
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
        ),
      ),
  );
  getIt.registerLazySingleton(() => Connectivity());
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService.instance);

  // == Core ==
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));

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
  getIt.registerLazySingleton<TagRemoteDataSource>(
    () => TagRemoteDataSourceImpl(dio: getIt()),
  );
  getIt.registerLazySingleton<TaskRemoteDataSource>(
    () => TaskRemoteDataSourceImpl(dio: getIt()),
  );
  getIt.registerLazySingleton<UserLocalDataSource>(
    () => UserLocalDataSourceImpl(dbService: getIt()),
  );
  getIt.registerLazySingleton<CalendarLocalDataSource>(
    () => CalendarLocalDataSourceImpl(dbService: getIt()),
  );
  getIt.registerLazySingleton<TagLocalDataSource>(
    () => TagLocalDataSourceImpl(dbService: getIt()),
  );
  getIt.registerLazySingleton<TaskLocalDataSource>(
    () => TaskLocalDataSourceImpl(dbService: getIt()),
  );
  getIt.registerLazySingleton<SyncQueueLocalDataSource>(
    () => SyncQueueLocalDataSourceImpl(dbService: getIt()),
  );

  // == Repositories ==
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      sharedPreferences: getIt(),
    ),
  );
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      networkInfo: getIt(),
    ),
  );
  getIt.registerLazySingleton<CalendarRepository>(
    () => CalendarRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      networkInfo: getIt(),
      syncQueueLocalDataSource: getIt(),
      prefs: getIt(), // NEW
    ),
  );
  getIt.registerLazySingleton<TagRepository>(
    () => TagRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      networkInfo: getIt(),
      syncQueueLocalDataSource: getIt(),
      prefs: getIt(), // NEW
    ),
  );
  getIt.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      calendarRepository: getIt(),
      networkInfo: getIt(),
      syncQueueLocalDataSource: getIt(),
      prefs: getIt(), // NEW
    ),
  );

  // == Use Cases ==
  // Auth
  getIt.registerLazySingleton(() => SignIn(getIt()));
  getIt.registerLazySingleton(() => SignUp(getIt()));
  getIt.registerLazySingleton(() => SignOut(getIt()));
  getIt.registerLazySingleton(
    () => CheckAuthStatus(getIt()),
  ); // <-- Bổ sung Use Case còn thiếu

  // User
  getIt.registerLazySingleton(() => GetCachedUser(getIt()));
  getIt.registerLazySingleton(() => SyncUserProfile(getIt()));
  getIt.registerLazySingleton(() => ChangePassword(getIt()));

  // Calendar
  getIt.registerLazySingleton(() => GetLocalCalendars(getIt()));
  getIt.registerLazySingleton(() => SyncRemoteCalendars(getIt()));
  getIt.registerLazySingleton(() => SaveCalendar(getIt()));
  getIt.registerLazySingleton(() => DeleteCalendar(getIt()));
  getIt.registerLazySingleton(() => SetDefaultCalendar(getIt()));

  // Tag
  getIt.registerLazySingleton(() => GetLocalTags(getIt()));
  getIt.registerLazySingleton(() => SyncRemoteTags(getIt()));
  getIt.registerLazySingleton(() => SaveTag(getIt()));
  getIt.registerLazySingleton(() => DeleteTag(getIt()));

  // Task
  getIt.registerLazySingleton(() => GetLocalTasksInCalendar(getIt()));
  getIt.registerLazySingleton(() => GetAllLocalTasks(getIt()));
  getIt.registerLazySingleton(() => SyncAllRemoteTasks(getIt()));
  getIt.registerLazySingleton(() => SaveTask(getIt()));
  getIt.registerLazySingleton(() => DeleteTask(getIt()));

  // Sync
  getIt.registerLazySingleton(
    () => ProcessSyncQueue(
      localDataSource: getIt(),
      taskRemoteDataSource: getIt(),
      calendarRemoteDataSource: getIt(),
      calendarLocalDataSource: getIt(),
      tagRemoteDataSource: getIt(),
      tagLocalDataSource: getIt(),
    ),
  );
  getIt.registerLazySingleton(
    () => MergeGuestData(getIt()),
  ); // NEW (missing before)
  getIt.registerLazySingleton(
    () => UploadGuestData(
      dbService: getIt(),
      queueDs: getIt(),
      processSyncQueue: getIt(),
    ),
  ); // NEW

  // == BLoCs ==
  getIt.registerFactory(
    () => AuthBloc(
      signInUseCase: getIt(),
      signUpUseCase: getIt(),
      signOutUseCase: getIt(),
      checkAuthStatus: getIt(), // <-- Bổ sung dependency
    ),
  );
  getIt.registerFactory(
    () => UserBloc(
      getCachedUser: getIt(),
      syncUserProfile: getIt(),
      changePassword: getIt(),
    ),
  );
  getIt.registerFactory(
    () => CalendarBloc(
      getLocalCalendars: getIt(),
      syncRemoteCalendars: getIt(),
      saveCalendar: getIt(),
      deleteCalendar: getIt(),
      setDefaultCalendar: getIt(),
      syncAllRemoteTasks: getIt(), // NEW
    ),
  );
  getIt.registerFactory(
    () => TagBloc(
      getLocalTags: getIt(),
      syncRemoteTags: getIt(),
      saveTag: getIt(),
      deleteTag: getIt(),
    ),
  );
  getIt.registerFactory(
    () => TaskListBloc(getLocalTasksInCalendar: getIt(), deleteTask: getIt()),
  );
  getIt.registerFactory(() => TaskEditorBloc(saveTask: getIt()));

  // Sửa lại tên Use Case cho khớp
  getIt.registerFactory(
    () =>
        HomeBloc(getLocalCalendars: getIt(), getLocalTasksInCalendar: getIt()),
  );
  getIt.registerFactory(
    () => AllTasksBloc(
      getLocalCalendars: getIt(),
      getAllLocalTasks: getIt(), // CHANGED: dùng GetAllLocalTasks
    ),
  );
  getIt.registerFactory(
    () => SyncBloc(
      getCachedUser: getIt(),
      syncUserProfile: getIt(),
      syncRemoteCalendars: getIt(),
      syncRemoteTags: getIt(),
      syncAllRemoteTasks: getIt(),
      mergeGuestData: getIt(), // now registered
      processSyncQueue: getIt(),
      uploadGuestData: getIt(),
    ),
  );
}
