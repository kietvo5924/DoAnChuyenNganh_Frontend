import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

// Trạng thái ngay sau khi người dùng nhấn nút đăng nhập thành công
class AuthJustLoggedIn extends AuthState {}

// Trạng thái khi người dùng mở lại app và đã đăng nhập từ trước
class AuthAlreadyLoggedIn extends AuthState {}

// Trạng thái đã đăng xuất hoặc chưa từng đăng nhập
class AuthSignedOut extends AuthState {}

// Trạng thái khi vào chế độ khách thành công
class AuthGuestSuccess extends AuthState {}

// Các trạng thái có dữ liệu (chỉ dùng cho thông báo)
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
