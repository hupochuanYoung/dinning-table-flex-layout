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
enum ShapeType { tableRound, tableRect, chair, wall, cashier, pillar, kitchen }

/// 画布上一个物体
class ShapeModel {
  final String id;
  final ShapeType type;
  Offset position; // 世界坐标（未缩放）
  Size size; // 世界尺寸
  double rotation; // 弧度
  bool selected;

  ShapeModel({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.selected = false,
  });
}

class LayoutHomePage extends StatefulWidget {
  const LayoutHomePage({super.key});

  @override
  State<LayoutHomePage> createState() => _LayoutHomePageState();
}

class _LayoutHomePageState extends State<LayoutHomePage> {
  // 画布逻辑大小（世界坐标）
  final Size worldSize = const Size(2000, 1200);

  // 网格设置
  static const double grid = 40; // 网格间距（世界单位）

  // 变换控制器（用于缩放/平移）
  final TransformationController _tc = TransformationController();

  // 物体集合
  final List<ShapeModel> shapes = [];

  // 选中 ID
  String? selectedId;

  @override
  void initState() {
    super.initState();
    _seedDemo();
  }

  void _seedDemo() {
    shapes.addAll([
      ShapeModel(id: 't1', type: ShapeType.tableRound, position: const Offset(400, 300), size: const Size(140, 140)),
      ShapeModel(id: 't2', type: ShapeType.tableRect, position: const Offset(700, 280), size: const Size(220, 120)),
      ShapeModel(id: 'c1', type: ShapeType.chair, position: const Offset(360, 240), size: const Size(50, 50)),
      ShapeModel(id: 'c2', type: ShapeType.chair, position: const Offset(540, 360), size: const Size(50, 50)),
    ]);
  }

  // 将屏幕像素位移转换为世界位移（考虑当前缩放）
  Offset _deltaToWorld(Offset screenDelta) {
    final scale = _tc.value.getMaxScaleOnAxis();
    return screenDelta / scale;
  }

  // 吸附到网格
  Offset _snap(Offset p, ShapeType type) {
    double step = 1;
    if (type == ShapeType.chair) {
      step = 0.5;
    }
    double sx = (p.dx / grid / step).roundToDouble() * step * grid;
    double sy = (p.dy / grid / step).roundToDouble() * step * grid;
    return Offset(sx, sy);
  }

  void _addShape(ShapeType type) {
    final id = 's${DateTime.now().microsecondsSinceEpoch}';
    final base = const Offset(200, 200);
    final Size sz;
    switch (type) {
      case ShapeType.tableRound:
        sz = const Size(grid * 2, grid * 2);
        break;
      case ShapeType.tableRect:
        sz = const Size(grid * 2, grid * 2);
        break;
      case ShapeType.chair:
        sz = Size(grid, grid);
        break;
      case ShapeType.cashier:
        sz = Size(grid*2, grid);
        break;
      case ShapeType.wall:
        sz = Size(grid, grid*5);
        break;     default:
        sz = const Size(grid * 2, grid * 2);
        break;

    }
    setState(() {
      shapes.add(ShapeModel(id: id, type: type, position: _snap(base, type), size: sz));
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
          _ToolButton(label: '椅子', icon: Icons.chair_outlined, onTap: () => _addShape(ShapeType.chair)),
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
            boundaryMargin: const EdgeInsets.all(2000),
            constrained: false,
            child: Stack(
              children: [
                // 背景网格
                CustomPaint(painter: GridPainter(grid: grid, worldSize: worldSize), size: worldSize),
                // 物体层
                ...shapes.map(_buildShapeWidget),
              ],
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
        shapeVisual = _RectTable(size: s.size, selected: isSelected);
        break;
      case ShapeType.chair:
        shapeVisual = _Chair(size: s.size, selected: isSelected);
        break;
      case ShapeType.cashier:
        shapeVisual = _Cashier(size: s.size, selected: isSelected);
        break;
      case ShapeType.wall:
        shapeVisual = _Wall(size: s.size, selected: isSelected);
        break;  default:
        shapeVisual = _Wall(size: s.size, selected: isSelected);
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
            // 双击旋转 15° 作为示例
            setState(() {
              s.rotation += math.pi / 12;
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

class _RectTable extends StatelessWidget {
  final Size size;
  final bool selected;

  const _RectTable({required this.size, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.orange : Colors.orange.shade400;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(0.18),
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: const Text('方桌'),
    );
  }
}

class _Chair extends StatelessWidget {
  final Size size;
  final bool selected;

  const _Chair({required this.size, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.indigo : Colors.indigo.shade400;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.18),
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: const Text('椅'),
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
        border: Border.all(color:color, width: 2),
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
        color:color.withOpacity(0.18),
        border: Border.all(color:color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text('收银台'),
    );
  }
}

