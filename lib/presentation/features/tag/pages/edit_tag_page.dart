import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../../domain/tag/entities/tag_entity.dart';
import '../bloc/tag_bloc.dart';
import '../bloc/tag_event.dart';
import '../bloc/tag_state.dart';

// Hàm helper để chuyển đổi chuỗi Hex thành Color
Color _hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class EditTagPage extends StatefulWidget {
  final TagEntity tag;
  const EditTagPage({super.key, required this.tag});

  @override
  State<EditTagPage> createState() => _EditTagPageState();
}

class _EditTagPageState extends State<EditTagPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag.name);
    _currentColor = _hexToColor(widget.tag.color ?? '#808080');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  // -- HÀM ĐÃ ĐƯỢC SỬA LỖI --
  void _updateTag() {
    if (_formKey.currentState!.validate()) {
      // 1. Tạo đối tượng TagEntity đã được cập nhật với thông tin mới từ form
      final updatedTag = TagEntity(
        id: widget.tag.id, // Giữ lại ID cũ
        name: _nameController.text.trim(),
        color: _colorToHex(_currentColor),
      );
      // 2. Gửi đi event hợp nhất SaveTagSubmitted
      context.read<TagBloc>().add(SaveTagSubmitted(tag: updatedTag));
    }
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn một màu'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentColor,
            onColorChanged: (color) {
              setState(() => _currentColor = color);
            },
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa Nhãn'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _updateTag),
        ],
      ),
      body: BlocListener<TagBloc, TagState>(
        listener: (context, state) {
          if (state is TagOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          } else if (state is TagError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhãn',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'Tên không được để trống' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Màu sắc:', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 16),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _currentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _pickColor,
                      child: const Text('Chọn màu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
