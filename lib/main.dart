import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Layout MVP',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      home: const LayoutHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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

class Table {
  final String id;
  String name;
  TableStatus status;
  int capacity;
  List<int> distribution;

  Table({
    required this.id,
    required this.name,
    this.status = TableStatus.free,
    this.capacity = 0,
    this.distribution = const [0, 0, 0, 0],
  });
}

/// 画布上一个物体
class ShapeModel {
  final String id;
  final ShapeType type;
  Offset position; // 世界坐标（未缩放）
  Size size; // 世界尺寸
  double rotation; // 弧度
  bool selected;
  Table? table;

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

class LayoutHomePage extends StatefulWidget {
  const LayoutHomePage({super.key});

  @override
  State<LayoutHomePage> createState() => _LayoutHomePageState();
}
 const double grid = 40; // 网格间距（世界单位）

class _LayoutHomePageState extends State<LayoutHomePage> {
  // 画布逻辑大小（世界坐标）
  final Size worldSize = const Size(2000, 1200);
  double worldExtent = 8000; // 8k x 8k，看起来就像无限

  // 网格设置

  // 变换控制器（用于缩放/平移）
  final TransformationController _tc = TransformationController();

  // 物体集合
  final List<ShapeModel> shapes = [];

  // 选中 ID
  String? selectedId;

  @override
  void initState() {
    super.initState();
  }

  // 将屏幕像素位移转换为世界位移（考虑当前缩放）
  Offset _deltaToWorld(Offset screenDelta) {
    final scale = _tc.value.getMaxScaleOnAxis();
    return screenDelta / scale;
  }

  // 吸附到网格
  Offset _snap(Offset p, ShapeType type) {
    double step = 0.5;
    if (type == ShapeType.chair) {
      step = 0.1;
    }
    double sx = (p.dx / grid / step).roundToDouble() * step * grid;
    double sy = (p.dy / grid / step).roundToDouble() * step * grid;
    return Offset(sx, sy);
  }

  void _addShape(ShapeType type) {
    final id = 's${DateTime.now().microsecondsSinceEpoch}';
    final base = const Offset(200, 200);
    final Size sz;
    Table? table;
    switch (type) {
      case ShapeType.tableRound:
        sz = const Size(grid * 2, grid * 2);
        break;
      case ShapeType.tableRect:
        sz = const Size(grid * 2, grid * 2);
        // loop status , choose random
        final status = TableStatus.values[math.Random().nextInt(TableStatus.values.length)];
        final capacity = 4;
        final distribution = [1, 1, 1, 1];

        table = Table(
          id: id,
          name: "A${math.Random().nextInt(100)}",
          status: status,
          capacity: capacity,
          distribution: distribution,
        );
        break;
      case ShapeType.chair:
        sz = Size(grid * 0.8, grid / 3);
        break;

      case ShapeType.booth:
        sz = Size(grid * 1, grid * 4);
        break;
      case ShapeType.window:
        sz = Size(grid * 3, grid / 2);
        break;
      case ShapeType.pillar:
        sz = Size(grid, grid);
        break;
      // 结构类

      case ShapeType.door:
        sz = Size(grid, grid * 2);
        break;
      case ShapeType.wall:
        sz = Size(grid / 4, grid * 5);
        break;
      case ShapeType.kitchen:
        sz = Size(grid * 6, grid * 4);
        break;
      case ShapeType.restroom:
        sz = Size(grid * 3, grid * 4);
        break;

      // 业务类
      case ShapeType.cashier:
        sz = Size(grid * 2, grid);
        break;
      case ShapeType.barCounter:
        sz = Size(grid * 2, grid * 4);
        break;
      case ShapeType.queueArea:
        sz = Size(grid * 4, grid * 4);
        break;

      // 辅助类
      case ShapeType.label:
      case ShapeType.arrow:
      case ShapeType.decoration:
        sz = Size(grid * 2, grid);
        break;
    }

    setState(() {
      shapes.add(ShapeModel(id: id, type: type, position: _snap(base, type), size: sz, table: table));
      selectedId = id;
    });
  }

  void _deleteSelected() {
    if (selectedId == null) return;
    setState(() {
      shapes.removeWhere((s) => s.id == selectedId);
      selectedId = null;
    });
  }

  void _resetView() {
    setState(() {
      _tc.value = Matrix4.identity();
    });
  }

  void _editTableSizeDialog(ShapeModel shape) {
    final widthCtrl = TextEditingController(text: (shape.size.width / grid).toStringAsFixed(0));
    final heightCtrl = TextEditingController(text: (shape.size.height / grid).toStringAsFixed(0));
    final nameCtrl = TextEditingController(text: shape.table?.name);
    final capacityCtrl = TextEditingController(text: shape.table?.capacity.toString());

    // set sets left/top/right/bottom distribution

    final leftCtrl = TextEditingController(text: shape.table?.distribution[0].toString());
    final topCtrl = TextEditingController(text: shape.table?.distribution[1].toString());
    final rightCtrl = TextEditingController(text: shape.table?.distribution[2].toString());
    final bottomCtrl = TextEditingController(text: shape.table?.distribution[3].toString());

    // TODO: max is the max of left/top/right/bottom
    final max = shape.table?.capacity ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置桌子尺寸（格）'),
          content:SingleChildScrollView(child:  Column(

            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称', hintText: '例如：c1、t05、包间1'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '宽'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '长'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '容量'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: leftCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '左'),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: topCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '上'),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: rightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '右'),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: bottomCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '下'),
                    ),
                  ),
                ],
              ),
            ],
          ),),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(
              onPressed: () {
                final w = double.tryParse(widthCtrl.text) ?? 1;
                final h = double.tryParse(heightCtrl.text) ?? 1;
                final left = int.tryParse(leftCtrl.text) ?? 0;
                final top = int.tryParse(topCtrl.text) ?? 0;
                final right = int.tryParse(rightCtrl.text) ?? 0;
                final bottom = int.tryParse(bottomCtrl.text) ?? 0;
                final capacity = int.tryParse(capacityCtrl.text) ?? 0;
                if (left + top + right + bottom > max) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('左上右下之和不能大于容量')));
                  return;
                }
                setState(() {
                  shape.size = Size(grid * w, grid * h);
                  shape.table?.name = nameCtrl.text.trim();
                  shape.table?.distribution = [left, top, right, bottom];
                  shape.table?.capacity = capacity;
                });
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('餐厅布局（缩放/网格/拖拽）'),
        actions: [
          IconButton(tooltip: '重置视图', onPressed: _resetView, icon: const Icon(Icons.center_focus_strong)),
          IconButton(tooltip: '删除选中', onPressed: _deleteSelected, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Row(
        children: [
          // 左侧工具栏
          _buildToolbox(),
          const VerticalDivider(width: 1),
          // 右侧画布
          Expanded(child: _buildCanvas()),
        ],
      ),
    );
  }

  Widget _buildToolbox() {
    return Container(
      width: 88,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text('组件', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ToolButton(label: '圆桌', icon: Icons.circle_outlined, onTap: () => _addShape(ShapeType.tableRound)),
          _ToolButton(label: '方桌', icon: Icons.rectangle_outlined, onTap: () => _addShape(ShapeType.tableRect)),
          // _ToolButton(label: '椅子', icon: Icons.chair_outlined, onTap: () => _addShape(ShapeType.chair)),
          _ToolButton(label: 'cashier', icon: Icons.countertops, onTap: () => _addShape(ShapeType.cashier)),
          _ToolButton(label: 'Wall', icon: Icons.rectangle_outlined, onTap: () => _addShape(ShapeType.wall)),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('提示：两指缩放/拖动画布 拖拽组件移动，自动网格吸附', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: 0.3,
            maxScale: 3.5,
            boundaryMargin: const EdgeInsets.all(10000),
            constrained: false,
            child: SizedBox(
              width: worldExtent,
              height: worldExtent,
              child: Stack(
                children: [
                  // 背景网格
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(worldExtent, worldExtent),
                      painter: GridPainter(grid: grid, worldSize: Size(worldExtent, worldExtent)),
                    ),
                  ), // 物体层
                  ...shapes.map(_buildShapeWidget),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShapeWidget(ShapeModel s) {
    final isSelected = s.id == selectedId;
    final Widget shapeVisual;
    switch (s.type) {
      case ShapeType.tableRound:
        shapeVisual = _RoundTable(size: s.size, selected: isSelected);
        break;
      case ShapeType.tableRect:
        shapeVisual = _RectTable(shapeModel: s, selected: isSelected);
        break;
      case ShapeType.chair:
        shapeVisual = _Chair(size: s.size, selected: isSelected);
        break;
      case ShapeType.cashier:
        shapeVisual = _Cashier(size: s.size, selected: isSelected);
        break;
      case ShapeType.wall:
        shapeVisual = _Wall(size: s.size, selected: isSelected);
        break;
      default:
        shapeVisual = _GenericBox(shape: s, selected: isSelected);
        break;
    }

    return Positioned(
      left: s.position.dx,
      top: s.position.dy,
      child: Listener(
        onPointerDown: (_) {
          setState(() {
            selectedId = s.id;
          });
        },
        child: GestureDetector(
          onPanStart: (_) {
            setState(() => selectedId = s.id);
          },

          onLongPress: () {
            if (s.type == ShapeType.tableRect) {
              _editTableSizeDialog(s);
            }
          },

          onPanUpdate: (details) {
            // 将屏幕像素增量变为世界增量（考虑缩放）
            final worldDelta = _deltaToWorld(details.delta);
            setState(() {
              s.position += worldDelta;
            });
          },
          onPanEnd: (_) {
            // 放手时吸附网格
            setState(() {
              s.position = _snap(s.position, s.type);
            });
          },
          onDoubleTap: () {
            // 双击旋转 15° 作为示例math.pi / 12;
            //45° 的弧度 = π / 4
            setState(() {
              s.rotation += math.pi / 4;
            });
          },
          child: Transform.rotate(angle: s.rotation, child: shapeVisual),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 背景网格：根据当前缩放自动绘制细/粗线
class GridPainter extends CustomPainter {
  final double grid; // 基础网格间距（世界）
  final Size worldSize;

  GridPainter({required this.grid, required this.worldSize});

  @override
  void paint(Canvas canvas, Size size) {
    // 背景
    final bg = Paint()..color = const Color(0xFFF8F9FA);
    canvas.drawRect(Offset.zero & worldSize, bg);

    // 线条
    final thin =
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1;
    final bold =
        Paint()
          ..color = const Color(0xFFD0D7E2)
          ..strokeWidth = 1.5;

    for (double x = 0; x <= worldSize.width; x += grid) {
      final isBold = (x / grid) % 5 == 0;
      canvas.drawLine(Offset(x, 0), Offset(x, worldSize.height), isBold ? bold : thin);
    }
    for (double y = 0; y <= worldSize.height; y += grid) {
      final isBold = (y / grid) % 5 == 0;
      canvas.drawLine(Offset(0, y), Offset(worldSize.width, y), isBold ? bold : thin);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundTable extends StatelessWidget {
  final Size size;
  final bool selected;

  const _RoundTable({required this.size, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.teal : Colors.teal.shade300;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: const Text('圆桌'),
    );
  }
}

Color getColor(TableStatus status) {
  return switch (status) {
    TableStatus.free => Colors.green,
    TableStatus.reserved => Colors.orange,
    TableStatus.occupied => Colors.red,
    TableStatus.disabled => Colors.grey,
  };
}


enum Side { top, right, bottom, left }

/// Build chairs for a given side
List<Widget> buildSideChairs(int count, Side side, Color color) {
  if (count == 0) return [];

  return List.generate(count, (index) {
    double spacing = 1 / (count + 1);

    Alignment alignment;
    // left should has gap to the right and top should has gap to the bottom
    BorderRadiusGeometry? borderRadius;
    double width = grid * 0.75;
    double height = grid * 0.5;
    const double gapFromTable = 5; // distance away from table
    const double betweenChairs = 5; // distance between chairs on same side
    Offset translateOffset;
    double positionOffset = (index - (count - 1) / 2) * betweenChairs;

    // l t r b
    switch (side) {
      case Side.top:
        alignment = Alignment(-1 + (index + 1) * 2 * spacing, -1);
        translateOffset = Offset(positionOffset, -gapFromTable);
        print("top alignment $alignment $translateOffset");
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        );
        break;
      case Side.right:
        alignment = Alignment(1, -1 + (index + 1) * 2 * spacing);
        width =  grid * 0.5;
        height =  grid * 0.75;
        translateOffset = Offset(gapFromTable, positionOffset);
        print("right alignment $alignment $translateOffset");
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(25),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(25),
        );
        break;
      case Side.bottom:
        alignment = Alignment(-1 + (index + 1) * 2 * spacing, 1);
        print("bottom alignment $alignment $spacing");
        translateOffset = Offset(positionOffset, gapFromTable);
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        );
        break;
      case Side.left:
        alignment = Alignment(-1, -1 + (index + 1) * 2 * spacing);
        width =  grid * 0.5;
        height =  grid * 0.75;
        translateOffset = Offset(-gapFromTable, positionOffset);
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(5),
        );
        break;
    }

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: translateOffset,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: borderRadius),
        ),
      ),
    );
  });
}

class _RectTable extends StatelessWidget {
  final ShapeModel shapeModel;
  final bool selected;

  const _RectTable({required this.shapeModel, required this.selected});

  @override
  Widget build(BuildContext context) {
    final statusColor = getColor(shapeModel.table?.status ?? TableStatus.free);
    final color = selected ? statusColor : statusColor.withOpacity(0.8);
    final distribution = shapeModel.table?.distribution ?? [0, 0, 0, 0];

    final double tableW = shapeModel.size.width;
    final double tableH = shapeModel.size.height;
    final double scale = 1.5;
    final double shortSide = tableW < tableH ? tableW : tableH;
    double factor = shortSide * scale - shortSide;
    print("tableW. $tableW =$tableH $factor");
    if((tableW == grid && tableH == grid *2)  || (tableW == grid *2 && tableH == grid ) ){
      factor += 20;
    }

    return Container(
      width: tableW + factor,
      height: tableH + factor,
      // color: Colors.red,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...buildSideChairs(distribution[0], Side.left, statusColor),
          ...buildSideChairs(distribution[1], Side.top, statusColor),
          ...buildSideChairs(distribution[2], Side.right, statusColor),
          ...buildSideChairs(distribution[3], Side.bottom, statusColor),
          Container(
            width: shapeModel.size.width,
            height: shapeModel.size.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.18),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (shapeModel.table?.name ?? "").isNotEmpty ? (shapeModel.table?.name ?? "") : shapeModel.type.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                SizedBox(height: 10),

                Text("${shapeModel.table?.status.name}".toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chair extends StatelessWidget {
  final Size size;
  final bool selected;

  const _Chair({required this.size, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.grey : Colors.grey.shade400;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(50),
          topRight: Radius.circular(50),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
        color: color.withOpacity(0.9),
        // border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(""),
    );
  }
}

class _Wall extends StatelessWidget {
  final Size size;
  final bool selected;

  const _Wall({required this.size, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.indigo : Colors.indigo.shade400;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Cashier extends StatelessWidget {
  final Size size;
  final bool selected;

  const _Cashier({required this.size, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.indigo : Colors.indigo.shade400;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text('收银台'),
    );
  }
}

class _GenericBox extends StatelessWidget {
  final ShapeModel shape;
  final bool selected;

  const _GenericBox({required this.shape, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: shape.size.width,
      height: shape.size.height,
      decoration: BoxDecoration(
        color: selected ? Colors.grey.withOpacity(0.2) : Colors.white,
        border: Border.all(color: selected ? Colors.blue : Colors.grey.shade400, width: selected ? 2 : 1),
      ),
      alignment: Alignment.center,
      child: Text(shape.type.name, style: const TextStyle(fontSize: 10)),
    );
  }
}

class InfiniteGridPainter extends CustomPainter {
  final double grid;

  InfiniteGridPainter({required this.grid});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line =
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1;

    final Paint bold =
        Paint()
          ..color = const Color(0xFFD0D7E2)
          ..strokeWidth = 1.5;

    // 获取当前画布的视图变换矩阵
    final transform = canvas.getSaveCount();
    // 理论上可以结合 TransformationController 来获取偏移量
    // 不过更常见的是直接绘制一大片，然后靠 InteractiveViewer 平移/缩放

    // 绘制一个大区域（比如 -5000~5000）即可近似无限
    const double extent = 5000;
    for (double x = -extent; x <= extent; x += grid) {
      final isBold = (x / grid) % 5 == 0;
      canvas.drawLine(Offset(x, -extent), Offset(x, extent), isBold ? bold : line);
    }
    for (double y = -extent; y <= extent; y += grid) {
      final isBold = (y / grid) % 5 == 0;
      canvas.drawLine(Offset(-extent, y), Offset(extent, y), isBold ? bold : line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
