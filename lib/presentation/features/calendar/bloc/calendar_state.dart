import 'package:equatable/equatable.dart';
import 'package:planmate_app/domain/user/entities/user_entity.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';

abstract class CalendarState extends Equatable {
  const CalendarState();
  @override
  List<Object?> get props => [];
}

class CalendarInitial extends CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarLoaded extends CalendarState {
  final List<CalendarEntity> calendars;
  const CalendarLoaded({required this.calendars});
  @override
  List<Object?> get props => [calendars];
}

class CalendarOperationInProgress extends CalendarState {}

class CalendarOperationSuccess extends CalendarState {
  final String message;
  const CalendarOperationSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class CalendarError extends CalendarState {
  final String message;
  const CalendarError({required this.message});
  @override
  List<Object?> get props => [message];
}

// Hoặc tạo State riêng cho trang chi tiết lịch, bao gồm danh sách người dùng
class CalendarDetailLoaded extends CalendarState {
  final CalendarEntity calendar;
  final List<UserEntity> sharingUsers; // Thêm mới

  const CalendarDetailLoaded({
    required this.calendar,
    this.sharingUsers = const [],
  });

  // Thêm copyWith để cập nhật danh sách user mà không cần load lại cả trang
  CalendarDetailLoaded copyWith({
    CalendarEntity? calendar,
    List<UserEntity>? sharingUsers,
  }) {
    return CalendarDetailLoaded(
      calendar: calendar ?? this.calendar,
      sharingUsers: sharingUsers ?? this.sharingUsers,
    );
  }

  @override
  List<Object?> get props => [calendar, sharingUsers];
}

// Có thể thêm State riêng cho danh sách lịch được chia sẻ với tôi
class CalendarSharedWithMeLoaded extends CalendarState {
  final List<CalendarEntity> calendars;
  const CalendarSharedWithMeLoaded({required this.calendars});
  @override
  List<Object?> get props => [calendars];
}
