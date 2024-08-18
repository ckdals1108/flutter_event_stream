import 'dart:convert';

import 'package:flutter/foundation.dart';

class EventModel {
  final String id;
  final String name;
  final Map<String, dynamic> properties;
  final DateTime createdAt;
  EventModel({
    required this.id,
    required this.name,
    required this.properties,
    required this.createdAt,
  });

  EventModel copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? properties,
    DateTime? createdAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      properties: properties ?? this.properties,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'properties': properties,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] as String,
      name: map['name'] as String,
      properties: Map<String, dynamic>.from(
        (map['properties'] as Map<String, dynamic>),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory EventModel.fromJson(String source) =>
      EventModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'EventModel(id: $id, name: $name, properties: $properties, createdAt: $createdAt)';
  }

  @override
  bool operator ==(covariant EventModel other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.name == name &&
        mapEquals(other.properties, properties) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        properties.hashCode ^
        createdAt.hashCode;
  }
}
