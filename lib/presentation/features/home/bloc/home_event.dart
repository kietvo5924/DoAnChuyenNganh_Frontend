import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object> get props => [];
}

// Event để ra lệnh cho BLoC tải dữ liệu cần thiết cho trang chủ
class FetchHomeData extends HomeEvent {}
