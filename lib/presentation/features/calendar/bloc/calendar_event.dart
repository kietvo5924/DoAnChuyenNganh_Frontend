import 'package:equatable/equatable.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();
  @override
  List<Object?> get props => [];
}

class FetchCalendars extends CalendarEvent {
  final bool forceRemote;
  const FetchCalendars({this.forceRemote = false});
  @override
  List<Object?> get props => [forceRemote];
}

class SaveCalendarRequested extends CalendarEvent {
  final CalendarEntity calendar;
  const SaveCalendarRequested(this.calendar);
  @override
  List<Object?> get props => [calendar];
}

class DeleteCalendarRequested extends CalendarEvent {
  final int calendarId;
  const DeleteCalendarRequested(this.calendarId);
  @override
  List<Object?> get props => [calendarId];
}

class SetDefaultCalendarRequested extends CalendarEvent {
  final int calendarId;
  const SetDefaultCalendarRequested(this.calendarId);
  @override
  List<Object?> get props => [calendarId];
}

class SaveCalendarSubmitted extends CalendarEvent {
  final CalendarEntity calendar;
  const SaveCalendarSubmitted({required this.calendar});
  @override
  List<Object?> get props => [calendar];
}

class DeleteCalendarSubmitted extends CalendarEvent {
  final int calendarId;
  const DeleteCalendarSubmitted({required this.calendarId});
  @override
  List<Object?> get props => [calendarId];
}

class SetDefaultCalendarSubmitted extends CalendarEvent {
  final int calendarId;
  const SetDefaultCalendarSubmitted({required this.calendarId});
  @override
  List<Object?> get props => [calendarId];
}

class ShareCalendarRequested extends CalendarEvent {
  final int calendarId;
  final String email;
  final String permissionLevel; // "VIEW_ONLY" hoặc "EDIT"
  const ShareCalendarRequested({
    required this.calendarId,
    required this.email,
    required this.permissionLevel,
  });
  @override
  List<Object?> get props => [calendarId, email, permissionLevel];
}

class ReportCalendarAbuseRequested extends CalendarEvent {
  final int calendarId;
  final String reason;
  final String? description;
  const ReportCalendarAbuseRequested({
    required this.calendarId,
    required this.reason,
    this.description,
  });

  @override
  List<Object?> get props => [calendarId, reason, description];
}

class UnshareCalendarRequested extends CalendarEvent {
  final int calendarId;
  final int userId;
  const UnshareCalendarRequested({
    required this.calendarId,
    required this.userId,
  });
  @override
  List<Object?> get props => [calendarId, userId];
}

class FetchSharingUsers extends CalendarEvent {
  final int calendarId;
  const FetchSharingUsers({required this.calendarId});
  @override
  List<Object?> get props => [calendarId];
}

class FetchSharedWithMeCalendars extends CalendarEvent {}

class InitializeCalendarDetail extends CalendarEvent {
  final CalendarEntity calendar;
  const InitializeCalendarDetail({required this.calendar});
  @override
  List<Object?> get props => [calendar];
}
