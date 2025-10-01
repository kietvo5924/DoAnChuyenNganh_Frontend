import 'package:equatable/equatable.dart';

// Đây là lớp cơ sở (base class) cho tất cả các loại lỗi trong ứng dụng.
// Việc dùng một lớp cơ sở giúp chúng ta xử lý lỗi một cách đồng bộ.
// Kế thừa từ Equatable giúp việc so sánh các đối tượng Failure dễ dàng hơn,
// đặc biệt hữu ích trong việc unit test và quản lý state của BLoC.
abstract class Failure extends Equatable {
  const Failure([List properties = const <dynamic>[]]);

  @override
  List<Object> get props => [];
}

// Các loại lỗi cụ thể sẽ kế thừa từ lớp Failure ở trên.

// Lỗi xảy ra khi giao tiếp với server (API).
// Ví dụ: Lỗi 404 Not Found, 500 Internal Server Error, hoặc lỗi parse JSON.
// Chúng ta thêm một thuộc tính `message` để có thể chứa thông báo lỗi trả về từ backend.
class ServerFailure extends Failure {
  final String? message;

  const ServerFailure({this.message});

  @override
  List<Object> get props => [message ?? ''];
}

// Lỗi xảy ra khi tương tác với bộ nhớ đệm cục bộ (local cache).
// Ví dụ: Lỗi khi đọc/ghi dữ liệu từ SharedPreferences hoặc SQLite.
class CacheFailure extends Failure {}

// Lỗi liên quan đến kết nối mạng.
// Ví dụ: Không có kết nối Internet.
class NetworkFailure extends Failure {}
