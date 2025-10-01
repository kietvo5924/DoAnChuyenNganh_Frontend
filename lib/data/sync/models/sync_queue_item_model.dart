class SyncQueueItemModel {
  final int? id;
  final String entityType;
  final int entityId;
  final String action;
  final String? payload; // NEW

  SyncQueueItemModel({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.payload, // NEW
  });

  factory SyncQueueItemModel.fromMap(Map<String, dynamic> map) {
    return SyncQueueItemModel(
      id: map['id'],
      entityType: map['entity_type'],
      entityId: map['entity_id'],
      action: map['action'],
      payload: map['payload'], // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload, // NEW
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
