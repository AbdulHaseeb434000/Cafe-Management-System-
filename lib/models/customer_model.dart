import 'package:uuid/uuid.dart';
import '../core/utils/date_helpers.dart';

class CustomerModel {
  final int? id;
  final String uuid;
  final String name;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  const CustomerModel({
    this.id,
    required this.uuid,
    required this.name,
    this.phone,
    this.address,
    required this.createdAt,
  });

  CustomerModel copyWith({
    int? id,
    String? uuid,
    String? name,
    String? phone,
    String? address,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'name': name,
        'phone': phone,
        'address': address,
        'created_at': DateHelpers.toIso(createdAt),
      };

  factory CustomerModel.fromMap(Map<String, dynamic> map) => CustomerModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String,
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
      CustomerModel(
        uuid: const Uuid().v4(),
        name: name,
        phone: phone,
        address: address,
        createdAt: DateTime.now(),
      );
}
