import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/services/navigation_service.dart'; // <-- Import file mới
import 'injection.dart';
import 'presentation/features/auth/bloc/auth_bloc.dart';
import 'presentation/features/auth/pages/signin_page.dart';
import 'presentation/features/user/bloc/user_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
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
      ],
      child: MaterialApp(
        title: 'MySchedule App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),

        navigatorKey: NavigationService.navigatorKey,
        home: const SignInPage(),
      ),
    );
  }
}
