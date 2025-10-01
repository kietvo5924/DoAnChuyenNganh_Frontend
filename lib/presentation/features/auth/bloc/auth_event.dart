import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckStatusRequested extends AuthEvent {}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;
  const SignInRequested({required this.email, required this.password});
}

class SignUpRequested extends AuthEvent {
  final String fullName;
  final String email;
  final String password;
  const SignUpRequested({
    required this.fullName,
    required this.email,
    required this.password,
  });
}

class SignOutRequested extends AuthEvent {}

class SignInAsGuestRequested extends AuthEvent {}

class GuestWantsToLogin extends AuthEvent {}
