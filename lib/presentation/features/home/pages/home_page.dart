import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/app_drawer.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../../domain/task/entities/task_entity.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Sẽ fallback sang toàn bộ tasks nếu mất calendar default
    context.read<HomeBloc>().add(FetchHomeData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HomeLoaded) {
            if (state.tasks.isEmpty) {
              return const Center(
                child: Text('Không có công việc trong lịch mặc định.'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: state.tasks.length,
              itemBuilder: (_, i) {
                final t = state.tasks[i];
                return Card(
                  child: ListTile(
                    title: Text(t.title),
                    subtitle: Text('Lịch: ${state.defaultCalendar.name}'),
                    leading: Icon(
                      t.repeatType == RepeatType.NONE
                          ? Icons.event_note
                          : Icons.repeat,
                    ),
                  ),
                );
              },
            );
          }
          if (state is HomeError) {
            return Center(child: Text(state.message));
          }
          return const Center(
            child: Text(
              'Nội dung trang chủ (Lịch chính và các công việc) sẽ được hiển thị ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}
