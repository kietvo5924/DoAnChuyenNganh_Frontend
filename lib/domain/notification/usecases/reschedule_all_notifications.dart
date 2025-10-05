import 'package:planmate_app/core/services/database_service.dart';
import 'package:planmate_app/core/services/notification_service.dart';

class RescheduleAllNotifications {
  final NotificationService notificationService;
  final DatabaseService dbService;

  RescheduleAllNotifications({
    required this.notificationService,
    required this.dbService,
  });

  Future<void> call({int remindBeforeMinutes = 15}) async {
    final db = await dbService.database;
    await notificationService.rescheduleAllUpcomingTasksFromDb(
      db,
      remindBeforeMinutes: remindBeforeMinutes,
    );
  }
}
