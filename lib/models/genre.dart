import 'package:flutter/material.dart';

/// メモを分類するためのジャンル(カテゴリ)。
class Genre {
  Genre({
    required this.id,
    required this.name,
    required this.color,
  });

  factory Genre.fromMap(Map<String, Object?> map) {
    return Genre(
      id: map['id']! as String,
      name: map['name']! as String,
      color: Color(map['color']! as int),
    );
  }

  final String id;
  final String name;
  final Color color;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
    };
  }

  Genre copyWith({String? name, Color? color}) {
    return Genre(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
