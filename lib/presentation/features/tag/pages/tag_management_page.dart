import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/tag/entities/tag_entity.dart';
import '../bloc/tag_bloc.dart';
import '../bloc/tag_event.dart';
import '../bloc/tag_state.dart';
import 'add_tag_page.dart';
import 'edit_tag_page.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/empty_state.dart';

Color _hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});
  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  @override
  void initState() {
    super.initState();
    context.read<TagBloc>().add(FetchTags());
  }

  void _showDeleteConfirmationDialog(BuildContext context, TagEntity tag) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa nhãn "${tag.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              context.read<TagBloc>().add(DeleteTagSubmitted(tagId: tag.id));
              Navigator.pop(dialogContext);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Nhãn')),
      body: BlocListener<TagBloc, TagState>(
        listener: (context, state) {
          if (state is TagOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TagError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<TagBloc, TagState>(
          builder: (context, state) {
            if (state is TagLoaded) {
              if (state.tags.isEmpty) {
                return const Center(
                  child: EmptyState(
                    icon: Icons.label_outline,
                    title: 'Chưa có nhãn',
                    message: 'Tạo nhãn mới để phân loại công việc.',
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => context.read<TagBloc>().add(FetchTags()),
                child: ListView.builder(
                  itemCount: state.tags.length,
                  itemBuilder: (context, index) {
                    final tag = state.tags[index];
                    return ListTile(
                      key: ValueKey(tag.id),
                      leading: Icon(
                        Icons.circle,
                        color: _hexToColor(tag.color ?? '#808080'),
                      ),
                      title: Text(tag.name),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditTagPage(tag: tag),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            _showDeleteConfirmationDialog(context, tag),
                      ),
                    );
                  },
                ),
              );
            }
            return const Center(child: LoadingIndicator());
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tạo nhãn mới',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTagPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
