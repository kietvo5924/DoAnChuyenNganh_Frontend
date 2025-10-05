import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:planmate_app/presentation/features/auth/pages/auth_wrapper.dart';
import 'package:planmate_app/presentation/features/calendar/bloc/calendar_bloc.dart';
import 'package:planmate_app/presentation/features/sync/bloc/sync_bloc.dart';
import 'package:planmate_app/presentation/features/tag/bloc/tag_bloc.dart';
import 'package:planmate_app/presentation/features/task/bloc/all_tasks_bloc.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_editor_bloc.dart';
import 'package:planmate_app/presentation/features/task/bloc/task_list_bloc.dart';
import 'core/services/navigation_service.dart';
import 'injection.dart';
import 'presentation/features/auth/bloc/auth_bloc.dart';
import 'presentation/features/user/bloc/user_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planmate_app/presentation/features/home/bloc/home_bloc.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  await getIt<NotificationService>().init();

  await initializeDateFormatting('vi_VN', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AuthBloc>()),
        BlocProvider(create: (_) => getIt<UserBloc>()),
        BlocProvider(create: (_) => getIt<CalendarBloc>()),
        BlocProvider(create: (_) => getIt<TagBloc>()),
        BlocProvider(create: (_) => getIt<TaskListBloc>()),
        BlocProvider(create: (_) => getIt<TaskEditorBloc>()),
        BlocProvider(create: (_) => getIt<AllTasksBloc>()),
        BlocProvider(create: (_) => getIt<SyncBloc>()),
        BlocProvider(create: (_) => getIt<HomeBloc>()),
      ],
      child: MaterialApp(
        title: 'MySchedule App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),

        navigatorKey: NavigationService.navigatorKey,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('vi', 'VN'), // Hỗ trợ tiếng Việt
          Locale('en', 'US'), // và tiếng Anh
        ],
        home: const AuthWrapper(),
      ),
    );
  }
}
