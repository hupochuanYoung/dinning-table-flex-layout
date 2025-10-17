
import 'package:flutter/material.dart' ;

/// 支持的组件类型
enum ShapeType {
  // 结构类
  wall,
  door,
  window,
  pillar,
  kitchen,
  restroom,
  // 桌椅类
  tableRect,
  tableRound,
  chair,
  booth,
  // 业务类
  cashier,
  barCounter,
  queueArea,
  // 辅助类
  label,
  arrow,
  decoration,
}

enum TableStatus { free, reserved, occupied, disabled }

class TableModel {
  final String id;
  String name;
  TableStatus status;
  int capacity;
  List<int> distribution;

  TableModel({
    required this.id,
    required this.name,
    this.status = TableStatus.free,
    this.capacity = 0,
    this.distribution = const [0, 0, 0, 0],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'capacity': capacity,
      'distribution': distribution,
    };
  }

  static TableModel fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      name: json['name'],
      status: TableStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => TableStatus.free,
      ),
      capacity: json['capacity'] ?? 0,
      distribution: (json['distribution'] as List).map((e) => e as int).toList(),
    );
  }
}

/// 画布上一个物体
class ShapeModel {
  final String id;
  final ShapeType type;
  Offset position; // 世界坐标（未缩放）
  Size size; // 世界尺寸
  double rotation; // 弧度
  bool selected;
  TableModel? table;

  ShapeModel({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.selected = false,
    this.table,
  });

}
extension ShapeModelJson on ShapeModel {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'x': position.dx,
      'y': position.dy,
      'w': size.width,
      'h': size.height,
      'rotation': rotation,
      if (table != null) 'table': table!.toJson(),

    };
  }

  static ShapeModel fromJson(Map<String, dynamic> json) {
    return ShapeModel(
      id: json['id'],
      type: ShapeType.values.firstWhere((e) => e.name == json['type']),
      position: Offset(json['x'], json['y']),
      size: Size(json['w'], json['h']),
      rotation: (json['rotation'] ?? 0).toDouble(),
      table: json['table'] != null ? TableModel.fromJson(json['table']) : null,
    );
  }
}
