import 'dart:convert';
import 'package:flutter/material.dart';

class Budget {
  final String id;
  final String name;
  final double amount;
  final List<String> categoryIds;
  final IconData icon;
  final Color color;
  final int sortOrder;

  const Budget({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryIds,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
  });

  Budget copyWith({
    String? id,
    String? name,
    double? amount,
    List<String>? categoryIds,
    IconData? icon,
    Color? color,
    int? sortOrder,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryIds: categoryIds ?? this.categoryIds,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category_ids': jsonEncode(categoryIds),
      'icon': icon.codePoint,
      'color': color.toARGB32(),
      'sort_order': sortOrder,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    // Parse category_ids - handle both JSON array and single UUID string
    final categoryIdsRaw = map['category_ids'];
    List<String> categoryIds;
    if (categoryIdsRaw == null) {
      categoryIds = [];
    } else if (categoryIdsRaw is String) {
      if (categoryIdsRaw.startsWith('[')) {
        // JSON array format: ["uuid1", "uuid2"]
        try {
          final decoded = jsonDecode(categoryIdsRaw);
          if (decoded is List) {
            categoryIds = decoded.map((e) => e.toString()).toList();
          } else {
            categoryIds = [];
          }
        } catch (_) {
          categoryIds = [];
        }
      } else if (categoryIdsRaw.contains(',')) {
        // Comma-separated format: "uuid1,uuid2" (legacy Supabase format)
        categoryIds = categoryIdsRaw.split(',').where((s) => s.isNotEmpty).toList();
      } else {
        // Single UUID format: "uuid1"
        categoryIds = categoryIdsRaw.isNotEmpty ? [categoryIdsRaw] : [];
      }
    } else {
      categoryIds = [];
    }

    // Parse icon - handle int, UUID string, or default
    IconData icon;
    final iconRaw = map['icon'];
    if (iconRaw is int) {
      icon = IconData(iconRaw, fontFamily: 'MaterialIcons');
    } else if (iconRaw is String && iconRaw.isNotEmpty) {
      // UUID string - use default icon
      icon = const IconData(0xe8a6, fontFamily: 'MaterialIcons');
    } else {
      icon = const IconData(0xe8a6, fontFamily: 'MaterialIcons');
    }

    // Parse color - handle int, null, or default
    Color color;
    final colorRaw = map['color'];
    if (colorRaw is int) {
      color = Color(colorRaw);
    } else {
      // null or invalid - use default color
      color = const Color(0xFF607D8B);
    }

    // Parse sort_order - handle int, DateTime, or default
    int sortOrder;
    final sortRaw = map['sort_order'];
    if (sortRaw is int) {
      sortOrder = sortRaw;
    } else if (sortRaw is DateTime) {
      // DateTime incorrectly stored - use default
      sortOrder = 0;
    } else if (sortRaw is num) {
      sortOrder = sortRaw.toInt();
    } else {
      sortOrder = 0;
    }

    return Budget(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      amount: num.tryParse(map['amount']?.toString() ?? '0')?.toDouble() ?? 0,
      categoryIds: categoryIds,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
    );
  }
}
