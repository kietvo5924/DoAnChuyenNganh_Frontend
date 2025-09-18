import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../domain/user/usecases/change_password.dart'; // <-- Import
import '../../../../domain/user/usecases/get_user_profile.dart'; // <-- Import
import 'user_event.dart';
import 'user_state.dart';

// Giải thích: UserBloc quản lý logic và trạng thái cho các tính năng liên quan đến người dùng.
class UserBloc extends Bloc<UserEvent, UserState> {
  // Khai báo các use case mà BLoC này sẽ phụ thuộc vào
  final GetUserProfile _getUserProfileUseCase;
  final ChangePassword _changePasswordUseCase;

  // Constructor để inject (tiêm) các dependency vào
  UserBloc({
    required GetUserProfile getUserProfileUseCase,
    required ChangePassword changePasswordUseCase,
  }) : _getUserProfileUseCase = getUserProfileUseCase,
       _changePasswordUseCase = changePasswordUseCase,
       super(UserInitial()) {
    // Trình xử lý sự kiện GetUserProfile
    on<FetchUserProfile>((event, emit) async {
      emit(UserLoading());
      // Gọi use case và nhận về kết quả
      final result = await _getUserProfileUseCase();
      result.fold(
        (failure) =>
            emit(UserOperationFailure(message: "Tải thông tin thất bại")),
        (profile) => emit(UserProfileLoaded(profile: profile)),
      );
    });

    // Trình xử lý sự kiện ChangePasswordRequested
    on<ChangePasswordRequested>((event, emit) async {
      emit(UserLoading());
      // Gọi use case với các tham số từ event
      final result = await _changePasswordUseCase(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
        confirmationPassword: event.confirmationPassword,
      );
      result.fold(
        // Ép kiểu failure thành ServerFailure để lấy message cụ thể từ server
        (failure) => emit(
          UserOperationFailure(
            message: (failure as ServerFailure).message ?? "Đã xảy ra lỗi",
          ),
        ),
        (message) => emit(UserOperationSuccess(message: message)),
      );
    });
  }
}
