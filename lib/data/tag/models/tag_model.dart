import '../../../domain/tag/entities/tag_entity.dart';

class TagModel extends TagEntity {
  const TagModel({required int id, required String name, String? color})
    : super(id: id, name: name, color: color);

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(id: json['id'], name: json['name'], color: json['color']);
  }

  factory TagModel.fromDb(Map<String, dynamic> map) {
    return TagModel(id: map['id'], name: map['name'], color: map['color']);
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'is_synced': 1, // Mặc định là đã đồng bộ khi cache
    };
  }
}
