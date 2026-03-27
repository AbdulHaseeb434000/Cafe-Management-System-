import '../core/utils/date_helpers.dart';

class CustomerModel {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  const CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.address,
    required this.createdAt,
  });

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'created_at': DateHelpers.toIso(createdAt),
      };

  factory CustomerModel.fromMap(Map<String, dynamic> map) => CustomerModel(
        id: map['id'] as int,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        createdAt: DateHelpers.fromIso(map['created_at'] as String),
      );

  factory CustomerModel.create({
    required String name,
    String? phone,
    String? address,
  }) =>
      CustomerModel(name: name, phone: phone, address: address, createdAt: DateTime.now());
}
