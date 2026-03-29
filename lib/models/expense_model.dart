import 'package:uuid/uuid.dart';

class ExpenseModel {
  final int? id;
  final String uuid;
  final String category;
  final double amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;

  const ExpenseModel({
    this.id,
    required this.uuid,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
  });

  static const categories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Supplies',
    'Maintenance',
    'Marketing',
    'Other',
  ];

  factory ExpenseModel.create({
    required String category,
    required double amount,
    required String description,
    required DateTime date,
  }) {
    final now = DateTime.now();
    return ExpenseModel(
      uuid: const Uuid().v4(),
      category: category,
      amount: amount,
      description: description,
      date: date,
      createdAt: now,
    );
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) => ExpenseModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String? ?? '',
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'category': category,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  ExpenseModel copyWith({
    int? id,
    String? category,
    double? amount,
    String? description,
    DateTime? date,
  }) =>
      ExpenseModel(
        id: id ?? this.id,
        uuid: uuid,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        date: date ?? this.date,
        createdAt: createdAt,
      );
}
