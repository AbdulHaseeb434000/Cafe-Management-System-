import '../core/constants/app_constants.dart';

class TableModel {
  final int? id;
  final String name;
  final int capacity;
  final String status;

  const TableModel({
    this.id,
    required this.name,
    this.capacity = 4,
    this.status = AppConstants.tableStatusFree,
  });

  bool get isFree => status == AppConstants.tableStatusFree;
  bool get isOccupied => status == AppConstants.tableStatusOccupied;
  bool get isReserved => status == AppConstants.tableStatusReserved;

  TableModel copyWith({int? id, String? name, int? capacity, String? status}) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'capacity': capacity,
        'status': status,
      };

  factory TableModel.fromMap(Map<String, dynamic> map) => TableModel(
        id: map['id'] as int,
        name: map['name'] as String,
        capacity: map['capacity'] as int? ?? 4,
        status: map['status'] as String? ?? AppConstants.tableStatusFree,
      );
}
