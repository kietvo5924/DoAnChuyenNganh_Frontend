import 'package:equatable/equatable.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';

abstract class CalendarState extends Equatable {
  const CalendarState();
  @override
  List<Object> get props => [];
}

class CalendarInitial extends CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarLoaded extends CalendarState {
  final List<CalendarEntity> calendars;
  const CalendarLoaded({required this.calendars});
  @override
  List<Object> get props => [calendars];
}

class CalendarOperationSuccess extends CalendarState {
  final String message;
  const CalendarOperationSuccess({required this.message});
  @override
  List<Object> get props => [message];
}

class CalendarError extends CalendarState {
  final String message;
  const CalendarError({required this.message});
  @override
  List<Object> get props => [message];
}
