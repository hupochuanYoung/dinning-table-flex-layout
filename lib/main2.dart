import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class GridViewPort extends StatefulWidget {
  @override
  _GridViewPortState createState() => _GridViewPortState();
}

class _GridViewPortState extends State<GridViewPort> {
  Offset offset = Offset.zero;
  double scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          offset += details.delta;
        });
      },
      onScaleUpdate: (details) {
        setState(() {
          scale = (scale * details.scale).clamp(0.2, 5.0);
        });
      },
      child: CustomPaint(size: Size.infinite, painter: InfiniteGridPainter(gridSize: 40, offset: offset, scale: scale)),
    );
  }
}

void main() {
  runApp(const DiningRoomScreen());
}

class PosDiningTableApp extends StatelessWidget {
  const PosDiningTableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: DiningRoomScreen());
  }
}

class _DiningRoomScreenState extends State<DiningRoomScreen> {
  double gridSize = 50.0;
  int gridCols = 20;
  int gridRows = 15;
  final double minGridSize = 20.0;
  final double maxGridSize = 100.0;

  void _zoomIn() {
    setState(() {
      gridSize = (gridSize + 5).clamp(minGridSize, maxGridSize);
    });
  }

  void _zoomOut() {
    setState(() {
      gridSize = (gridSize - 5).clamp(minGridSize, maxGridSize);
    });
  }

  List<LayoutElement> elements = [];

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("layout_all_components");
    if (data != null) {
      final decoded = jsonDecode(data) as List;
      setState(() {
        elements = decoded.map((e) => LayoutElement.fromJson(e)).toList();
      });
    } else {
      // 默认放两个
      elements = [
        LayoutElement(id: "T1", type: ElementType.table, gridX: 2, gridY: 2, gridW: 2, gridH: 1),
        LayoutElement(id: "W1", type: ElementType.window, gridX: 1, gridY: 1, gridW: 1, gridH: 2),
      ];
    }
  }

  Future<void> _saveLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(elements.map((e) => e.toJson()).toList());
    await prefs.setString("layout_all_components", data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("布局已保存")));
  }

  Offset offset = Offset.zero;
  double scale = 1.0;
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("餐厅布局编辑器"),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveLayout)],
      ),
      body: Row(
        children: [
          // 左边画布，占满可用空间
          Expanded(
            flex: 3,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 2.0,
              boundaryMargin: const EdgeInsets.all(double.infinity), // allow infinite panning
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: GridPaper(
                      color: Colors.black26,
                      divisions: 1,
                      interval: 200,

                    ),
                  ),
                  // GestureDetector(
                  //   onPanUpdate: (details) {
                  //     setState(() {
                  //       offset += details.delta;
                  //     });
                  //   },
                  //   // onScaleUpdate: (details) {
                  //   //   setState(() {
                  //   //     scale = (scale * details.scale).clamp(0.2, 5.0);
                  //   //   });
                  //   // },
                  //   child: CustomPaint(
                  //     size: Size.infinite,
                  //     painter: InfiniteGridPainter(gridSize: 40, offset: offset, scale: scale),
                  //   ),
                  // ),
                  // CustomPaint(size: const Size(5000, 5000), painter: GridPainter(gridSize: 30)),
                  ...elements.map((e) {
                    return Positioned(
                      left: e.gridX * gridSize,
                      top: e.gridY * gridSize,
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          setState(() {
                            final gx = ((e.gridX * gridSize + d.delta.dx) / gridSize).round();
                            final gy = ((e.gridY * gridSize + d.delta.dy) / gridSize).round();
                            e.gridX = gx.clamp(0, gridCols - e.gridW);
                            e.gridY = gy.clamp(0, gridRows - e.gridH);
                          });
                        },
                        onLongPress: () {
                          setState(() {
                            elements.remove(e);
                          });
                        },
                        child: CustomPaint(
                          size: Size(e.gridW * gridSize, e.gridH * gridSize),
                          painter: ElementPainter(e),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 右边属性面板
          Expanded(flex: 1, child: _buildEditor()),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(heroTag: "zoom_in", mini: true, onPressed: _zoomIn, child: const Icon(Icons.zoom_in)),
        const SizedBox(height: 8),
        FloatingActionButton(heroTag: "zoom_out", mini: true, onPressed: _zoomOut, child: const Icon(Icons.zoom_out)),
        const SizedBox(height: 8),
        PopupMenuButton<ElementType>(
          icon: const Icon(Icons.add),
          onSelected: (t) {
            setState(() {
              elements.add(
                LayoutElement(
                  id: "${t.name}-${elements.length + 1}",
                  type: t,
                  gridX: 1,
                  gridY: 1,
                  gridW: t == ElementType.table ? 2 : 2,
                  gridH: t == ElementType.table ? 1 : 1,
                ),
              );
            });
          },
          itemBuilder:
              (ctx) => const [
                PopupMenuItem(value: ElementType.table, child: Text("新增桌子")),
                PopupMenuItem(value: ElementType.window, child: Text("新增窗户")),
                PopupMenuItem(value: ElementType.cashier, child: Text("新增收银台")),
                PopupMenuItem(value: ElementType.wall, child: Text("新增墙壁")),
              ],
        ),
      ],
    );
  }

  /// 右边属性编辑器
  Widget _buildEditor() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children:
          elements.map((e) {
            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${e.id} (${e.type.name})", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Text("宽:"),
                        SizedBox(
                          width: 40,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(text: e.gridW.toString()),
                            onSubmitted: (v) => setState(() => e.gridW = int.tryParse(v) ?? e.gridW),
                          ),
                        ),
                        const Text(" 高:"),
                        SizedBox(
                          width: 40,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(text: e.gridH.toString()),
                            onSubmitted: (v) => setState(() => e.gridH = int.tryParse(v) ?? e.gridH),
                          ),
                        ),
                      ],
                    ),
                    if (e.type == ElementType.table) ...[
                      const SizedBox(height: 8),
                      _edgeField("top", e),
                      _edgeField("bottom", e),
                      _edgeField("left", e),
                      _edgeField("right", e),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _edgeField(String edge, LayoutElement e) {
    return Row(
      children: [
        Text("$edge:"),
        SizedBox(
          width: 40,
          child: TextField(
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: e.edgeSeats[edge].toString()),
            onSubmitted: (v) => setState(() => e.edgeSeats[edge] = int.tryParse(v) ?? 0),
          ),
        ),
      ],
    );
  }
}

/// ====== 网格背景 ======
// class GridPainter extends CustomPainter {
//   final double gridSize;
//   GridPainter({required this.gridSize});
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint =
//         Paint()
//           ..color = Colors.grey.shade300
//           ..strokeWidth = 1;
//
//     // draw vertical lines
//     for (double x = 0; x <= size.width; x += gridSize) {
//       canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
//     }
//
//     // draw horizontal lines
//     for (double y = 0; y <= size.height; y += gridSize) {
//       canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

class InfiniteGridPainter extends CustomPainter {
  final double gridSize; // base grid cell size in world units
  final Offset offset; // pan offset in world units
  final double scale; // zoom factor (>= 0.1)

  InfiniteGridPainter({required this.gridSize, required this.offset, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = Colors.grey.shade300
          ..strokeWidth = 1.0;

    final double step = gridSize * scale;
    if (step < 2) return; // too dense to draw

    // Calculate the world rect visible on screen
    final double left = -offset.dx / scale;
    final double top = -offset.dy / scale;
    final double right = left + size.width / scale;
    final double bottom = top + size.height / scale;

    // Find nearest grid lines
    final double startX = (left / gridSize).floor() * gridSize;
    final double endX = (right / gridSize).ceil() * gridSize;
    final double startY = (top / gridSize).floor() * gridSize;
    final double endY = (bottom / gridSize).ceil() * gridSize;

    // Draw vertical lines
    for (double x = startX; x <= endX; x += gridSize) {
      final dx = (x * scale) + offset.dx;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = startY; y <= endY; y += gridSize) {
      final dy = (y * scale) + offset.dy;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant InfiniteGridPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.scale != scale || oldDelegate.gridSize != gridSize;
  }
}

/// ====== 元素绘制 ======
class ElementPainter extends CustomPainter {
  final LayoutElement e;
  ElementPainter(this.e);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = switch (e.type) {
            ElementType.table => Colors.brown,
            ElementType.window => Colors.blueGrey,
            ElementType.cashier => Colors.orange,
            ElementType.wall => Colors.black54,
          };

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (e.type == ElementType.table) {
      _drawSeats(canvas, size, e);
    }

    final tp = TextPainter(
      text: TextSpan(text: e.id, style: const TextStyle(color: Colors.white)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
  }

  void _drawSeats(Canvas canvas, Size size, LayoutElement e) {
    final paint = Paint()..color = Colors.black;
    const r = 5.0, offset = 10.0;

    void drawEdge(int n, bool horizontal, bool isTopOrLeft) {
      if (n <= 0) return;
      final gap = (horizontal ? size.width : size.height) / (n + 1);
      for (int i = 1; i <= n; i++) {
        if (horizontal) {
          final x = gap * i;
          final y = isTopOrLeft ? -offset : size.height + offset;
          canvas.drawCircle(Offset(x, y), r, paint);
        } else {
          final y = gap * i;
          final x = isTopOrLeft ? -offset : size.width + offset;
          canvas.drawCircle(Offset(x, y), r, paint);
        }
      }
    }

    drawEdge(e.edgeSeats["top"] ?? 0, true, true);
    drawEdge(e.edgeSeats["bottom"] ?? 0, true, false);
    drawEdge(e.edgeSeats["left"] ?? 0, false, true);
    drawEdge(e.edgeSeats["right"] ?? 0, false, false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ====== 数据模型 ======
enum ElementType { table, window, cashier, wall }

class LayoutElement {
  String id;
  ElementType type;
  int gridX, gridY;
  int gridW, gridH;
  Map<String, int> edgeSeats;

  LayoutElement({
    required this.id,
    required this.type,
    this.gridX = 0,
    this.gridY = 0,
    this.gridW = 2,
    this.gridH = 1,
    Map<String, int>? edgeSeats,
  }) : edgeSeats = edgeSeats ?? {"top": 0, "bottom": 0, "left": 0, "right": 0};

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type.name,
    "gridX": gridX,
    "gridY": gridY,
    "gridW": gridW,
    "gridH": gridH,
    "edgeSeats": edgeSeats,
  };

  factory LayoutElement.fromJson(Map<String, dynamic> json) => LayoutElement(
    id: json["id"],
    type: ElementType.values.firstWhere((t) => t.name == json["type"]),
    gridX: json["gridX"],
    gridY: json["gridY"],
    gridW: json["gridW"],
    gridH: json["gridH"],
    edgeSeats: Map<String, int>.from(json["edgeSeats"]),
  );
}
