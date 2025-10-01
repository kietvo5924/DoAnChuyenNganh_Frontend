import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();
  @override
  List<Object> get props => [];
}

// Lấy thông tin người dùng từ cache (local DB)
class FetchCachedUserProfile extends UserEvent {}

// Đồng bộ thông tin người dùng từ server về cache
class SyncRemoteUserProfile extends UserEvent {}

// Gửi yêu cầu đổi mật khẩu
class ChangePasswordSubmitted extends UserEvent {
  final String currentPassword;
  final String newPassword;
  final String confirmationPassword;

  const ChangePasswordSubmitted({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmationPassword,
  });

  @override
  List<Object> get props => [
    currentPassword,
    newPassword,
    confirmationPassword,
  ];
}
