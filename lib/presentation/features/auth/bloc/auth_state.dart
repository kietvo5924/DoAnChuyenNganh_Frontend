import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSignInSuccess extends AuthState {}

class AuthSignOutSuccess extends AuthState {}

// Các trạng thái có dữ liệu thì cần đưa dữ liệu vào props.
class AuthSignUpSuccess extends AuthState {
  final String message;
  const AuthSignUpSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure({required this.message});

  @override
  List<Object> get props => [message];
}
