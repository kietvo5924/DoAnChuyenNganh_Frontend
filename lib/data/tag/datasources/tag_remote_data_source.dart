import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../models/tag_model.dart';

abstract class TagRemoteDataSource {
  Future<List<TagModel>> getAllTags();
  Future<TagModel> createTag(String name, String? color);
  Future<TagModel> updateTag(int id, String name, String? color);
  Future<void> deleteTag(int id);
}

class TagRemoteDataSourceImpl implements TagRemoteDataSource {
  final Dio dio;
  TagRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<TagModel>> getAllTags() async {
    final response = await dio.get('${ApiConfig.baseUrl}/tags');
    return (response.data as List)
        .map((json) => TagModel.fromJson(json))
        .toList();
  }

  @override
  Future<TagModel> createTag(String name, String? color) async {
    final response = await dio.post(
      '${ApiConfig.baseUrl}/tags',
      data: {'name': name, 'color': color},
    );
    return TagModel.fromJson(response.data);
  }

  @override
  Future<TagModel> updateTag(int id, String name, String? color) async {
    final response = await dio.put(
      '${ApiConfig.baseUrl}/tags/$id',
      data: {'name': name, 'color': color},
    );
    return TagModel.fromJson(response.data);
  }

  @override
  Future<void> deleteTag(int id) async {
    await dio.delete('${ApiConfig.baseUrl}/tags/$id');
  }
}
