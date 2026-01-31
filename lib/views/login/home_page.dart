import 'dart:math' as math;
import 'package:flutter/material.dart';

import '/views/home/inicio_page.dart';
import '/views/home/pagos_page.dart';
import '/views/home/menu_page.dart';
import '/views/home/beneficios_page.dart';

// --- Painter (curva con notch) ---
class WavyBottomBarPainter extends CustomPainter {
  final int selectedIndex;
  final double itemWidth;
  final Color barColor;

  WavyBottomBarPainter({
    required this.selectedIndex,
    required this.itemWidth,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    final double topY = 0;
    final double h = size.height;

    final double centerX = (selectedIndex * itemWidth) + (itemWidth / 2);

    final double notchRadius = (h * 0.48).clamp(18.0, 42.0);
    final double notchDepth = (h * 0.38).clamp(10.0, 26.0);
    final double spread = 1.55;

    final double leftEdge = math.max(0, centerX - notchRadius * spread);
    final double rightEdge = math.min(
      size.width,
      centerX + notchRadius * spread,
    );

    path.moveTo(0, topY);
    path.lineTo(leftEdge, topY);

    path.quadraticBezierTo(
      math.max(0, centerX - notchRadius * 1.10),
      topY,
      math.max(0, centerX - notchRadius),
      topY + notchDepth,
    );

    path.arcToPoint(
      Offset(math.min(size.width, centerX + notchRadius), topY + notchDepth),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    path.quadraticBezierTo(
      math.min(size.width, centerX + notchRadius * 1.10),
      topY,
      rightEdge,
      topY,
    );

    path.lineTo(size.width, topY);
    path.lineTo(size.width, h);
    path.lineTo(0, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavyBottomBarPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.itemWidth != itemWidth ||
        oldDelegate.barColor != barColor;
  }
}

// --- HomePage ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final Color mainColor = const Color.fromARGB(255, 27, 111, 129);

  final List<Map<String, dynamic>> _navItems = const [
    {"icon": Icons.home_filled, "label": "Inicio"},
    {"icon": Icons.local_fire_department, "label": "Pagos"},
    {"icon": Icons.local_drink, "label": "Menú"},
    {"icon": Icons.card_giftcard, "label": "Beneficios"},
  ];

  final List<Widget> _pages = const [
    InicioPage(),
    PagosPage(),
    MenuPage(),
    BeneficiosPage(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final double safeBottom = mediaQuery.padding.bottom.clamp(0.0, 34.0);

    // Responsive (sin “saltos” raros)

    final double barHeight = (size.height * 0.085).clamp(70.0, 86.0); // un poco menos alto

    final double fabSize = (size.width * 0.16).clamp(52.0, 64.0);
    final double extraTop = fabSize * 0.12; // antes 0.35 (esto lo subía demasiado)

    return Scaffold(
      body: _pages[_selectedIndex],
      extendBody: true,
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth = constraints.maxWidth / _navItems.length;

          return SizedBox(
            height: barHeight + extraTop + safeBottom,
            width: constraints.maxWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Rellena el área del safe-bottom para que no quede hueco.
                if (safeBottom > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: safeBottom,
                    child: ColoredBox(color: mainColor),
                  ),

                // Barra con notch (por encima del safe-bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: safeBottom,
                  height: barHeight,
                  child: CustomPaint(
                    painter: WavyBottomBarPainter(
                      selectedIndex: _selectedIndex,
                      itemWidth: itemWidth,
                      barColor: mainColor,
                    ),
                  ),
                ),

                // Items (por encima del safe-bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: safeBottom,
                  height: barHeight,
                  child: Row(
                    children: List.generate(_navItems.length, (index) {
                      final bool isSelected = _selectedIndex == index;
                      return _buildNavItem(
                        index: index,
                        itemWidth: itemWidth,
                        barHeight: barHeight,
                        fabSize: fabSize,
                        isSelected: isSelected,
                        icon: _navItems[index]["icon"],
                        label: _navItems[index]["label"] as String,
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required double itemWidth,
    required double barHeight,
    required double fabSize,
    required bool isSelected,
    required dynamic icon,
    required String label,
  }) {
    // Posiciones responsivas (clamp evita que se “salga” en pantallas pequeñas)
    final double selectedBottom = (barHeight - (fabSize / 2) - 26).clamp(
      10.0,
      barHeight - 12,
    );
    final double unselectedBottom = (barHeight * 0.40).clamp(18.0, 30.0);

    final Color iconColor = isSelected
        ? mainColor
        : Colors.white.withOpacity(0.92);

    return InkWell(
      onTap: () => _onItemTapped(index),
      splashColor: Colors.white.withOpacity(0.08),
      highlightColor: Colors.white.withOpacity(0.05),
      child: SizedBox(
        width: itemWidth,
        height: barHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Texto (solo cuando NO está seleccionado)
            Positioned(
              bottom: 10,
              child: AnimatedOpacity(
                opacity: isSelected ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),

            // Ícono (FAB cuando seleccionado)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              bottom: isSelected ? selectedBottom : unselectedBottom,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: isSelected ? fabSize : 32,
                height: isSelected ? fabSize : 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            blurRadius: 16,
                            spreadRadius: 1,
                            color: Colors.black.withOpacity(0.18),
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : const [],
                ),
                child: _buildIcon(icon, isSelected, iconColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(dynamic icon, bool isSelected, Color color) {
    if (icon is IconData) {
      return Icon(icon, size: isSelected ? 26 : 24, color: color);
    }
    if (icon is String) {
      return Image.asset(
        icon,
        width: isSelected ? 28 : 22,
        height: isSelected ? 28 : 22,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    return const SizedBox.shrink();
  }
}
