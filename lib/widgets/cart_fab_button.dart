import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartFabButton extends StatefulWidget {
  final int count;
  final VoidCallback onPressed;
  final bool draggable;
  final String heroTag;

  const CartFabButton({
    super.key,
    required this.count,
    required this.onPressed,
    this.draggable = false,
    this.heroTag = 'cart_fab',
  });

  @override
  State<CartFabButton> createState() => _CartFabButtonState();
}

class _CartFabButtonState extends State<CartFabButton> {
  Offset? _fabOffset;
  double? _fabXFrac;
  double? _fabYFrac;
  bool _isDragging = false;
  Offset? _dragStartGlobal;
  Offset? _dragStartOffset;

  static const String _fabXFracKey = 'cart_fab_x_frac';
  static const String _fabYFracKey = 'cart_fab_y_frac';

  @override
  void initState() {
    super.initState();
    if (widget.draggable) {
      _loadFabPosition();
    }
  }

  Future<void> _loadFabPosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fabXFrac = prefs.getDouble(_fabXFracKey);
      _fabYFrac = prefs.getDouble(_fabYFracKey);
      _fabOffset = null;
    });
  }

  Future<void> _saveFabPosition(double xFrac, double yFrac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fabXFracKey, xFrac);
    await prefs.setDouble(_fabYFracKey, yFrac);
  }

  void _snapFabToEdge({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    final current = _fabOffset;
    if (current == null) return;
    final double snappedX = (current.dx - minX) <= (maxX - current.dx) ? minX : maxX;
    final double snappedY = current.dy.clamp(minY, maxY);
    final double xRange = (maxX - minX).abs() < 0.001 ? 1 : (maxX - minX);
    final double yRange = (maxY - minY).abs() < 0.001 ? 1 : (maxY - minY);
    final xFrac = ((snappedX - minX) / xRange).clamp(0.0, 1.0);
    final yFrac = ((snappedY - minY) / yRange).clamp(0.0, 1.0);
    setState(() {
      _fabOffset = Offset(snappedX, snappedY);
      _fabXFrac = xFrac;
      _fabYFrac = yFrac;
    });
    _saveFabPosition(xFrac, yFrac);
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton(
      heroTag: widget.heroTag,
      backgroundColor: const Color.fromARGB(255, 27, 111, 129),
      onPressed: widget.onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_cart, color: Colors.white),
          if (widget.count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Center(
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!widget.draggable) return fab;

    // Draggable logic
    final media = MediaQuery.of(context);
    final size = media.size;
    final padding = media.padding;
    final minX = 12.0;
    final maxX = size.width - 68.0;
    final minY = padding.top + 80.0;
    final maxY = size.height - 120.0;
    double resolvedX = minX;
    double resolvedY = maxY;
    if (_fabOffset != null) {
      resolvedX = _fabOffset!.dx;
      resolvedY = _fabOffset!.dy;
    } else if (_fabXFrac != null && _fabYFrac != null) {
      final xRange = maxX - minX;
      final yRange = maxY - minY;
      resolvedX = minX + (_fabXFrac!.clamp(0.0, 1.0) * xRange);
      resolvedY = minY + (_fabYFrac!.clamp(0.0, 1.0) * yRange);
    }
    return AnimatedPositioned(
      left: resolvedX,
      top: resolvedY,
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            _dragStartGlobal = details.globalPosition;
            _dragStartOffset = Offset(resolvedX, resolvedY);
          });
        },
        onPanUpdate: (details) {
          final startGlobal = _dragStartGlobal;
          final startOffset = _dragStartOffset;
          if (startGlobal == null || startOffset == null) return;
          final delta = details.globalPosition - startGlobal;
          final newX = (startOffset.dx + delta.dx).clamp(minX, maxX);
          final newY = (startOffset.dy + delta.dy).clamp(minY, maxY);
          setState(() {
            _fabOffset = Offset(newX, newY);
          });
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
            _dragStartGlobal = null;
            _dragStartOffset = null;
          });
          _snapFabToEdge(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _isDragging ? 1.06 : 1.0,
          child: fab,
        ),
      ),
    );
  }
}
