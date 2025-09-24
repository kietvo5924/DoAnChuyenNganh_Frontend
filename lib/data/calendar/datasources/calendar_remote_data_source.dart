import 'package:dio/dio.dart';
import 'package:planmate_app/core/config/api_config.dart';
import 'package:planmate_app/data/calendar/models/calendar_model.dart';

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
      data: {'name': name, 'description': description},
    );
    return CalendarModel.fromJson(response.data);
  }

  @override
  Future<CalendarModel> updateCalendar(
    int id,
    String name,
    String? description,
  ) async {
    final response = await dio.put(
      '${ApiConfig.baseUrl}/calendars/$id',
      data: {'name': name, 'description': description},
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
}
