import 'package:dio/dio.dart';
import 'package:planmate_app/data/user/models/user_model.dart';
import '../../../core/config/api_config.dart';
import '../models/calendar_model.dart';

abstract class CalendarRemoteDataSource {
  Future<List<CalendarModel>> getAllCalendars();
  Future<CalendarModel> createCalendar(String name, String? description);
  Future<CalendarModel> updateCalendar(
    int id,
    String name,
    String? description,
  );
  Future<void> deleteCalendar(int id);
  Future<void> setDefaultCalendar(int id);

  Future<void> shareCalendar(
    int calendarId,
    String email,
    String permissionLevel,
  );
  Future<void> unshareCalendar(int calendarId, int userId);
  Future<List<UserModel>> getUsersSharingCalendar(
    int calendarId,
  ); // Giả sử bạn có UserModel
  Future<List<CalendarModel>> getCalendarsSharedWithMe();
}

class CalendarRemoteDataSourceImpl implements CalendarRemoteDataSource {
  final Dio dio;
  CalendarRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<CalendarModel>> getAllCalendars() async {
    final response = await dio.get('${ApiConfig.baseUrl}/calendars');
    return (response.data as List)
        .map((json) => CalendarModel.fromJson(json))
        .toList();
  }

  @override
  Future<CalendarModel> createCalendar(String name, String? description) async {
    final response = await dio.post(
      '${ApiConfig.baseUrl}/calendars',
      data: {'name': name, 'description': description, 'isDefault': false},
    );
    return CalendarModel.fromJson(response.data);
  }

  @override
  Future<CalendarModel> updateCalendar(
    int id,
    String name,
    String? description,
  ) async {
    // Gửi luôn isDefault để server không vô tình reset
    final response = await dio.put(
      '${ApiConfig.baseUrl}/calendars/$id',
      data: {
        'name': name,
        'description': description,
        // Nếu backend bỏ qua field này cũng không sao, nhưng giúp bảo toàn trạng thái
        'isDefault': false, // sẽ được xử lý lại bằng set-default endpoint khác
      },
    );
    return CalendarModel.fromJson(response.data);
  }

  @override
  Future<void> deleteCalendar(int id) async {
    await dio.delete('${ApiConfig.baseUrl}/calendars/$id');
  }

  @override
  Future<void> setDefaultCalendar(int id) async {
    await dio.put('${ApiConfig.baseUrl}/calendars/$id/set-default');
  }

  @override
  Future<void> shareCalendar(
    int calendarId,
    String email,
    String permissionLevel,
  ) async {
    await dio.post(
      '${ApiConfig.baseUrl}/calendars/$calendarId/share',
      data: {
        'email': email,
        'permissionLevel':
            permissionLevel, // Backend mong đợi "VIEW_ONLY" hoặc "EDIT"
      },
    );
  }

  @override
  Future<void> unshareCalendar(int calendarId, int userId) async {
    await dio.delete(
      '${ApiConfig.baseUrl}/calendars/$calendarId/unshare/$userId',
    );
  }

  @override
  Future<List<UserModel>> getUsersSharingCalendar(int calendarId) async {
    // Lưu ý: Cần có UserModel và fromJson tương ứng
    final response = await dio.get(
      '${ApiConfig.baseUrl}/calendars/$calendarId/users',
    );
    // Giả sử UserModel có factory UserModel.fromJson
    return (response.data as List)
        .map((json) => UserModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<CalendarModel>> getCalendarsSharedWithMe() async {
    final response = await dio.get(
      '${ApiConfig.baseUrl}/calendars/shared-with-me',
    );
    return (response.data as List)
        .map((json) => CalendarModel.fromJson(json))
        .toList();
  }
}
