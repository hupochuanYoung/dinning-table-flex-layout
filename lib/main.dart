import 'dart:math' as math;
import 'package:demo_dinning_table/table_model.dart';
import 'package:demo_dinning_table/utils.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

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

  // 变换控制器（用于缩放/平移）
  final TransformationController _tc = TransformationController();

  // 物体集合
  final List<ShapeModel> shapes = [];

  // 选中 ID
  // String? selectedId;
  bool isMultiSelectMode = false;
  final Set<String> selectedIds = {};
  final Map<String, Offset> _initialPositions = {};
  Offset _cumulativeDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
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

  void _addShape(ShapeType type, {int? capacity, Size? customSize, List<int>? distribution}) {
    final id = 's${DateTime.now().microsecondsSinceEpoch}';
    // final base = const Offset(200, 200);
    // 1️⃣ 获取当前视口尺寸
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size viewportSize = box.size;

    // 2️⃣ 计算屏幕中心点（逻辑坐标）
    final Offset viewportCenter = Offset(
      viewportSize.width / 2,
      viewportSize.height / 2,
    );

    final vm.Vector3 worldVec = vm.Matrix4.inverted(_tc.value).transform3(
      vm.Vector3(viewportCenter.dx, viewportCenter.dy, 0),
    );

    final Offset base = Offset(worldVec.x, worldVec.y);

    final Size sz;
    TableModel? table;
    switch (type) {
      case ShapeType.tableRound:
        sz = const Size(grid * 2, grid * 2);
        break;
      case ShapeType.tableRect:
        sz = customSize ?? const Size(grid * 2, grid * 2);
        // loop status , choose random
        final status = TableStatus.values[math.Random().nextInt(TableStatus.values.length)];
        final tableCapacity = capacity ?? 2;
        final tableDistribution = distribution ?? [0, 1, 0, 1];

        table = TableModel(
          id: id,
          name: "A${math.Random().nextInt(100)}",
          status: status,
          capacity: tableCapacity,
          distribution: tableDistribution,
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
    });
  }

  void _deleteSelected() {
    if (selectedIds.isEmpty) return;
    setState(() {
      shapes.removeWhere((s) => selectedIds.contains(s.id));
      selectedIds.clear();
      _initialPositions.clear();
    });
    // setState(() {
    //   shapes.removeWhere((s) => s.id == selectedId);
    //   selectedId = null;
    // });
  }

  void _deleteShape(String id) {
    setState(() {
      shapes.removeWhere((s) => s.id == id);
      selectedIds.remove(id);
      _initialPositions.remove(id);
    });
  }

  void _duplicateShape(ShapeModel original) {
    final id = 's${DateTime.now().microsecondsSinceEpoch}';
    TableModel? newTable;
    if (original.table != null) {
      newTable = TableModel(
        id: id,
        name: original.table!.name,
        status: original.table!.status,
        capacity: original.table!.capacity,
        distribution: List.from(original.table!.distribution),
      );
    }
    setState(() {
      shapes.add(
        ShapeModel(
          id: id,
          type: original.type,
          position: original.position + const Offset(20, 20),
          // Offset the duplicate
          size: original.size,
          rotation: original.rotation,
          table: newTable,
        ),
      );
    });
  }

  void _showTableSizeMenu(BuildContext context, Offset globalPosition) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<Map<String, dynamic>>(
      context: context,
      position: RelativeRect.fromRect(globalPosition & const Size(40, 40), Offset.zero & overlay.size),
      items: [
        PopupMenuItem<Map<String, dynamic>>(
          value: {
            'capacity': 2,
            'size': Size(grid * 2, grid * 2),
            'distribution': [0, 1, 0, 1],
          },
          child: Text('2人桌 (2×2)'),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {
            'capacity': 4,
            'size': Size(grid * 3, grid * 2),
            'distribution': [0, 2, 0, 2],
          },
          child: Text('4人桌 (3×2)'),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {
            'capacity': 4,
            'size': Size(grid * 2, grid * 3),
            'distribution': [2, 0, 2, 0],
          },
          child: Text('4人桌 (2×3)'),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {
            'capacity': 6,
            'size': Size(grid * 2, grid * 4),
            'distribution': [2, 1, 2, 1],
          },
          child: Text('6人桌 (3×4)'),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {
            'capacity': 8,
            'size': Size(grid * 4, grid * 2),
            'distribution': [1, 3, 1, 3],
          },
          child: Text('8人桌 (3×3)'),
        ),
        PopupMenuItem<Map<String, dynamic>>(
          value: {
            'capacity': 12,
            'size': Size(grid * 3, grid * 6),
            'distribution': [4, 2, 4, 2],
          },
          child: Text('12人桌 (4×6)'),
        ),
      ],
    );

    if (result != null) {
      _addShape(
        ShapeType.tableRect,
        capacity: result['capacity'] as int,
        customSize: result['size'] as Size,
        distribution: result['distribution'] as List<int>,
      );
    }
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置桌子尺寸（格）'),
          content: SingleChildScrollView(
            child: Column(
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
            ),
          ),
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
                if (left + top + right + bottom > capacity) {
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
        title: Text('餐厅布局 ${isMultiSelectMode ? selectedIds : ""}'),
        actions: [

          IconButton(
            tooltip: '保存布局',
            icon: const Icon(Icons.save),
            onPressed: () => saveLayout(shapes,context),
          ),
          IconButton(
            tooltip: '加载布局',
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              final loaded = await loadLayout(context);
              setState(() {
                shapes
                  ..clear()
                  ..addAll(loaded);
              });
            },
          ),

          // Multi-select toggle button
          IconButton(
            tooltip: isMultiSelectMode ? '关闭多选模式' : '开启多选模式',
            onPressed: () {
              setState(() {
                isMultiSelectMode = !isMultiSelectMode;
                // Clear selections when switching modes
                selectedIds.clear();
                _initialPositions.clear();
              });
            },
            icon: Icon(
              isMultiSelectMode ? Icons.check_box : Icons.check_box_outline_blank,
              color: isMultiSelectMode ? Colors.teal : null,
            ),
          ),
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
          Builder(
            builder:
                (ctx) => _ToolButton(
                  label: '方桌',
                  icon: Icons.rectangle_outlined,
                  onTap: () {
                    final RenderBox box = ctx.findRenderObject() as RenderBox;
                    final position = box.localToGlobal(Offset.zero);
                    _showTableSizeMenu(context, position + Offset(box.size.width, 0));
                  },
                ),
          ),
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
          child: GestureDetector(
            // Click on empty space to clear all selections (only in multi-select mode)
            onTapDown: (details) {
              if (isMultiSelectMode) {
                setState(() {
                  selectedIds.clear();
                  _initialPositions.clear();
                });
              }
            },
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
          ),
        );
      },
    );
  }

  Widget _buildShapeWidget(ShapeModel s) {
    bool isSelected = true;
    if (isMultiSelectMode) {
      isSelected = selectedIds.contains(s.id);
    }

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
      child: GestureDetector(
        // Prevent tap from propagating to canvas background
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Only handle tap in multi-select mode
          if (!isMultiSelectMode) return;

          // Toggle selection on tap
          if (selectedIds.contains(s.id)) {
            selectedIds.remove(s.id);
            _initialPositions.remove(s.id);
          } else {
            selectedIds.add(s.id);
            _initialPositions[s.id] = s.position;
          }
          setState(() {});
        },
        onPanStart: (_) {
          if (isMultiSelectMode) {
            // Multi-select mode: Only allow drag if widget is already selected
            if (!selectedIds.contains(s.id)) {
              return;
            }
          } else {
            // Single mode: Auto-select this widget only
            selectedIds.clear();
            selectedIds.add(s.id);
            _initialPositions.clear();
            _initialPositions[s.id] = s.position;
          }

          _cumulativeDelta = Offset.zero;
          for (final shape in shapes) {
            if (selectedIds.contains(shape.id)) {
              _initialPositions[shape.id] = shape.position;
              debugPrint('onPanStart ${shape.position}');
            }
          }
        },
        onLongPressStart: (details) async {
          if (s.type == ShapeType.tableRect) {
            // Show popup menu at the tap location
            final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
            final result = await showMenu<String>(
              context: context,
              position: RelativeRect.fromRect(details.globalPosition & const Size(40, 40), Offset.zero & overlay.size),
              items: [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('编辑桌子')]),
                ),
                PopupMenuItem<String>(
                  value: 'duplicate',
                  child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('复制')]),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('删除')]),
                ),
              ],
            );

            // Handle menu selection
            if (result == 'edit') {
              _editTableSizeDialog(s);
            } else if (result == 'duplicate') {
              _duplicateShape(s);
            } else if (result == 'delete') {
              _deleteShape(s.id);
            }
          }
        },
        onPanUpdate: (details) {
          // Only allow drag if widget is in selection
          if (!selectedIds.contains(s.id)) {
            return;
          }

          // Convert screen pixel delta to world delta (considering scale)
          final scale = _tc.value.getMaxScaleOnAxis();
          _cumulativeDelta += details.delta / scale;

          setState(() {
            // Move all selected shapes together
            for (final shape in shapes) {
              if (selectedIds.contains(shape.id)) {
                final start = _initialPositions[shape.id]!;
                final newPos = start + _cumulativeDelta;
                shape.position = _clampToBounds(newPos, shape.size);
              }
            }
          });
        },
        onPanEnd: (_) {
          // Only snap if widget is selected
          if (!selectedIds.contains(s.id)) {
            return;
          }

          // Snap all selected shapes to grid when released
          setState(() {
            for (final shape in shapes) {
              if (selectedIds.contains(shape.id)) {
                shape.position = _snap(shape.position, shape.type);
              }
            }

            // In single-select mode, clear selection after move
            if (!isMultiSelectMode) {
              selectedIds.clear();
              _initialPositions.clear();
            }
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
    );
  }

  Offset _clampToBounds(Offset pos, Size size) {
    const double minX = 0;
    const double minY = 0;
    final double maxX = worldExtent - size.width / 2;
    final double maxY = worldExtent - size.height / 2;

    double clampedX = pos.dx.clamp(size.width / 2 + minX, maxX);
    double clampedY = pos.dy.clamp(size.height / 2 + minY, maxY);

    return Offset(clampedX, clampedY);
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
        // print("top alignment $alignment $translateOffset");
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        );
        break;
      case Side.right:
        alignment = Alignment(1, -1 + (index + 1) * 2 * spacing);
        width = grid * 0.5;
        height = grid * 0.75;
        translateOffset = Offset(gapFromTable, positionOffset);
        // print("right alignment $alignment $translateOffset");
        borderRadius = BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(25),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(25),
        );
        break;
      case Side.bottom:
        alignment = Alignment(-1 + (index + 1) * 2 * spacing, 1);
        // print("bottom alignment $alignment $spacing");
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
        width = grid * 0.5;
        height = grid * 0.75;
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
    // print("tableW. $tableW =$tableH $factor");
    // if ((tableW == grid && tableH == grid * 2) || (tableW == grid * 2 && tableH == grid)) {
    //   factor += 20;
    // }
    //
    // if (tableW == tableH) {
    //   factor = grid;
    // }
    factor = grid;

    return Container(
      width: tableW + factor,
      height: tableH + factor,
      // color: Colors.red,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...buildSideChairs(distribution[0], Side.left, color),
          ...buildSideChairs(distribution[1], Side.top, color),
          ...buildSideChairs(distribution[2], Side.right, color),
          ...buildSideChairs(distribution[3], Side.bottom, color),
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
