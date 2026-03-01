import 'package:flutter/material.dart';

enum CategoryType { expense, income }

class Category {
  final String id;
  String name;
  IconData icon;
  Color color;
  CategoryType type;
  String? parentId;
  String? note;
  int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.parentId,
    this.note,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'icon': icon.codePoint,
    'color': color.toARGB32(),
    'parent_id': parentId,
    'note': note ?? '',
    'sort_order': sortOrder,
  };

  static Category fromMap(Map<String, dynamic> m) => Category(
    id: m['id'] as String,
    name: m['name'] as String,
    type: CategoryType.values.firstWhere((e) => e.name == m['type'] as String),
    icon: IconData(m['icon'] as int, fontFamily: 'MaterialIcons'),
    color: Color(m['color'] as int),
    parentId: m['parent_id'] as String?,
    note: m['note'] as String?,
    sortOrder: m['sort_order'] as int? ?? 0,
  );

  Category copyWith({
    String? name,
    IconData? icon,
    Color? color,
    CategoryType? type,
    String? parentId,
    bool? isDefault,
    String? note,
    int? sortOrder,
    bool clearParent = false,
    bool clearNote = false,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      note: clearNote ? null : (note ?? this.note),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
