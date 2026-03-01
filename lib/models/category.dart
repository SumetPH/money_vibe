import 'package:flutter/material.dart';

enum CategoryType { expense, income }

class Category {
  final String id;
  String name;
  IconData icon;
  Color color;
  CategoryType type;
  String? parentId;
  bool isDefault;
  String? note;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.parentId,
    this.isDefault = false,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
        'parent_id': parentId,
        'is_default': isDefault ? 1 : 0,
        'note': note,
      };

  static Category fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        type: CategoryType.values
            .firstWhere((e) => e.name == m['type'] as String),
        icon: IconData(m['icon'] as int, fontFamily: 'MaterialIcons'),
        color: Color(m['color'] as int),
        parentId: m['parent_id'] as String?,
        isDefault: m['is_default'] == 1,
        note: m['note'] as String?,
      );

  Category copyWith({
    String? name,
    IconData? icon,
    Color? color,
    CategoryType? type,
    String? parentId,
    bool? isDefault,
    String? note,
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
      isDefault: isDefault ?? this.isDefault,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
