// lib/injection.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:planmate_app/presentation/features/chatbot/bloc/chatbot_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import 'core/api/dio_interceptor.dart';
import 'core/network/network_info.dart';
import 'core/services/database_service.dart';
import 'core/services/notification_service.dart';

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
// Chatbot data
import 'data/chatbot/datasources/chatbot_remote_data_source.dart';
import 'data/chatbot/repositories/chatbot_repository_impl.dart';

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

// THÊM MỚI: Imports cho Use Cases chia sẻ
import 'domain/calendar/usecases/get_calendars_shared_with_me.dart';
import 'domain/calendar/usecases/get_users_sharing_calendar.dart';
import 'domain/calendar/usecases/share_calendar.dart';
import 'domain/calendar/usecases/unshare_calendar.dart';
import 'domain/calendar/usecases/report_calendar_abuse.dart';
// KẾT THÚC THÊM MỚI

import 'domain/sync/usecases/process_sync_queue.dart';
import 'domain/sync/usecases/merge_guest_data.dart';
import 'domain/sync/usecases/upload_guest_data.dart';
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
import 'domain/notification/usecases/reschedule_all_notifications.dart';
// Chatbot domain
import 'domain/chatbot/repositories/chatbot_repository.dart';
import 'domain/chatbot/usecases/send_chat_message.dart';

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

// NEW: connectivity listener guards
bool _connectivityListenerAttached = false;
bool _queueSyncRunning = false;

Future<void> configureDependencies() async {
  // == External ==
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton(() => sharedPreferences);
  getIt.registerLazySingleton(() {
    final dio = Dio();
    // NEW: avoid redirect loops and let client handle 302 as an error
    dio.options.followRedirects = false;
    dio.options.maxRedirects = 0;
    dio
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
      );
    return dio;
  });
  getIt.registerLazySingleton(() => Connectivity());
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService.instance);

  // == Core ==
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));
  getIt.registerLazySingleton<NotificationService>(
    () => NotificationService.instance,
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
  // Chatbot
  getIt.registerLazySingleton<ChatbotRemoteDataSource>(
    () => ChatbotRemoteDataSourceImpl(dio: getIt()),
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
      prefs: getIt(),
    ),
  );
  getIt.registerLazySingleton<TagRepository>(
    () => TagRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      networkInfo: getIt(),
      syncQueueLocalDataSource: getIt(),
      prefs: getIt(),
    ),
  );
  getIt.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      calendarRepository: getIt(),
      networkInfo: getIt(),
      syncQueueLocalDataSource: getIt(),
      prefs: getIt(),
      notificationService: getIt(),
    ),
  );
  // Chatbot
  getIt.registerLazySingleton<ChatbotRepository>(
    () => ChatbotRepositoryImpl(remoteDataSource: getIt()),
  );

  // == Use Cases ==
  // Auth
  getIt.registerLazySingleton(() => SignIn(getIt()));
  getIt.registerLazySingleton(() => SignUp(getIt()));
  getIt.registerLazySingleton(() => SignOut(getIt()));
  getIt.registerLazySingleton(() => CheckAuthStatus(getIt()));

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
  // THÊM MỚI: Đăng ký Use Cases cho chức năng chia sẻ
  getIt.registerLazySingleton(() => ShareCalendar(getIt()));
  getIt.registerLazySingleton(() => UnshareCalendar(getIt()));
  getIt.registerLazySingleton(() => GetUsersSharingCalendar(getIt()));
  getIt.registerLazySingleton(() => GetCalendarsSharedWithMe(getIt()));
  getIt.registerLazySingleton(() => ReportCalendarAbuse(getIt()));
  // KẾT THÚC THÊM MỚI

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
      taskLocalDataSource: getIt(),
      calendarRemoteDataSource: getIt(),
      calendarLocalDataSource: getIt(),
      tagRemoteDataSource: getIt(),
      tagLocalDataSource: getIt(),
    ),
  );
  getIt.registerLazySingleton(() => MergeGuestData(getIt()));
  getIt.registerLazySingleton(
    () => UploadGuestData(
      dbService: getIt(),
      queueDs: getIt(),
      processSyncQueue: getIt(),
    ),
  );
  getIt.registerLazySingleton(
    () => RescheduleAllNotifications(
      notificationService: getIt(),
      dbService: getIt(),
    ),
  );
  // Chatbot UseCases
  getIt.registerLazySingleton(() => SendChatMessage(getIt()));

  // == BLoCs ==
  getIt.registerFactory(
    () => AuthBloc(
      signInUseCase: getIt(),
      signUpUseCase: getIt(),
      signOutUseCase: getIt(),
      checkAuthStatus: getIt(),
    ),
  );
  getIt.registerFactory(
    () => UserBloc(
      getCachedUser: getIt(),
      syncUserProfile: getIt(),
      changePassword: getIt(),
    ),
  );

  // THAY ĐỔI: Cập nhật CalendarBloc để nhận các UseCase mới
  getIt.registerFactory(
    () => CalendarBloc(
      // Các dependencies cũ
      getLocalCalendars: getIt(),
      syncRemoteCalendars: getIt(),
      saveCalendar: getIt(),
      deleteCalendar: getIt(),
      setDefaultCalendar: getIt(),
      syncAllRemoteTasks: getIt(),
      // Các dependencies mới cho chức năng chia sẻ
      shareCalendar: getIt(),
      unshareCalendar: getIt(),
      getUsersSharingCalendar: getIt(),
      getCalendarsSharedWithMe: getIt(),
      reportCalendarAbuse: getIt(),
    ),
  );
  // KẾT THÚC THAY ĐỔI

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
  getIt.registerFactory(
    () => TaskEditorBloc(saveTask: getIt(), deleteTask: getIt()),
  );

  getIt.registerFactory(
    () => HomeBloc(
      getLocalCalendars: getIt(),
      getLocalTasksInCalendar: getIt(),
      getAllLocalTasks: getIt(),
    ),
  );
  getIt.registerFactory(
    () => AllTasksBloc(
      getLocalCalendars: getIt(),
      getAllLocalTasks: getIt(),
      getCalendarsSharedWithMe: getIt(),
    ),
  );
  getIt.registerFactory(
    () => SyncBloc(
      getCachedUser: getIt(),
      syncUserProfile: getIt(),
      syncRemoteCalendars: getIt(),
      syncRemoteTags: getIt(),
      syncAllRemoteTasks: getIt(),
      mergeGuestData: getIt(),
      processSyncQueue: getIt(),
      uploadGuestData: getIt(),
    ),
  );
  // Keep chatbot memory alive during app lifetime
  getIt.registerLazySingleton<ChatbotBloc>(
    () => ChatbotBloc(sendChatMessage: getIt()),
  );

  // Auto process sync when network is back
  if (!_connectivityListenerAttached) {
    _connectivityListenerAttached = true;
    final connectivity = getIt<Connectivity>();
    connectivity.onConnectivityChanged.listen((_) async {
      final connected = await getIt<NetworkInfo>().isConnected;
      if (!connected || _queueSyncRunning) return;

      _queueSyncRunning = true;
      try {
        await getIt<ProcessSyncQueue>()();
        await getIt<SyncRemoteCalendars>()();
        await getIt<SyncRemoteTags>()();
        await getIt<SyncAllRemoteTasks>()();
        await getIt<RescheduleAllNotifications>()();
      } catch (_) {
        // silent
      } finally {
        _queueSyncRunning = false;
      }
    });
  }
}
