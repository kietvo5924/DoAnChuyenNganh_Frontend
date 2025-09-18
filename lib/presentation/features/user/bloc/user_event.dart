abstract class UserEvent {}

class FetchUserProfile extends UserEvent {}

class ChangePasswordRequested extends UserEvent {
  final String currentPassword;
  final String newPassword;
  final String confirmationPassword;

  ChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmationPassword,
  });
}
