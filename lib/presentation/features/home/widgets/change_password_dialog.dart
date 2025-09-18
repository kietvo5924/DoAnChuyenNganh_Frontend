import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../user/bloc/user_bloc.dart';
import '../../user/bloc/user_event.dart';
import '../../user/bloc/user_state.dart';

// Giải thích: Widget này tạo ra một hộp thoại (dialog) cho phép người dùng
// nhập thông tin để đổi mật khẩu. Nó là một StatefulWidget để quản lý
// các TextEditingController.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<UserBloc>().add(
        ChangePasswordRequested(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          confirmationPassword: _confirmPasswordController.text,
        ),
      );
      // Sau khi gửi event, dialog sẽ được đóng từ BlocListener ở profile_page
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        return AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                    ),
                    obscureText: true,
                    validator: (value) =>
                        value!.isEmpty ? 'Không được để trống' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới',
                    ),
                    obscureText: true,
                    validator: (value) => (value!.length < 6)
                        ? 'Mật khẩu phải có ít nhất 6 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Mật khẩu xác nhận không khớp';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            // Nếu đang loading thì hiển thị vòng xoay, nếu không thì hiển thị nút Lưu
            if (state is UserLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(onPressed: _submit, child: const Text('Lưu')),
          ],
        );
      },
    );
  }
}
