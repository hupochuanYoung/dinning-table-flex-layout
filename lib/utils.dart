import 'dart:io';
import 'dart:convert';
import 'package:demo_dinning_table/table_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<String> _getLayoutFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/layout.json';
}

Future<void> saveLayout(List<ShapeModel> shapes,context) async {
  final file = File(await _getLayoutFilePath());
  final jsonData = jsonEncode(shapes.map((e) => e.toJson()).toList());
  await file.writeAsString(jsonData);
  String text = '✅ Layout saved to ${file.path}';
  ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(text)));

}

Future<List<ShapeModel>> loadLayout(context) async {
  final file = File(await _getLayoutFilePath());
  if (!await file.exists()) return [];
  final jsonData = await file.readAsString();
  final decoded = jsonDecode(jsonData) as List;
  ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("ok")));
  return decoded.map((e) => ShapeModelJson.fromJson(e)).toList();

}
