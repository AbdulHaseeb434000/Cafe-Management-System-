import '../core/utils/date_helpers.dart';

class MenuItemModel {
  final int? id;
  final int categoryId;
  final String name;
  final double price;
  final String? description;
  final bool isAvailable;
  final String? imagePath;
  final DateTime createdAt;

  const MenuItemModel({
    this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description,
    this.isAvailable = true,
    this.imagePath,
    required this.createdAt,
  });

  MenuItemModel copyWith({
    int? id,
    int? categoryId,
    String? name,
    double? price,
    String? description,
    bool? isAvailable,
    String? imagePath,
    DateTime? createdAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'name': name,
        'price': price,
        'description': description,
        'is_available': isAvailable ? 1 : 0,
        'image_path': imagePath,
        'created_at': DateHelpers.toIso(createdAt),
      };

  factory MenuItemModel.fromMap(Map<String, dynamic> map) => MenuItemModel(
        id: map['id'] as int,
        categoryId: map['category_id'] as int,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        description: map['description'] as String?,
        isAvailable: (map['is_available'] as int? ?? 1) == 1,
        imagePath: map['image_path'] as String?,
        createdAt: DateHelpers.fromIso(map['created_at'] as String),
      );

  factory MenuItemModel.create({
    required int categoryId,
    required String name,
    required double price,
    String? description,
  }) =>
      MenuItemModel(
        categoryId: categoryId,
        name: name,
        price: price,
        description: description,
        createdAt: DateTime.now(),
      );
}
