import 'package:flutter/material.dart';

class FolderModel {
  final String id;
  final String name;
  final int itemCount;
  final Color color;
  final DateTime createdAt;

  FolderModel({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'itemCount': itemCount,
      'color': color.toARGB32(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      itemCount: map['itemCount'] ?? 0,
      color: Color(map['color'] ?? Colors.blue.toARGB32()),
      createdAt: map['createdAt'] != null 
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now() 
          : DateTime.now(),
    );
  }
}
