import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/services/notificaciones_store.dart';
import 'package:bubblesplash/views/home/notificaciones_page.dart';

import '/views/home/inicio_page.dart';
import '/views/home/pagos_page.dart';
import '/views/home/menu_page.dart';
import '/views/home/beneficios_page.dart';
import 'package:bubblesplash/services/menu_prefetcher.dart';
import 'package:bubblesplash/services/sede_service.dart';
import 'package:bubblesplash/widgets/sede_obligatoria_dialog.dart';

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

  /// Avisos sin leer, para la burbuja de la pestaña de notificaciones.
  int _avisosSinLeer = 0;

  /// Posición de esa pestaña. Se busca por la etiqueta en vez de escribir el
  /// número: si mañana se reordena la barra, la burbuja sigue en su sitio.
  int get _indiceAvisos =>
      _navItems.indexWhere((i) => i['label'] == 'Avisos');

  final Color mainColor = const Color.fromARGB(255, 27, 111, 129);

  final List<Map<String, dynamic>> _navItems = const [
    {"icon": Icons.home_filled, "label": "Inicio"},
    {"icon": Icons.local_fire_department, "label": "Pagos"},
    {"icon": Icons.local_drink, "label": "Menú"},
    {"icon": Icons.card_giftcard, "label": "Beneficios"},
    {"icon": Icons.notifications, "label": "Avisos"},
  ];

  late final List<Widget> _pages;

  /// Mientras se comprueba la sede no se muestra nada del contenido: todo lo
  /// que hay dentro (menú, productos, beneficios) depende de ella.
  bool _comprobandoSede = true;

  /// Fuerza a reconstruir las páginas tras elegir sede, para que el menú
  /// recargue el catálogo del local correcto.
  Key _contenidoKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _construirPaginas();
    _asegurarSede();
    _contarAvisos();
  }

  Future<void> _contarAvisos() async {
    // Se enseña lo que hay guardado sin esperar, y en segundo plano se
    // comprueba contra el servidor: si el panel borró un aviso, la burbuja
    // deja de contarlo.
    final local = await NotificacionesStore.sinLeer();
    if (mounted) setState(() => _avisosSinLeer = local);

    if (await NotificacionesStore.sincronizar()) {
      final n = await NotificacionesStore.sinLeer();
      if (mounted) setState(() => _avisosSinLeer = n);
    }
  }

  void _construirPaginas() {
    _pages = [
      InicioPage(onTabChange: _onItemTapped),
      const PagosPage(),
      const MenuPage(),
      const BeneficiosPage(),
      const NotificacionesPage(),
    ];
  }

  /// Comprueba si el usuario ya tiene sede. Si no, abre un diálogo bloqueante.
  ///
  /// Es el caso típico del acceso con Google: nunca pasó por el formulario de
  /// registro, así que llega sin sede y no se le puede mostrar ningún catálogo.
  Future<void> _asegurarSede() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('isGuest') ?? false;
    final token = (prefs.getString('access_token') ?? '').trim();

    // Invitado o sin sesión: no hay perfil que consultar.
    if (isGuest || token.isEmpty) {
      if (mounted) setState(() => _comprobandoSede = false);
      return;
    }

    final perfil = await SedeService.fetchMyProfile();

    // Si no se pudo consultar (sin red, servidor caído) NO se bloquea la app:
    // se deja entrar y se volverá a preguntar en el siguiente arranque.
    final debeElegir = perfil != null && perfil['must_select_sede'] == true;

    if (!mounted) return;

    if (!debeElegir) {
      setState(() => _comprobandoSede = false);
      return;
    }

    // Bucle: no se sale de aquí hasta que confirme una sede.
    Sede? elegida;
    while (elegida == null && mounted) {
      elegida = await SedeObligatoriaDialog.mostrar(context);
    }

    if (!mounted) return;
    setState(() {
      _comprobandoSede = false;
      // Cambiar la Key basta para que Flutter descarte el subárbol y vuelva a
      // ejecutar el initState de cada página, recargando el catálogo de su
      // sede. No se reconstruye `_pages`: es `late final` y solo admite una
      // asignación (reasignarla lanzaba LateInitializationError).
      _contenidoKey = UniqueKey();
    });

    MenuPrefetcher.prefetchMenu();
  }

  void _onItemTapped(int index) async {
    // Pagos, Beneficios y Avisos son personales: sin sesión no hay nada que
    // enseñar, así que se invita a iniciarla en vez de abrir una vista vacía.
    if (index == 1 || index == 3 || index == _indiceAvisos) {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuest') ?? false;
      if (isGuest) {
        if (!mounted) return;
        final login = await _showLoginPromptDialog(context);
        if (login == true && mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
        return;
      }
    }
    setState(() => _selectedIndex = index);

    // Al entrar o salir de Avisos se recuenta: dentro pudo marcarlos leídos.
    _contarAvisos();
  }

  Future<bool?> _showLoginPromptDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF1B6F81),
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Acceso Requerido',
                  style: TextStyle(
                    color: Color(0xFF062B35),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Para acceder a esta sección debes iniciar sesión o crear una cuenta.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B6F81),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Iniciar sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final double safeBottom = mediaQuery.padding.bottom.clamp(0.0, 34.0);

    // El alto de la barra sí depende solo de la pantalla.
    final double barHeight = (size.height * 0.085).clamp(66.0, 86.0);

    // Espera mientras se resuelve la sede: sin menú ni pestañas.
    //
    // Solo el indicador de carga. El texto «Preparando tu sede» nombraba un
    // detalle interno que al cliente no le dice nada y, al aparecer y
    // desaparecer en un instante, daba la sensación de que algo iba mal.
    if (_comprobandoSede) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          // Algo más grande y grueso que el de por defecto: esta espera dura
          // un instante y un indicador fino apenas se percibe.
          child: SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
        ),
      );
    }

    return Scaffold(
      body: KeyedSubtree(key: _contenidoKey, child: _pages[_selectedIndex]),
      extendBody: true,
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth = constraints.maxWidth / _navItems.length;

          // El círculo del elemento activo se acota TAMBIÉN por el ancho de
          // cada pestaña, no solo por el de la pantalla. Con cuatro pestañas
          // sobraba sitio; con cinco, en un móvil estrecho el círculo se
          // comía el hueco de sus vecinos.
          final double fabSize = math
              .min(size.width * 0.16, itemWidth * 0.76)
              .clamp(42.0, 64.0);

          final double extraTop = fabSize * 0.12;

          // La letra se ajusta al hueco disponible. Con cinco pestañas,
          // «Beneficios» a 11 px ya no cabía en pantallas de 320 px.
          final double labelSize = (itemWidth * 0.16).clamp(8.5, 11.0);

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
                        labelSize: labelSize,
                        isSelected: isSelected,
                        icon: _navItems[index]["icon"],
                        label: _navItems[index]["label"] as String,
                        avisos: index == _indiceAvisos ? _avisosSinLeer : 0,
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
    required double labelSize,
    required bool isSelected,
    required dynamic icon,
    required String label,
    int avisos = 0,
  }) {
    // Posiciones responsivas (clamp evita que se “salga” en pantallas pequeñas)
    // Todo se mide contra el alto real de la barra, no contra números fijos:
    // en una pantalla corta la barra encoge, y con topes de 18–30 px el icono
    // acababa encima del texto.
    final double labelBottom = (barHeight * 0.11).clamp(6.0, 12.0);

    final double selectedBottom = (barHeight - (fabSize / 2) - 26).clamp(
      10.0,
      barHeight - 12,
    );

    // El icono arranca por encima del texto, con un respiro de 3 px.
    final double unselectedBottom = math
        .max(barHeight * 0.38, labelBottom + labelSize + 3)
        .clamp(16.0, barHeight - 34);

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
            //
            // Va acotado a izquierda y derecha y envuelto en un FittedBox:
            // así se encoge hasta caber en vez de recortarse con puntos
            // suspensivos. Importa porque la app permite agrandar la letra
            // del sistema hasta un 130 %, y con ese ajuste «Beneficios» no
            // cabía en NINGÚN teléfono; se leía «Benefi…».
            Positioned(
              left: 3,
              right: 3,
              bottom: labelBottom,
              child: AnimatedOpacity(
                opacity: isSelected ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.90),
                      fontSize: labelSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
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
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _buildIcon(icon, isSelected, iconColor),
                    // Contador de avisos sin leer. Se oculta cuando la
                    // pestaña está abierta: ahí ya los está viendo.
                    if (avisos > 0 && !isSelected)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE23D3D),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.3,
                            ),
                          ),
                          child: Text(
                            avisos > 9 ? '9+' : '$avisos',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
