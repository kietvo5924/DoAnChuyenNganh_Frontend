import 'package:equatable/equatable.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();
  @override
  List<Object?> get props => [];
}

class FetchCalendars extends CalendarEvent {}

class AddCalendar extends CalendarEvent {
  final String name;
  final String? description;
  const AddCalendar({required this.name, this.description});
}

class UpdateCalendarRequested extends CalendarEvent {
  final int id;
  final String name;
  final String? description;
  const UpdateCalendarRequested({
    required this.id,
    required this.name,
    this.description,
  });
}

class DeleteCalendarRequested extends CalendarEvent {
  final int id;
  const DeleteCalendarRequested({required this.id});
}

class SetDefaultCalendarRequested extends CalendarEvent {
  final int id;
  const SetDefaultCalendarRequested({required this.id});
}
