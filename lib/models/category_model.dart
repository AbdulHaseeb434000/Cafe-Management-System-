import '../core/utils/date_helpers.dart';

class CategoryModel {
  final int? id;
  final String name;
  final String icon;
  final int sortOrder;
  final DateTime createdAt;

  const CategoryModel({
    this.id,
    required this.name,
    this.icon = 'restaurant',
    this.sortOrder = 0,
    required this.createdAt,
  });

  CategoryModel copyWith({
    int? id,
    String? name,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon': icon,
        'sort_order': sortOrder,
        'created_at': DateHelpers.toIso(createdAt),
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as int,
        name: map['name'] as String,
        icon: map['icon'] as String? ?? 'restaurant',
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: DateHelpers.fromIso(map['created_at'] as String),
      );

  factory CategoryModel.create({required String name, String icon = 'restaurant', int sortOrder = 0}) =>
      CategoryModel(name: name, icon: icon, sortOrder: sortOrder, createdAt: DateTime.now());
}
