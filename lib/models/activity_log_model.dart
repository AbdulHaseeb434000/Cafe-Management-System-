class ActivityLogModel {
  final int? id;
  final String uuid;
  final String actionType;
  final String entityType;
  final String entityName;
  final String? details;
  final DateTime createdAt;

  const ActivityLogModel({
    this.id,
    required this.uuid,
    required this.actionType,
    required this.entityType,
    required this.entityName,
    this.details,
    required this.createdAt,
  });

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    return ActivityLogModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      actionType: map['action_type'] as String,
      entityType: map['entity_type'] as String,
      entityName: map['entity_name'] as String,
      details: map['details'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'action_type': actionType,
        'entity_type': entityType,
        'entity_name': entityName,
        'details': details,
        'created_at': createdAt.toIso8601String(),
      };
}
