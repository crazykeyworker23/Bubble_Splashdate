import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'CartPage.dart';
import 'package:bubblesplash/utils/route_observer.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/services/menu_prefetcher.dart';
import 'package:bubblesplash/services/sede_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import '../../constants/api_constants.dart';
import 'package:bubblesplash/widgets/connection_error_dialog.dart';

import 'package:bubblesplash/models/category.dart';
import 'package:bubblesplash/models/product.dart';
import 'package:bubblesplash/utils/tamanos.dart';
import 'package:bubblesplash/utils/carrito_promos.dart';
import 'package:bubblesplash/models/topping.dart';

// =========================
// Splash Bubble Premium UI (diseño premium glass)
// =========================
class SB {
  // Colores principales premium
  static const navy = Color(0xFF062B35);
  static const teal = Color(0xFF128FA0);
  static const teal2 = Color(0xFF12A3B6);
  static const mint = Color(0xFF22C55E);
  static const gold = Color(0xFFF6C453);
  static const blueGlass = Color(0xCCF0F9FF);

  // Fondo y tarjetas
  static const bg = Color(0xFFF6FAFC);
  static const card = Colors.white;
  static const glass = Color(0xB3F0F9FF); // glassmorphism
  static const stroke = Color(0xFFE6EEF5);
  static const text = Color(0xFF0F172A);
  static const sub = Color(0xFF64748B);

  // Gradientes premium
  static const gradBrand = LinearGradient(
    colors: [navy, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradAccent = LinearGradient(
    colors: [teal, teal2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradGlass = LinearGradient(
    colors: [Color(0x66FFFFFF), Color(0x33FFFFFF), Color(0x11FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Sombras premium
  static List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.07),
      blurRadius: 22,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: Colors.black.withOpacity(0.16),
      blurRadius: 36,
      offset: const Offset(0, 18),
    ),
  ];

  // Efecto glassmorphism
  static BoxDecoration glassBox({BorderRadiusGeometry? radius}) =>
      BoxDecoration(
        gradient: gradGlass,
        color: glass,
        borderRadius: radius ?? BorderRadius.circular(20),
        border: Border.all(color: stroke.withOpacity(0.7), width: 1.2),
        boxShadow: shadowSoft,
        backgroundBlendMode: BlendMode.overlay,
      );
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry radius;
  final bool glass;
  final bool shadow;
  final bool borderGlow;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = const BorderRadius.all(Radius.circular(22)),
    this.glass = false,
    this.shadow = true,
    this.borderGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: glass
          ? SB
                .glassBox(radius: radius)
                .copyWith(
                  boxShadow: shadow ? SB.shadowSoft : [],
                  border: Border.all(
                    color: borderGlow ? SB.mint.withOpacity(0.45) : SB.stroke,
                    width: borderGlow ? 2.2 : 1.2,
                  ),
                )
          : BoxDecoration(
              color: SB.card,
              borderRadius: radius,
              border: Border.all(
                color: borderGlow ? SB.mint.withOpacity(0.45) : SB.stroke,
                width: borderGlow ? 2.2 : 1.2,
              ),
              boxShadow: shadow ? SB.shadowSoft : [],
            ),
      child: child,
    );
  }
}

class PremiumPill {
  static ShapeBorder shape({bool selected = false, bool glow = false}) {
    return StadiumBorder(
      side: BorderSide(
        color: selected
            ? (glow ? SB.mint.withOpacity(0.55) : Colors.transparent)
            : SB.text.withOpacity(0.08),
        width: glow ? 2.0 : 1.0,
      ),
    );
  }

  static BoxDecoration decoration({bool selected = false, bool glow = false}) {
    return BoxDecoration(
      gradient: selected
          ? SB.gradAccent
          : LinearGradient(
              colors: [SB.card, SB.bg],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      borderRadius: BorderRadius.circular(999),
      boxShadow: glow && selected
          ? [
              BoxShadow(
                color: SB.mint.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : [],
      border: Border.all(
        color: selected
            ? (glow ? SB.mint.withOpacity(0.55) : SB.stroke)
            : SB.stroke,
        width: glow && selected ? 2.0 : 1.0,
      ),
    );
  }
}

bool isBase64(String str) {
  final base64RegExp = RegExp(r'^[A-Za-z0-9+/=\r\n]+={0,2}\u0000*\u0000*$');
  return str.length > 100 && base64RegExp.hasMatch(str.replaceAll('\n', ''));
}

String extractBase64(String str) {
  if (str.startsWith('data:image')) {
    final idx = str.indexOf('base64,');
    if (idx != -1) return str.substring(idx + 7);
  }
  return str;
}

class MenuPage extends StatefulWidget {
  final double descuento;
  // Id opcional de la oferta/canje aplicada (se usará como ofc_int_id en el pedido)
  final int? ofcIntId;
  // Tamaño de vaso permitido según canje de puntos
  final String? allowedSize;
  const MenuPage({
    super.key,
    this.descuento = 0.0,
    this.ofcIntId,
    this.allowedSize,
  });

  @override
  State<MenuPage> createState() => _MenuPageState();
}

// --------------------
// CustomAppBar simple
// --------------------
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onHelpPressed;
  final VoidCallback? onRefreshPressed;
  final bool refreshing;
  final String? sedeNombre;

  const CustomAppBar({
    super.key,
    this.onHelpPressed,
    this.onRefreshPressed,
    this.refreshing = false,
    this.sedeNombre,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B3D4A), Color(0xFF128FA0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 12),
            ),
          ],
        ),
      ),
      titleSpacing: 14,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.local_drink_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    ' SPLASH BUBBLE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    (sedeNombre != null && sedeNombre!.isNotEmpty)
                        ? 'SEDE ${sedeNombre!.toUpperCase()}'
                        : 'BEBIDAS ESPECIALES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (onRefreshPressed != null)
          IconButton(
            icon: refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
            onPressed: refreshing ? null : onRefreshPressed,
            tooltip: 'Actualizar productos y ofertas de tu sede',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        if (onHelpPressed != null) ...[
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: onHelpPressed,
            tooltip: 'Ver guía de navegación',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: Colors.white),
                SizedBox(width: 5),
                Icon(Icons.circle, size: 6, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'BUBBLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------
// CUERPO PRINCIPAL
// --------------------
class _MenuPageState extends State<MenuPage>
    with RouteAware, WidgetsBindingObserver {
  List<Map<String, dynamic>> pedidos = [];
  bool _suppressNextReload = false;

  // Indica si ya se usó el canje/descuento en algún producto del carrito
  bool get _canjeYaUsado => pedidos.any((p) => p['isPromoItem'] == true);

  /// La pantalla se abrió desde un canje de oferta: el proceso debe ser
  /// "elegir producto → pagar", sin pasos intermedios.
  bool get _isCanjeExpress =>
      (widget.ofcIntId != null && widget.ofcIntId! > 0) || widget.descuento > 0;

  List<Category> _categories = [];
  bool _isLoadingProducts = true;
  String? _productsError;

  // ✅ optimización: evita solapes y reprocesado
  bool _isFetchingCategories = false;
  String? _lastCategoriesBody;

  int? _selectedCategoryId;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _carouselKey = GlobalKey();
  final GlobalKey _categoryChipsKey = GlobalKey();
  final GlobalKey _productListKey = GlobalKey();

  bool _showInteractiveOnboarding = false;
  int _currentOnboardingStep = 0;

  static const String _cartFabXFracKey = 'menu_cart_fab_x_frac';
  static const String _cartFabYFracKey = 'menu_cart_fab_y_frac';
  final GlobalKey _cartFabStackKey = GlobalKey();

  double? _cartFabXFrac;
  double? _cartFabYFrac;
  Offset? _cartFabOffset;

  Offset? _cartFabDragStartGlobal;
  Offset? _cartFabDragStartOffset;
  bool _isDraggingCartFab = false;

  bool _refrescando = false;
  String? _sedeNombre;

  static const String _categoriesCacheKey = 'menu_categories_cache';
  static const String _categoriesCacheTimeKey = 'menu_categories_cache_time';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Si ya tenemos categorías en memoria, usarlas de inmediato para evitar el estado "cargando..."
    if (MenuPrefetcher.inMemoryCategories.isNotEmpty) {
      _categories = MenuPrefetcher.inMemoryCategories;
      _isLoadingProducts = false;
      _selectedCategoryId = _categories.first.id;
    }

    _cargarPedidosGuardados();
    _cargarCategorias();
    _cargarNombreSede();
    _loadCartFabPosition();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ al volver al foreground, refresca 1 vez
    if (state == AppLifecycleState.resumed) {
      _actualizarCategoriasDesdeApi(background: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_suppressNextReload) return;
    _cargarPedidosGuardados();
  }

  // --------------------
  // Carrito
  // --------------------
  Future<void> _cargarPedidosGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('cart_pedidos') ?? [];
    if (!mounted) return;
    setState(() {
      // Sin canje activo en esta sesión, los precios promocionales del
      // carrito guardado se revierten: el servidor cobraría el precio
      // completo y la app estaría mostrando otro.
      pedidos = sanearCarritoGuardado(
        data.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList(),
        hayCanjeActivo: (widget.ofcIntId ?? 0) > 0,
      );
    });
  }

  Future<void> _guardarPedidos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = pedidos.map((p) {
      final image = p['image'] ?? '';
      String normalizedImage = image;
      if (image is String &&
          image.isNotEmpty &&
          !image.startsWith('http') &&
          !image.startsWith('data:image') &&
          !image.endsWith('.svg')) {
        // Si es solo un nombre de archivo, lo convertimos a URL del backend
        normalizedImage =
            '${BackendConfig.baseUrl}bubblesplash/productos/img/$image';
      }
      final pCopy = Map<String, dynamic>.from(p);
      pCopy['image'] = normalizedImage;
      return jsonEncode(pCopy);
    }).toList();
    await prefs.setStringList('cart_pedidos', data);
  }

  Future<void> _openCart() async {
    _suppressNextReload = true;
    List<Map<String, dynamic>>? updatedPedidos;
    try {
      updatedPedidos = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(
          builder: (context) => CartPage(
            initialPedidos: pedidos,
            descuento: widget.descuento,
            ofcIntId: widget.ofcIntId,
          ),
        ),
      );
    } finally {
      _suppressNextReload = false;
    }

    final updated = updatedPedidos;
    if (updated != null) {
      setState(() => pedidos = updated);
      await _guardarPedidos();
    } else {
      await _cargarPedidosGuardados();
    }
  }

  // --------------------
  // FAB Draggable persist
  // --------------------
  Future<void> _loadCartFabPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_cartFabXFracKey);
    final y = prefs.getDouble(_cartFabYFracKey);
    if (!mounted) return;
    setState(() {
      _cartFabXFrac = x;
      _cartFabYFrac = y;
      _cartFabOffset = null;
    });
  }

  Future<void> _saveCartFabPosition({
    required double xFrac,
    required double yFrac,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cartFabXFracKey, xFrac);
    await prefs.setDouble(_cartFabYFracKey, yFrac);
  }

  void _snapCartFabToEdge({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    final current = _cartFabOffset;
    if (current == null) return;

    final double snappedX = (current.dx - minX) <= (maxX - current.dx)
        ? minX
        : maxX;
    final double snappedY = current.dy.clamp(minY, maxY);

    final double xRange = (maxX - minX).abs() < 0.001 ? 1 : (maxX - minX);
    final double yRange = (maxY - minY).abs() < 0.001 ? 1 : (maxY - minY);
    final xFrac = ((snappedX - minX) / xRange).clamp(0.0, 1.0);
    final yFrac = ((snappedY - minY) / yRange).clamp(0.0, 1.0);

    setState(() {
      _cartFabOffset = Offset(snappedX, snappedY);
      _cartFabXFrac = xFrac;
      _cartFabYFrac = yFrac;
    });

    _saveCartFabPosition(xFrac: xFrac, yFrac: yFrac);
  }

  Widget _buildCartFabButton({required int count}) {
    return FloatingActionButton(
      heroTag: 'menu_cart_fab',
      backgroundColor: const Color.fromARGB(255, 27, 111, 129),
      onPressed: _openCart,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_cart, color: Colors.white),
          if (count > 0)
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
                    '$count',
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
  }

  // --------------------
  // Carga categorías (cache + optimización)
  // --------------------
  Future<void> _cargarNombreSede() async {
    final sede = await SedeService.getUserSede();
    if (!mounted || sede == null) return;
    setState(() => _sedeNombre = sede.name);
  }

  /// Vuelve a pedir al servidor el catálogo de la sede.
  ///
  /// Descarta la caché a propósito: es el botón que usa el cliente cuando el
  /// local acaba de cambiar precios, stock u ofertas y quiere verlo ya.
  Future<void> _refrescarDatosDeSede() async {
    if (_refrescando) return;
    setState(() => _refrescando = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_categoriesCacheKey);
      await prefs.remove(_categoriesCacheTimeKey);

      // Por si cambió de sede desde Mi perfil.
      await SedeService.fetchMyProfile();
      await _cargarNombreSede();

      _lastCategoriesBody = null;
      MenuPrefetcher.inMemoryCategories = [];
      await _cargarCategorias();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _sedeNombre == null
                ? 'Menú actualizado.'
                : 'Menú de ${_sedeNombre!} actualizado.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _refrescando = false);
    }
  }

  Future<void> _cargarCategorias() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final cached = prefs.getString(_categoriesCacheKey);
    final cacheTime = prefs.getInt(_categoriesCacheTimeKey) ?? 0;

    bool hasCache = false;
    bool isCacheValid = false;

    // Mostrar caché inmediatamente si existe
    if (cached != null && cached.trim().isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = now - cacheTime;
      // Considerar la caché válida por 15 minutos (900,000 ms)
      isCacheValid = cacheAge < 15 * 60 * 1000;

      try {
        // Usar compute para no bloquear el hilo principal al decodificar y mapear el JSON grande
        final categories = await compute(_parseCategoriesIsolate, cached);

        if (!mounted) return;
        MenuPrefetcher.inMemoryCategories = categories;
        setState(() {
          _categories = categories;
          _isLoadingProducts = false;
          _productsError = null;
          if (_selectedCategoryId == null && _categories.isNotEmpty) {
            _selectedCategoryId = _categories.first.id;
          }
        });
        _precacheProductImages(categories);
        _checkOnboarding();

        // ✅ guarda last body para evitar reprocesado si es igual
        _lastCategoriesBody = cached;
        hasCache = true;
      } catch (e) {
        debugPrint('⚠️ Error al cargar categorías desde caché: $e');
        // Si el caché está dañado, lo limpiamos para evitar bucles de fallos
        await prefs.remove(_categoriesCacheKey);
        await prefs.remove(_categoriesCacheTimeKey);
      }
    }

    // Si la caché existe y sigue siendo válida, no llamamos a la API en absoluto
    if (hasCache && isCacheValid) {
      debugPrint(
        '⚡ Caché de productos válida (menos de 15 minutos). No se requiere actualización de red.',
      );
      return;
    }

    // Si ya mostramos datos del caché pero expiró la validez, actualizamos en segundo plano sin bloquear la pantalla
    if (hasCache) {
      _actualizarCategoriasDesdeApi(background: true);
      return;
    }

    // Si no hay caché válido ni guardado (primera vez), sí bloquea la UI con pantalla de carga
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    await _actualizarCategoriasDesdeApi(background: false);
  }

  Future<void> _actualizarCategoriasDesdeApi({bool background = false}) async {
    if (_isFetchingCategories) return; // ✅ evita solapes
    _isFetchingCategories = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      final rawToken = prefs.getString('access_token');
      final token = (rawToken ?? '').trim();
      final uri = BackendConfig.api('bubblesplash/categorias/');

      http.Response? response;
      bool responseIsUseful = false;
      List<Category> parsedCategories = [];

      // 1. Intentar obtener el menú con token de autenticación
      if (token.isNotEmpty) {
        try {
          response = await http.get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            parsedCategories = await compute(
              _parseCategoriesIsolate,
              response.body,
            );

            if (parsedCategories.isNotEmpty) {
              responseIsUseful = true;
            } else {
              debugPrint(
                '⚠️ El menú con token retornó 0 categorías activas con productos.',
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error en la llamada al menú con token: $e');
        }
      }

      // 2. Fallback: Si falló, dio 401, o devolvió lista vacía, intentar de forma anónima
      if (!responseIsUseful) {
        debugPrint(
          '🔄 Reintentando obtener menú de forma anónima (sin token)...',
        );
        try {
          final anonResponse = await http.get(
            uri,
            headers: {'Accept': 'application/json'},
          );

          if (anonResponse.statusCode == 200) {
            final anonCategories = await compute(
              _parseCategoriesIsolate,
              anonResponse.body,
            );

            if (anonCategories.isNotEmpty) {
              parsedCategories = anonCategories;
              response = anonResponse;
              responseIsUseful = true;
              debugPrint('✅ Menú anónimo cargado con éxito en fallback.');
            }
          } else {
            if (response == null || response.statusCode == 401) {
              response = anonResponse; // Mantener error más descriptivo
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error en reintento anónimo de menú: $e');
        }
      }

      if (!mounted) return;

      if (response == null) {
        if (!background || _categories.isEmpty) {
          setState(() {
            _isLoadingProducts = false;
            _productsError = 'Error de conexión al cargar productos.';
          });
        }
        return;
      }

      if (response!.statusCode == 401) {
        if (!background || _categories.isEmpty) {
          setState(() {
            _isLoadingProducts = false;
            _productsError =
                'Tu sesión ha expirado. Inicia sesión nuevamente para ver el menú.';
          });
        }
        return;
      }

      if (response!.statusCode != 200) {
        if (!background || _categories.isEmpty) {
          setState(() {
            _isLoadingProducts = false;
            _productsError =
                'Error al cargar productos (${response!.statusCode}).';
          });
        }
        return;
      }

      // ✅ si el body es igual al anterior, no reproceses
      if (_lastCategoriesBody != null &&
          _lastCategoriesBody == response!.body) {
        if (!background) setState(() => _isLoadingProducts = false);
        return;
      }
      _lastCategoriesBody = response!.body;

      // Guardar en cache
      await prefs.setString(_categoriesCacheKey, response!.body);
      await prefs.setInt(_categoriesCacheTimeKey, now);

      // ✅ actualiza solo si cambió algo relevante
      bool same = _categories.length == parsedCategories.length;
      if (same) {
        for (int i = 0; i < parsedCategories.length; i++) {
          if (_categories[i].id != parsedCategories[i].id ||
              _categories[i].products.length !=
                  parsedCategories[i].products.length) {
            same = false;
            break;
          }
        }
      }

      MenuPrefetcher.inMemoryCategories = parsedCategories;
      setState(() {
        if (!same) _categories = parsedCategories;
        if (_selectedCategoryId == null && _categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        }
        if (!background) _isLoadingProducts = false;
        _productsError = null;
      });
      _precacheProductImages(parsedCategories);
      _checkOnboarding();
    } catch (e) {
      if (!mounted) return;
      if (!background || _categories.isEmpty) {
        final errStr = e.toString().toLowerCase();
        final isNetwork =
            errStr.contains('socketexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('clientexception') ||
            errStr.contains('handshake') ||
            errStr.contains('network') ||
            errStr.contains('connection');

        setState(() {
          _isLoadingProducts = false;
          _productsError = isNetwork
              ? 'No se pudo conectar con el servidor. Por favor, comprueba tu conexión a Internet e intenta nuevamente.'
              : 'Error al cargar productos: $e';
        });

        if (isNetwork && mounted) {
          showConnectionErrorDialog(context, onRetry: _cargarCategorias);
        }
      }
    } finally {
      _isFetchingCategories = false;
    }
  }

  void _precacheProductImages(List<Category> categories) {
    if (!mounted || categories.isEmpty) return;

    final selectedId = _selectedCategoryId;
    final targetCat = categories.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => categories.first,
    );

    final listToPrecache = targetCat.products.take(10);
    for (final prod in listToPrecache) {
      final u = prod.image.trim();
      if (u.startsWith('http')) {
        precacheImage(CachedNetworkImageProvider(u), context);
      }
    }
  }

  // --------------------
  // GRID: abrir detalle y agregar
  // --------------------
  Future<void> _openProductAndAdd({
    required BuildContext context,
    required Product product,
  }) async {
    // Si esta pantalla viene de un canje/oferta y ya se usó
    // en un producto, no permitimos agregar más desde aquí.
    if (widget.descuento > 0 && _canjeYaUsado) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => const _PremiumFeedbackModal(
            message:
                'Ya usaste tu canje en un producto. Esta oferta solo aplica a un producto por pedido.',
          ),
        );
      }
      return;
    }

    // Solo el primer producto puede aprovechar el canje/descuento
    final bool canUseCanje = widget.descuento > 0 && !_canjeYaUsado;

    _suppressNextReload = true;
    dynamic rawPedido;

    try {
      rawPedido = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailPage(
            product: product,
            descuento: canUseCanje ? widget.descuento : 0.0,
            allowedSize: canUseCanje ? widget.allowedSize : null,
          ),
        ),
      );
    } finally {
      _suppressNextReload = false;
    }

    if (rawPedido != null) {
      final Map<String, dynamic> pedido = Map<String, dynamic>.from(
        rawPedido as Map,
      );

      // Marcamos qué producto usó el canje para limitarlo a uno solo
      if (canUseCanje && widget.descuento > 0) {
        pedido['isPromoItem'] = true;
      }

      setState(() => pedidos.add(pedido));
      await _guardarPedidos();

      if (!context.mounted) return;

      // ✅ Flujo de canje: el cliente ya pagó con sus puntos, así que no se le
      //    ofrece "seguir comprando". Se va directo a completar el pedido para
      //    cerrar el canje en el menor número de pasos posible.
      if (_isCanjeExpress) {
        await _openCart();
        return;
      }

      // Compra normal: sí se le ofrece seguir agregando productos.
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _PremiumFeedbackModal(
          message: 'Producto agregado al carrito',
          primaryLabel: 'Ver carrito',
          onPrimary: _openCart,
          secondaryLabel: 'Seguir comprando',
          onSecondary: () {}, // solo cierra el modal
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final double safeBottom = mediaQuery.padding.bottom.clamp(0.0, 34.0);
    final double barHeight = (size.height * 0.105).clamp(74.0, 92.0);
    final double fabSize = (size.width * 0.16).clamp(52.0, 64.0);
    final double extraTop = fabSize * 0.35;
    final double homeBottomBarTotalHeight = barHeight + extraTop + safeBottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        sedeNombre: _sedeNombre,
        refreshing: _refrescando,
        onRefreshPressed: _refrescarDatosDeSede,
        onHelpPressed: () {
          setState(() {
            _showInteractiveOnboarding = true;
            _currentOnboardingStep = 0;
          });
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double margin = 16;
          const double fabDiameter = 56;

          final double minX = margin;
          final double minY = margin;
          final double maxX = (constraints.maxWidth - fabDiameter - margin)
              .clamp(minX, 99999);
          final double maxY =
              (constraints.maxHeight -
                      homeBottomBarTotalHeight -
                      fabDiameter -
                      margin)
                  .clamp(minY, 99999);

          double resolvedX;
          double resolvedY;

          if (_cartFabOffset != null) {
            resolvedX = _cartFabOffset!.dx;
            resolvedY = _cartFabOffset!.dy;
          } else if (_cartFabXFrac != null && _cartFabYFrac != null) {
            final double xRange = (maxX - minX).abs() < 0.001
                ? 0
                : (maxX - minX);
            final double yRange = (maxY - minY).abs() < 0.001
                ? 0
                : (maxY - minY);
            resolvedX = minX + (_cartFabXFrac!.clamp(0.0, 1.0) * xRange);
            resolvedY = minY + (_cartFabYFrac!.clamp(0.0, 1.0) * yRange);
          } else {
            resolvedX = maxX;
            resolvedY = maxY;
          }

          resolvedX = resolvedX.clamp(minX, maxX);
          resolvedY = resolvedY.clamp(minY, maxY);

          if (_cartFabOffset == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _cartFabOffset = Offset(resolvedX, resolvedY);
              });
            });
          }

          return Stack(
            key: _cartFabStackKey,
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 120),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // 🔹 Carrusel de Recomendados en la parte superior
                    if (_categories.isNotEmpty)
                      _FeaturedCarouselWidget(
                        key: _carouselKey,
                        products: _featuredProducts,
                        onProductTap: (product) => _openProductAndAdd(
                          context: context,
                          product: product,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // 🔹 Barra de Categorías Horizontal
                    if (_categories.isNotEmpty) _buildCategoryChipsBar(),

                    // 🔹 Resumen del pedido
                    if (pedidos.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF1F5F9), Color(0xFFFFFFFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 14,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0B3D4A),
                                    Color(0xFF1B6F81),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Pedidos: ${pedidos.length}",
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Total: S/. ${pedidos.fold<double>(0, (sum, p) {
                                      final unit = (p['price'] is num) ? (p['price'] as num).toDouble() : double.tryParse(p['price'].toString()) ?? 0.0;
                                      final qtyRaw = p['quantity'];
                                      final qty = (qtyRaw is int) ? qtyRaw : int.tryParse(qtyRaw?.toString() ?? '') ?? 1;
                                      final safeQty = qty <= 0 ? 1 : qty;
                                      return sum + (unit * safeQty);
                                    }).toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0B3D4A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _openCart,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0B3D4A),
                                side: BorderSide(
                                  color: const Color(
                                    0xFF0B3D4A,
                                  ).withOpacity(0.25),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Ver',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // ✅ Sección dinámica (CORREGIDA)
                    if (_isLoadingProducts && _categories.isEmpty)
                      const _MenuSkeletonLoader()
                    else if (_productsError != null && _categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          _productsError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No hay productos disponibles en este momento.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final selectedCat = _categories.firstWhere(
                            (c) => c.id == _selectedCategoryId,
                            orElse: () => _categories.first,
                          );
                          return _buildCategorySectionGrid(
                            key: _productListKey,
                            context: context,
                            categoryId: selectedCat.id,
                            title: selectedCat.name,
                            products: selectedCat.products,
                          );
                        },
                      ),
                  ],
                ),
              ),

              // 🔹 FAB draggable
              AnimatedPositioned(
                left: resolvedX,
                top: resolvedY,
                duration: _isDraggingCartFab
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openCart,
                  onPanStart: (details) {
                    setState(() {
                      _isDraggingCartFab = true;
                      _cartFabDragStartGlobal = details.globalPosition;
                      _cartFabDragStartOffset = Offset(resolvedX, resolvedY);
                    });
                  },
                  onPanUpdate: (details) {
                    final startGlobal = _cartFabDragStartGlobal;
                    final startOffset = _cartFabDragStartOffset;
                    if (startGlobal == null || startOffset == null) return;

                    final delta = details.globalPosition - startGlobal;
                    final newX = (startOffset.dx + delta.dx).clamp(minX, maxX);
                    final newY = (startOffset.dy + delta.dy).clamp(minY, maxY);

                    setState(() {
                      _cartFabOffset = Offset(newX, newY);
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _isDraggingCartFab = false;
                      _cartFabDragStartGlobal = null;
                      _cartFabDragStartOffset = null;
                    });

                    _snapCartFabToEdge(
                      minX: minX,
                      maxX: maxX,
                      minY: minY,
                      maxY: maxY,
                    );
                  },
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: _isDraggingCartFab ? 1.06 : 1.0,
                    child: _buildCartFabButton(count: pedidos.length),
                  ),
                ),
              ),
              if (_showInteractiveOnboarding)
                _OnboardingOverlay(
                  carouselKey: _carouselKey,
                  categoryChipsKey: _categoryChipsKey,
                  productListKey: _productListKey,
                  stackKey: _cartFabStackKey,
                  currentStep: _currentOnboardingStep,
                  totalSteps: 3,
                  reservaInferior: homeBottomBarTotalHeight,
                  onNext: _onNextOnboarding,
                  onSkip: _onSkipOnboarding,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final bool shown = prefs.getBool('menu_page_onboarding_shown') ?? false;
    if (!shown) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categories.isNotEmpty) {
          setState(() {
            _showInteractiveOnboarding = true;
            _currentOnboardingStep = 0;
          });
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onNextOnboarding() async {
    if (_currentOnboardingStep < 2) {
      setState(() {
        _currentOnboardingStep++;
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('menu_page_onboarding_shown', true);
      setState(() {
        _showInteractiveOnboarding = false;
      });
    }
  }

  void _onSkipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('menu_page_onboarding_shown', true);
    setState(() {
      _showInteractiveOnboarding = false;
    });
  }

  List<Product> get _featuredProducts {
    if (_categories.isEmpty) return [];
    final selectedCat = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => _categories.first,
    );
    return selectedCat.products.take(5).toList();
  }

  Widget _buildCategoryChipsBar() {
    return Container(
      key: _categoryChipsKey,
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategoryId == cat.id;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryId = cat.id;
                });
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE28F83)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE28F83).withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF0F172A).withOpacity(0.6),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------
  // SECCIÓN DE CATEGORÍA (PREMIUM + LISTA VERTICAL)
  // --------------------
  Widget _buildCategorySectionGrid({
    Key? key,
    required BuildContext context,
    required int categoryId,
    required String title,
    required List<Product> products,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFE28F83),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF062B35),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              for (int index = 0; index < products.length; index++) ...[
                Builder(
                  builder: (context) {
                    final product = products[index];
                    final precioOriginal = product.price;
                    final bool canUseCanje =
                        widget.descuento > 0 && !_canjeYaUsado;
                    final double efectivoDescuento = canUseCanje
                        ? widget.descuento
                        : 0.0;
                    final double precioFinal = canUseCanje
                        ? precioOriginal * (1 - widget.descuento)
                        : precioOriginal;
                    return _PremiumProductGridTile(
                      key: ValueKey<int>(product.id),
                      product: product,
                      descuento: efectivoDescuento,
                      precioOriginal: precioOriginal,
                      precioFinal: precioFinal,
                      onAdd: () => _openProductAndAdd(
                        context: context,
                        product: product,
                      ),
                    );
                  },
                ),
                if (index < products.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------
// TILE PREMIUM para GRID (2 columnas)
// --------------------
class _PremiumProductGridTile extends StatefulWidget {
  const _PremiumProductGridTile({
    super.key,
    required this.product,
    required this.descuento,
    required this.precioOriginal,
    required this.precioFinal,
    required this.onAdd,
  });

  final Product product;
  final double descuento;
  final double precioOriginal;
  final double precioFinal;
  final VoidCallback onAdd;

  @override
  State<_PremiumProductGridTile> createState() =>
      _PremiumProductGridTileState();
}

class _PremiumProductGridTileState extends State<_PremiumProductGridTile> {
  bool _isPressed = false;

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .where((w) => w.isNotEmpty)
        .join(' ');
  }

  Color _getPastelBg(int id) {
    final colors = [
      const Color(0xFFFFF0EC), // Peach pastel
      const Color(0xFFE8F5E9), // Mint green pastel
      const Color(0xFFE1F5FE), // Ice blue pastel
      const Color(0xFFFFFDE7), // Soft yellow pastel
      const Color(0xFFF3E5F5), // Lavender pastel
      const Color(0xFFE0F2F1), // Soft teal pastel
      const Color(0xFFFFF3E0), // Orange pastel
    ];
    return colors[id % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = widget.descuento > 0;

    // Medidas adaptadas al teléfono.
    //
    // Antes el alto de la tarjeta y el recuadro de la imagen estaban fijos en
    // 100 y 84 px. En un iPhone SE el nombre del producto se quedaba sin
    // espacio, y con la letra del sistema agrandada el precio salía fuera de
    // la tarjeta y no se veía. Ahora ambos se calculan a partir del ancho real
    // y del factor de texto, con topes para que la tarjeta no se deforme en un
    // Pro Max ni en una tablet.
    final media = MediaQuery.of(context);
    final double ancho = media.size.width;
    final double escalaTexto = media.textScaler.scale(14) / 14;

    final double altoTarjeta = (100 * escalaTexto).clamp(96.0, 140.0);
    final double ladoImagen = (ancho * 0.22).clamp(64.0, 92.0);
    final double fuenteNombre = (ancho * 0.037).clamp(13.0, 16.0);
    final double fuentePrecio = (ancho * 0.037).clamp(13.0, 16.0);
    final double ladoBoton = (ancho * 0.085).clamp(30.0, 38.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onAdd();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: altoTarjeta,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Contenedor pastel de imagen
              Container(
                width: ladoImagen,
                height: ladoImagen,
                decoration: BoxDecoration(
                  color: _getPastelBg(widget.product.id),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _PremiumGridImage(
                          key: ValueKey<String>(widget.product.image),
                          pathOrUrl: widget.product.image,
                        ),
                      ),
                      if (hasDiscount)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '-${(widget.descuento * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _capitalize(widget.product.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF062B35), // Navy oscuro
                        fontSize: fuenteNombre,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Los precios van en Flexible: con descuento son dos
                    // importes en la misma línea y en un teléfono estrecho se
                    // salían de la tarjeta.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'S/. ${widget.precioFinal.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFE28F83), // Color coral
                              fontSize: fuentePrecio,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'S/. ${widget.precioOriginal.toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: (fuentePrecio - 3).clamp(10.0, 13.0),
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Botón circular +
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Container(
                    width: ladoBoton,
                    height: ladoBoton,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE28F83), // Botón Coral
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x15000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: ladoBoton * 0.56,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumGridImage extends StatelessWidget {
  const _PremiumGridImage({super.key, required this.pathOrUrl});
  final String pathOrUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.grey[200],
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Icon(Icons.local_drink_rounded, size: 34, color: Colors.black26),
      ),
    );

    if (pathOrUrl.isEmpty) return placeholder;

    final trimmed = pathOrUrl.trim();
    final looksLikeEmoji =
        trimmed.isNotEmpty &&
        !trimmed.contains('/') &&
        trimmed.runes.length <= 4 &&
        trimmed.codeUnits.any((c) => c > 127);
    if (looksLikeEmoji) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Text(trimmed, style: const TextStyle(fontSize: 52)),
      );
    }

    if (pathOrUrl.startsWith('data:image') || isBase64(pathOrUrl)) {
      try {
        final base64Str = extractBase64(pathOrUrl);
        final bytes = base64Decode(base64Str);
        return Image.memory(
          key: ValueKey<String>(pathOrUrl),
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    }

    if (pathOrUrl.startsWith('http')) {
      return CachedNetworkImage(
        key: ValueKey<String>(pathOrUrl),
        imageUrl: pathOrUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
        memCacheWidth: 250,
        memCacheHeight: 250,
        maxWidthDiskCache: 500,
        maxHeightDiskCache: 500,
      );
    }

    return Image.asset(
      key: ValueKey<String>(pathOrUrl),
      pathOrUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final Product product;
  final double descuento;
  final String? allowedSize;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.descuento = 0.0,
    this.allowedSize,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _SelectableTopping {
  final Topping topping;
  final bool selected;
  final int quantity; // 0, 1 o 2 unidades

  const _SelectableTopping({
    required this.topping,
    this.selected = false,
    this.quantity = 0,
  });

  _SelectableTopping copyWith({
    Topping? topping,
    bool? selected,
    int? quantity,
  }) {
    return _SelectableTopping(
      topping: topping ?? this.topping,
      selected: selected ?? this.selected,
      quantity: quantity ?? this.quantity,
    );
  }
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  void _handleAddToCartPremium() {
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xCC000000),
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Agregando al carrito...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    final sizeExtra = _sizePrices[selectedSize] ?? 0.0;
    final iceExtra = _icePrices[selectedIce] ?? 0.0;
    final selectedToppings = toppings.where((t) => t.quantity > 0);
    final toppingsTotal = selectedToppings.fold<double>(
      0.0,
      (sum, t) => sum + (t.topping.price * t.quantity),
    );

    // ✅ Bruto = lo que costaría sin canje. Neto = lo que se cobra realmente.
    //    Con un canje del 100% el neto es 0 aunque el vaso sea grande.
    final unitTotalBruto = basePrice + sizeExtra + iceExtra + toppingsTotal;
    final unitTotal = _calcularTotal();
    final descuentoMonto = ((unitTotalBruto - unitTotal) * 100).round() / 100;

    // Normalizar imagen para que siempre sea URL del backend si corresponde
    String img = widget.product.image;
    if (img.isNotEmpty &&
        !img.startsWith('http') &&
        !img.startsWith('data:image') &&
        !img.endsWith('.svg')) {
      img = '${BackendConfig.baseUrl}bubblesplash/productos/img/$img';
    }
    final pedido = {
      'id': widget.product.id,
      'name': widget.product.name,
      'desc': widget.product.description,
      'image': img,
      'price': unitTotal,
      'priceOriginal': unitTotalBruto,
      'discountPercent': widget.descuento,
      'discountAmount': descuentoMonto,
      'basePrice': basePrice,
      'sizeExtra': sizeExtra,
      'iceExtra': iceExtra,
      'toppingsTotal': toppingsTotal,
      'size': selectedSize,
      'ice': selectedIce,
      'toppings': toppings
          .where((t) => t.quantity > 0)
          .map(
            (t) => {
              'id': t.topping.id,
              'name': t.topping.name,
              'price': t.topping.price,
              'qty': t.quantity,
            },
          )
          .toList(),
    };

    Future<void>.delayed(const Duration(milliseconds: 250)).then((_) {
      if (!mounted) return;
      navigator.pop(); // cierra loader
      navigator.pop(pedido); // retorna pedido
    });
  }

  String selectedSize = 'MEDIANO';
  String selectedIce = 'Normal';

  late double basePrice;
  double totalPrice = 0.0;

  bool _isLoadingDetail = false;
  String? _detailError;

  // Precios adicionales por tamaño de vaso (se llenan desde API)
  Map<String, double> _sizePrices = {'MEDIANO': 0.0};

  /// Nombre legible de cada tamaño, indexado por su código.
  ///
  /// El código es lo que viaja al backend (`NORMAL`) y la etiqueta lo que ve
  /// el cliente (`Mediano`). Se separan porque el código tiene que ser exacto
  /// para que se cobre el recargo correcto.
  Map<String, String> _sizeLabels = {};

  // Precios adicionales por nivel de hielo
  final Map<String, double> _icePrices = {
    'Normal': 0.0,
    'Extra hielo': 0.0,
    'Poco hielo': 0.0,
  };

  List<_SelectableTopping> toppings = [];

  @override
  void initState() {
    super.initState();
    // basePrice queda SIN descuento: el descuento se aplica al final sobre el
    // total de la unidad (ver _calcularTotal).
    basePrice = widget.product.price;
    totalPrice = _calcularTotal();
    _loadProductDetail();
    // Paralelizar la carga de tamaños y toppings
    Future.wait([_loadProductSizes(), _loadToppings()]);
  }

  Future<void> _loadProductDetail() async {
    final int id = widget.product.id;
    if (id == 0) return;

    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuest') ?? false;
      final rawToken = prefs.getString('access_token');

      if ((rawToken == null || rawToken.trim().isEmpty) && !isGuest) {
        if (!mounted) return;
        setState(() {
          _isLoadingDetail = false;
          _detailError =
              'No hay access token para cargar el detalle del producto.';
        });
        return;
      }

      final token = (rawToken ?? '').trim();
      final uri = Uri.parse(
        ApiConstants.baseUrl + '/bubblesplash/productos/$id/',
      );

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      http.Response response = await http.get(uri, headers: headers);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final String priceStr = (data['pro_de_baseprice'] ?? '0').toString();
        final double backendPrice = double.tryParse(priceStr) ?? basePrice;

        setState(() {
          basePrice = backendPrice;
          totalPrice = _calcularTotal();
          _isLoadingDetail = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _isLoadingDetail = false;
          _detailError =
              'Tu sesión ha expirado. Inicia sesión nuevamente para ver el detalle.';
        });
      } else {
        setState(() {
          _isLoadingDetail = false;
          _detailError = 'Error al cargar detalle (${response.statusCode}).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDetail = false;
        _detailError = 'Error al cargar detalle: $e';
      });
    }
  }

  Future<void> _loadToppings() async {
    try {
      final int productId = widget.product.id;
      if (productId == 0) return;

      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuest') ?? false;
      final rawToken = prefs.getString('access_token');
      if ((rawToken == null || rawToken.trim().isEmpty) && !isGuest) {
        debugPrint('No hay access token para cargar toppings');
        return;
      }

      final token = (rawToken ?? '').trim();
      final baseUrl = ApiConstants.baseUrl;

      // 1) Obtener qué toppings corresponden a este producto
      final uriMap = Uri.parse(baseUrl + '/bubblesplash/productos-toppings/');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      http.Response responseMap = await http.get(uriMap, headers: headers);

      if (responseMap.statusCode != 200) {
        debugPrint(
          'Error al cargar mapa productos-toppings: ${responseMap.statusCode} ${responseMap.body}',
        );
        return;
      }

      final List<dynamic> dataMap =
          jsonDecode(responseMap.body) as List<dynamic>;
      final Set<int> allowedToppingIds = <int>{};

      for (final item in dataMap.whereType<Map<String, dynamic>>()) {
        final dynamic rawProId =
            item['pro_int_id'] ?? item['producto'] ?? item['product_id'];
        int proId;
        if (rawProId is int) {
          proId = rawProId;
        } else {
          proId = int.tryParse(rawProId?.toString() ?? '') ?? -1;
        }
        if (proId != productId) continue;

        final dynamic rawTopId =
            item['top_int_id'] ?? item['topping'] ?? item['top_id'];
        int topId;
        if (rawTopId is int) {
          topId = rawTopId;
        } else {
          topId = int.tryParse(rawTopId?.toString() ?? '') ?? 0;
        }
        if (topId > 0) allowedToppingIds.add(topId);
      }

      if (allowedToppingIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          toppings = [];
          totalPrice = _calcularTotal();
        });
        return;
      }

      // 2) Obtener el catálogo completo de toppings y filtrar por los permitidos
      final uriToppings = Uri.parse(baseUrl + '/bubblesplash/toppings/');

      final headersToppings = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token.isNotEmpty) {
        headersToppings['Authorization'] = 'Bearer $token';
      }

      http.Response responseToppings = await http.get(
        uriToppings,
        headers: headersToppings,
      );

      if (responseToppings.statusCode != 200) {
        debugPrint(
          'Error al cargar toppings: ${responseToppings.statusCode} ${responseToppings.body}',
        );
        return;
      }

      final List<dynamic> data =
          jsonDecode(responseToppings.body) as List<dynamic>;
      final List<_SelectableTopping> nuevosToppings = data
          .whereType<Map<String, dynamic>>()
          .where(
            (item) =>
                (item['txt_status'] ?? '').toString().toUpperCase() == 'ACTIVO',
          )
          .map((item) {
            final int id = (item['top_int_id'] ?? 0) is int
                ? item['top_int_id'] as int
                : int.tryParse(item['top_int_id'].toString()) ?? 0;
            return {'map': item, 'id': id};
          })
          .where((wrapper) => allowedToppingIds.contains(wrapper['id'] as int))
          .map((wrapper) {
            final Map<String, dynamic> item =
                wrapper['map'] as Map<String, dynamic>;
            final int id = wrapper['id'] as int;
            final String name = (item['top_txt_name'] ?? '').toString();
            final String priceStr = (item['top_de_price'] ?? '0').toString();
            final double price = double.tryParse(priceStr) ?? 0.0;
            return _SelectableTopping(
              topping: Topping(id: id, name: name, price: price),
              selected: false,
              quantity: 0,
            );
          })
          .toList();

      if (!mounted) return;
      setState(() {
        toppings = nuevosToppings;
        totalPrice = _calcularTotal();
      });
    } catch (e) {
      debugPrint('Excepción al cargar toppings: $e');
    }
  }

  Future<void> _loadProductSizes() async {
    final int productId = widget.product.id;
    if (productId == 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuest') ?? false;
      final rawToken = prefs.getString('access_token');
      if ((rawToken == null || rawToken.trim().isEmpty) && !isGuest) {
        debugPrint('No hay access token para cargar tamaños de vaso');
        return;
      }

      final token = (rawToken ?? '').trim();
      final uri = Uri.parse(
        ApiConstants.baseUrl + '/bubblesplash/productos-sizes/',
      );

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      http.Response response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        debugPrint(
          'Error al cargar tamaños: ${response.statusCode} ${response.body}',
        );
        return;
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final Map<String, double> newSizes = {};
      final Map<String, String> newLabels = {};

      for (final item in data.whereType<Map<String, dynamic>>()) {
        final int proId = (item['pro_int_id'] ?? -1) is int
            ? item['pro_int_id'] as int
            : int.tryParse(item['pro_int_id'].toString()) ?? -1;
        if (proId != productId) continue;

        final String sizeName = (item['prs_txt_size'] ?? '').toString();
        final String extraStr = (item['prs_de_extraprice'] ?? '0').toString();
        final double extra = double.tryParse(extraStr) ?? 0.0;
        if (sizeName.isEmpty) continue;
        newSizes[sizeName] = extra;

        // El backend manda el nombre legible ya resuelto; si no viniera se
        // deriva del código, para no enseñar nunca 'NORMAL' al cliente.
        final String etiqueta = (item['prs_txt_label'] ?? '').toString().trim();
        newLabels[sizeName] = etiqueta.isNotEmpty
            ? etiqueta
            : etiquetaTamano(sizeName);
      }

      if (newSizes.isEmpty || !mounted) return;
      setState(() {
        _sizePrices = newSizes;
        _sizeLabels = newLabels;
        final String? allowed = widget.allowedSize?.trim();
        if (allowed != null && allowed.isNotEmpty) {
          final matchingSize = _sizePrices.keys.firstWhere((k) {
            final kUpper = k.toUpperCase();
            final aUpper = allowed.toUpperCase();
            return kUpper == aUpper ||
                kUpper.contains(aUpper) ||
                aUpper.contains(kUpper) ||
                (aUpper.startsWith('MED') && kUpper.startsWith('MED')) ||
                (aUpper.startsWith('PEQ') && kUpper.startsWith('PEQ')) ||
                (aUpper.startsWith('GRA') && kUpper.startsWith('GRA'));
          }, orElse: () => '');
          if (matchingSize.isNotEmpty) {
            selectedSize = matchingSize;
          }
        }
        if (!_sizePrices.keys.contains(selectedSize)) {
          final zeroExtra = _sizePrices.entries
              .firstWhere(
                (e) => e.value == 0.0,
                orElse: () => _sizePrices.entries.first,
              )
              .key;
          selectedSize = zeroExtra;
        }
        totalPrice = _calcularTotal();
      });
    } catch (e) {
      debugPrint('Excepción al cargar tamaños: $e');
    }
  }

  /// Precio de una unidad SIN descuento: base + extra de vaso + hielo + toppings.
  double get _unitTotalBruto {
    final sizeExtra = _sizePrices[selectedSize] ?? 0.0;
    final iceExtra = _icePrices[selectedIce] ?? 0.0;
    final toppingsTotal = toppings.fold<double>(
      0.0,
      (sum, t) => sum + (t.topping.price * t.quantity),
    );

    return basePrice + sizeExtra + iceExtra + toppingsTotal;
  }

  /// ✅ El descuento del canje se aplica sobre el TOTAL de la unidad, no solo
  /// sobre el precio base. Así una oferta del 100% deja el producto en S/ 0.00
  /// aunque el vaso sea grande y lleve toppings (los extras tampoco se cobran).
  double _calcularTotal() {
    final double bruto = _unitTotalBruto;
    final double factor = (1 - widget.descuento).clamp(0.0, 1.0);
    final double neto = bruto * factor;

    // Evita céntimos residuales por punto flotante (0.00000001).
    return (neto * 100).round() / 100;
  }

  void _changeToppingQuantity(int index, int delta) {
    final current = toppings[index];
    final currentQty = current.quantity;

    // Nueva cantidad propuesta (0, 1 o 2)
    int nextQty = currentQty + delta;
    if (nextQty < 0) nextQty = 0;
    if (nextQty > 2) nextQty = 2;

    // Cantidad total actual de unidades de toppings
    final currentTotalUnits = toppings.fold<int>(
      0,
      (sum, t) => sum + t.quantity,
    );

    final newTotalUnits = currentTotalUnits - currentQty + nextQty;

    if (newTotalUnits > 3) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _PremiumFeedbackModal(
          message: 'Solo puedes elegir hasta 3 toppings en total.',
        ),
      );
      return;
    }

    final nextSelected = nextQty > 0;

    setState(() {
      toppings[index] = current.copyWith(
        selected: nextSelected,
        quantity: nextQty,
      );
      totalPrice = _calcularTotal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: SB.bg,
      body: Stack(
        children: [
          // Fondo glassmorphism premium
          Positioned.fill(
            child: Container(
              decoration: SB
                  .glassBox(radius: BorderRadius.zero)
                  .copyWith(
                    gradient: SB.gradBrand,
                    color: SB.bg.withOpacity(0.98),
                    boxShadow: [],
                  ),
            ),
          ),
          // Overlay de luz suave para más profundidad
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.10),
                      Colors.transparent,
                      Colors.black.withOpacity(0.16),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // Imagen y glass overlay
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: 320,
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.only(left: 8, top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                title: Text(
                  widget.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(32),
                          ),
                          child: _buildDetailImage(widget.product.image),
                        ),
                      ),
                      // Glass overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.10),
                              Colors.black.withOpacity(0.60),
                              SB.navy.withOpacity(0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Tarjeta glass flotante
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'S/. ${totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (widget.descuento > 0)
                                  _DiscountPill(
                                    text:
                                        '-${(widget.descuento * 100).toInt()}%',
                                  ),
                                if (_isLoadingDetail)
                                  const _StatusPill(
                                    text: 'Actualizando precio...',
                                  ),
                                if (_detailError != null)
                                  _StatusPill(
                                    text: 'Error de detalle',
                                    danger: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // BODY PREMIUM ESTILO BOTTOM SHEET
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
                    child: Column(
                      children: [
                        if (_detailError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: PremiumCard(
                              glass: true,
                              shadow: false,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _detailError!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (widget.product.description.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: PremiumCard(
                              glass: true,
                              shadow: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(title: 'Descripción'),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.product.description,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                      color: SB.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Tamaño de vaso
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PremiumCard(
                            glass: true,
                            shadow: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle(title: 'Tamaño de vaso'),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        (_sizePrices.keys.isNotEmpty
                                                ? _sizePrices.keys.toList()
                                                : ['MEDIANO'])
                                            .map((size) {
                                              final String? allowed = widget
                                                  .allowedSize
                                                  ?.trim();
                                              final String sUpper = size
                                                  .toUpperCase();
                                              final String aUpper =
                                                  (allowed ?? '').toUpperCase();
                                              final bool isMatch =
                                                  allowed != null &&
                                                  allowed.isNotEmpty &&
                                                  (sUpper == aUpper ||
                                                      sUpper.contains(aUpper) ||
                                                      aUpper.contains(sUpper) ||
                                                      (aUpper.startsWith(
                                                            'MED',
                                                          ) &&
                                                          sUpper.startsWith(
                                                            'MED',
                                                          )) ||
                                                      (aUpper.startsWith(
                                                            'PEQ',
                                                          ) &&
                                                          sUpper.startsWith(
                                                            'PEQ',
                                                          )) ||
                                                      (aUpper.startsWith(
                                                            'GRA',
                                                          ) &&
                                                          sUpper.startsWith(
                                                            'GRA',
                                                          )));
                                              final bool isRestricted =
                                                  allowed != null &&
                                                  allowed.isNotEmpty &&
                                                  !isMatch;
                                              final selected =
                                                  selectedSize == size;
                                              final extra =
                                                  _sizePrices[size] ?? 0.0;
                                              String priceLabel;
                                              if (isRestricted) {
                                                priceLabel = 'No disponible';
                                              } else if (extra == 0.0) {
                                                priceLabel = 'Sin recargo';
                                              } else if (extra > 0.0) {
                                                priceLabel =
                                                    '+S/. ${extra.toStringAsFixed(2)}';
                                              } else {
                                                priceLabel =
                                                    '-S/. ${(-extra).toStringAsFixed(2)}';
                                              }

                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 10,
                                                ),
                                                child: Opacity(
                                                  opacity: isRestricted
                                                      ? 0.45
                                                      : 1.0,
                                                  child: GestureDetector(
                                                    onTap: isRestricted
                                                        ? () {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Este canje solo aplica para vaso $allowed.',
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        : () {
                                                            setState(() {
                                                              selectedSize =
                                                                  size;
                                                              totalPrice =
                                                                  _calcularTotal();
                                                            });
                                                          },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 220,
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 10,
                                                          ),
                                                      decoration:
                                                          PremiumPill.decoration(
                                                            selected: selected,
                                                            glow: selected,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: selected
                                                                  ? Colors.white
                                                                        .withOpacity(
                                                                          0.18,
                                                                        )
                                                                  : SB.bg,
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .local_drink_rounded,
                                                              size: 18,
                                                              color: selected
                                                                  ? Colors.white
                                                                  : SB.teal,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                // La base guarda el CÓDIGO (NORMAL);
                                                                // al cliente se le enseña "Mediano".
                                                                _sizeLabels[size] ??
                                                                    etiquetaTamano(
                                                                      size,
                                                                    ),
                                                                style: TextStyle(
                                                                  color:
                                                                      selected
                                                                      ? Colors
                                                                            .white
                                                                      : SB.text,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                priceLabel,
                                                                style: theme
                                                                    .textTheme
                                                                    .labelSmall
                                                                    ?.copyWith(
                                                                      color:
                                                                          selected
                                                                          ? Colors.white.withOpacity(
                                                                              0.9,
                                                                            )
                                                                          : SB.sub,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            })
                                            .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Toppings (ocultos)
                        Visibility(
                          visible: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: PremiumCard(
                              glass: true,
                              shadow: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle(
                                    title: 'Toppings (máx. 3)',
                                  ),
                                  const SizedBox(height: 8),
                                  toppings.isEmpty
                                      ? const Text(
                                          'No hay toppings disponibles.',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: List.generate(toppings.length, (
                                            index,
                                          ) {
                                            final t = toppings[index];
                                            final selected = t.quantity > 0;
                                            final priceLabel =
                                                '+S/. ${t.topping.price.toStringAsFixed(2)}';

                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 9,
                                                  ),
                                              decoration:
                                                  PremiumPill.decoration(
                                                    selected: selected,
                                                    glow: selected,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Botón disminuir
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _changeToppingQuantity(
                                                          index,
                                                          -1,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: selected
                                                            ? Colors.white
                                                                  .withOpacity(
                                                                    0.18,
                                                                  )
                                                            : SB.bg,
                                                      ),
                                                      child: Icon(
                                                        Icons.remove,
                                                        size: 18,
                                                        color: selected
                                                            ? Colors.white
                                                            : SB.teal,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Info topping
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        t.topping.name,
                                                        style: TextStyle(
                                                          color: selected
                                                              ? Colors.white
                                                              : SB.text,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        t.quantity > 0
                                                            ? '$priceLabel · x${t.quantity}'
                                                            : priceLabel,
                                                        style: theme
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color: selected
                                                                  ? Colors.white
                                                                        .withOpacity(
                                                                          0.9,
                                                                        )
                                                                  : SB.sub,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Botón aumentar
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _changeToppingQuantity(
                                                          index,
                                                          1,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: selected
                                                            ? Colors.white
                                                                  .withOpacity(
                                                                    0.18,
                                                                  )
                                                            : SB.bg,
                                                      ),
                                                      child: Icon(
                                                        Icons.add,
                                                        size: 18,
                                                        color: selected
                                                            ? Colors.white
                                                            : SB.teal,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tip: Puedes tocar toppings para seleccionar (máx. 3).',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Nivel de hielo
                        PremiumCard(
                          glass: true,
                          shadow: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(title: 'Nivel de hielo'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    ['Normal', 'Extra hielo', 'Poco hielo'].map(
                                      (ice) {
                                        final selected = selectedIce == ice;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          child: ChoiceChip(
                                            label: Text(_labelIce(ice)),
                                            selected: selected,
                                            onSelected: (v) {
                                              if (!v) return;
                                              setState(() {
                                                selectedIce = ice;
                                                totalPrice = _calcularTotal();
                                              });
                                            },
                                            selectedColor: SB.teal,
                                            backgroundColor: SB.card,
                                            labelStyle: TextStyle(
                                              color: selected
                                                  ? Colors.white
                                                  : SB.text,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            shape:
                                                PremiumPill.shape(
                                                      selected: selected,
                                                      glow: selected,
                                                    )
                                                    as OutlinedBorder,
                                            elevation: 0,
                                            pressElevation: 0,
                                          ),
                                        );
                                      },
                                    ).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // BOTTOM BAR PREMIUM
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: PremiumCard(
                  glass: false,
                  shadow: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: SB.sub,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'S/. ${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: SB.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Incluye tamaño, hielo y toppings',
                              style: TextStyle(
                                fontSize: 11,
                                color: SB.sub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: 1.0,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text(
                            'Agregar',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SB.teal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            shadowColor: SB.mint.withOpacity(0.18),
                          ),
                          onPressed: _handleAddToCartPremium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelSize(String size) {
    final extra = _sizePrices[size] ?? 0.0;
    if (extra == 0) return size;
    if (extra > 0) return "$size (+S/. ${extra.toStringAsFixed(2)})";
    return "$size (-S/. ${extra.abs().toStringAsFixed(2)})";
  }

  String _labelIce(String ice) {
    final extra = _icePrices[ice] ?? 0.0;
    if (extra == 0) return ice;
    return "$ice (+S/. ${extra.toStringAsFixed(2)})";
  }

  Widget _buildDetailImage(String pathOrUrl) {
    final placeholder = Container(
      color: Colors.grey[300],
      width: double.infinity,
      height: 220,
    );

    if (pathOrUrl.isEmpty) {
      return placeholder;
    }

    // Imagen en base64
    if (pathOrUrl.startsWith('data:image') || isBase64(pathOrUrl)) {
      try {
        final base64Str = extractBase64(pathOrUrl);
        final bytes = base64Decode(base64Str);
        return Image.memory(
          key: ValueKey<String>(pathOrUrl),
          bytes,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return placeholder;
          },
        );
      } catch (e) {
        return placeholder;
      }
    }

    if (pathOrUrl.startsWith('http')) {
      return CachedNetworkImage(
        key: ValueKey<String>(pathOrUrl),
        imageUrl: pathOrUrl,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
        memCacheWidth: 600,
        memCacheHeight: 440,
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 880,
      );
    }

    return Image.asset(
      key: ValueKey<String>(pathOrUrl),
      pathOrUrl,
      width: double.infinity,
      height: 220,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return placeholder;
      },
    );
    // =============================
    // Funciones auxiliares para base64
    // =============================
  }
}

class CategoryProductsPage extends StatefulWidget {
  final int categoryId;
  final String categoryTitle;
  final List<Product> products;
  final double descuento;
  final List<Map<String, dynamic>> initialPedidos;
  final int? ofcIntId;
  final String? allowedSize;

  const CategoryProductsPage({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.products,
    required this.descuento,
    required this.initialPedidos,
    this.ofcIntId,
    this.allowedSize,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  late List<Map<String, dynamic>> _pedidos;
  String _q = '';

  // Indica si ya se usó el canje/descuento en algún producto del carrito local
  bool get _canjeYaUsado => _pedidos.any((p) => p['isPromoItem'] == true);

  /// Se llegó aquí desde un canje: elegir producto → pagar, sin pasos extra.
  bool get _isCanjeExpress =>
      (widget.ofcIntId != null && widget.ofcIntId! > 0) || widget.descuento > 0;

  @override
  void initState() {
    super.initState();
    _pedidos = List<Map<String, dynamic>>.from(widget.initialPedidos);
  }

  List<Product> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products.where((p) {
      final name = p.name.toLowerCase();
      final desc = p.description.toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  double _totalCarrito() {
    return _pedidos.fold<double>(0.0, (sum, p) {
      final unit = (p['price'] is num)
          ? (p['price'] as num).toDouble()
          : double.tryParse(p['price'].toString()) ?? 0.0;

      final qtyRaw = p['quantity'];
      final qty = (qtyRaw is int)
          ? qtyRaw
          : int.tryParse(qtyRaw?.toString() ?? '') ?? 1;

      final safeQty = qty <= 0 ? 1 : qty;
      return sum + (unit * safeQty);
    });
  }

  Future<void> _openCartHere() async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => CartPage(
          initialPedidos: _pedidos,
          descuento: widget.descuento,
          ofcIntId: widget.ofcIntId,
        ),
      ),
    );

    if (updated != null) {
      setState(() => _pedidos = updated);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'cart_pedidos',
        _pedidos.map((p) => jsonEncode(p)).toList(),
      );
    }
  }

  Future<void> _openDetailAndAdd(Product product) async {
    // Si esta pantalla viene de un canje/oferta y ya se usó
    // en un producto, no permitimos agregar más desde aquí.
    if (widget.descuento > 0 && !_canjeYaUsado == false) {
      // !_canjeYaUsado == false  =>  _canjeYaUsado == true
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => const _PremiumFeedbackModal(
            message:
                'Ya usaste tu canje en un producto. Esta oferta solo aplica a un producto por pedido.',
          ),
        );
      }
      return;
    }

    final bool canUseCanje = widget.descuento > 0 && !_canjeYaUsado;

    final rawPedido = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: product,
          descuento: canUseCanje ? widget.descuento : 0.0,
          allowedSize: canUseCanje ? widget.allowedSize : null,
        ),
      ),
    );

    if (!mounted) return;

    if (rawPedido != null) {
      final pedido = Map<String, dynamic>.from(rawPedido as Map);

      if (canUseCanje && widget.descuento > 0) {
        pedido['isPromoItem'] = true;
      }

      setState(() => _pedidos.add(pedido));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'cart_pedidos',
        _pedidos.map((p) => jsonEncode(p)).toList(),
      );

      if (!mounted) return;

      // ✅ Canje: directo al pago, sin ofrecer seguir comprando.
      if (_isCanjeExpress) {
        await _openCartHere();
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _PremiumFeedbackModal(
          message: 'Producto agregado al carrito',
          primaryLabel: 'Ver carrito',
          onPrimary: _openCartHere,
          secondaryLabel: 'Ver productos',
          onSecondary: () {}, // se queda en la categoría
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final products = _filtered;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _pedidos); // ✅ devuelve carrito al MenuPage
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0B3D4A),
          title: Text(
            widget.categoryTitle,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
            color: Colors.white,
          ),
        ),

        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Buscar bebida...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),

            if (_pedidos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF1F5F9), Color(0xFFFFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 12,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B3D4A), Color(0xFF1B6F81)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Carrito: ${_pedidos.length} • Total: S/. ${_totalCarrito().toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0B3D4A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _openCartHere,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B3D4A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Ver',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: products.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron productos.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: products.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final precioOriginal = product.price;
                          final bool canUseCanje =
                              widget.descuento > 0 && !_canjeYaUsado;
                          final double efectivoDescuento = canUseCanje
                              ? widget.descuento
                              : 0.0;
                          final double precioFinal = canUseCanje
                              ? precioOriginal * (1 - widget.descuento)
                              : precioOriginal;

                          return _PremiumProductGridTile(
                            product: product,
                            descuento: efectivoDescuento,
                            precioOriginal: precioOriginal,
                            precioFinal: precioFinal,
                            onAdd: () => _openDetailAndAdd(product),
                          );
                        },
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Text(
                '${products.length} producto(s) en ${widget.categoryTitle}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xFF1B6F81), Color(0xFF12A3B6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF111827).withOpacity(0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountPill extends StatelessWidget {
  const _DiscountPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF128FA0)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, this.danger = false});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? Colors.redAccent.withOpacity(0.25)
        : Colors.white.withOpacity(0.16);
    final bd = danger
        ? Colors.redAccent.withOpacity(0.40)
        : Colors.white.withOpacity(0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: danger ? Colors.white : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PremiumFeedbackModal extends StatelessWidget {
  final String message;

  final String? primaryLabel;
  final VoidCallback? onPrimary;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _PremiumFeedbackModal({
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1B6F81),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 18),

                if (primaryLabel != null && onPrimary != null)
                  Row(
                    children: [
                      // ⬅️ Botón secundario (continuar / ver productos)
                      if (secondaryLabel != null && onSecondary != null)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onSecondary!();
                            },
                            child: Text(
                              secondaryLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      if (secondaryLabel != null) const SizedBox(width: 12),

                      // ✅ Botón principal (Ver carrito)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1B6F81),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onPrimary!();
                          },
                          child: Text(
                            primaryLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// INTERACTIVE ONBOARDING SPOTLIGHT OVERLAY
// ==========================================
class _OnboardingOverlay extends StatefulWidget {
  final GlobalKey carouselKey;
  final GlobalKey categoryChipsKey;
  final GlobalKey productListKey;
  final GlobalKey stackKey;
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final int totalSteps;

  /// Alto de la barra de navegación inferior de la pantalla principal.
  ///
  /// Se dibuja por encima de esta zona y captura las pulsaciones, así que la
  /// tarjeta de la guía no puede invadirla o su botón deja de responder.
  final double reservaInferior;

  const _OnboardingOverlay({
    required this.carouselKey,
    required this.categoryChipsKey,
    required this.productListKey,
    required this.stackKey,
    required this.currentStep,
    required this.onNext,
    required this.onSkip,
    required this.totalSteps,
    required this.reservaInferior,
  });

  @override
  State<_OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<_OnboardingOverlay> {
  Rect? _targetRect;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateRect();
  }

  @override
  void didUpdateWidget(covariant _OnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _updateRect();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRect() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final key = _getCurrentKey();
      final context = key.currentContext;
      final stackContext = widget.stackKey.currentContext;
      if (context != null && stackContext != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        final stackBox = stackContext.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize && stackBox != null) {
          final offset = renderBox.localToGlobal(
            Offset.zero,
            ancestor: stackBox,
          );
          final size = renderBox.size;
          setState(() {
            _targetRect = Rect.fromLTWH(
              offset.dx - 8,
              offset.dy - 8,
              size.width + 16,
              size.height + 16,
            );
          });
        }
      } else {
        _updateRect(); // retry if context not loaded yet
      }
    });
  }

  GlobalKey _getCurrentKey() {
    switch (widget.currentStep) {
      case 0:
        return widget.carouselKey;
      case 1:
        return widget.categoryChipsKey;
      case 2:
      default:
        return widget.productListKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepData = _getStepData();

    // El alto se toma del ÁREA REAL donde vive la guía, no de la pantalla.
    //
    // `_targetRect` se mide respecto al Stack de la página, así que mezclarlo
    // con `MediaQuery.size.height` comparaba dos sistemas de coordenadas
    // distintos: la pantalla incluye la barra superior, y la página se dibuja
    // por debajo de la barra de navegación inferior (`extendBody: true`). El
    // resultado era que la guía se creía con más espacio del que tenía y la
    // tarjeta terminaba bajo la barra inferior, que se lleva los toques: el
    // botón se veía, pero no respondía.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double alto = constraints.maxHeight;

        const double margen = 16;
        const double limiteArriba = margen;
        // Se reserva la barra de navegación de la pantalla principal, que se
        // pinta ENCIMA de esta zona y captura las pulsaciones.
        final double limiteAbajo = widget.reservaInferior + margen;

        double? tooltipTop;
        double? tooltipBottom;
        double maxAltoTarjeta;

        if (_targetRect != null) {
          final rect = _targetRect!;

          // Se mide el hueco a cada lado del elemento resaltado y se elige el
          // mayor, en vez de decidir por un umbral fijo del 55 % que dejaba la
          // tarjeta apretada cuando el objetivo caía justo en el medio.
          final double huecoAbajo = alto - limiteAbajo - (rect.bottom + margen);
          final double huecoArriba = (rect.top - margen) - limiteArriba;

          if (huecoAbajo >= huecoArriba) {
            tooltipTop = rect.bottom + margen;
            maxAltoTarjeta = huecoAbajo;
          } else {
            tooltipBottom = (alto - rect.top) + margen;
            maxAltoTarjeta = huecoArriba;
          }
        } else {
          tooltipTop = alto / 3;
          maxAltoTarjeta = alto - tooltipTop - limiteAbajo;
        }

        // Suelo de seguridad: si el elemento resaltado ocupa casi todo el alto
        // no queda hueco a ningún lado. En ese caso se centra la tarjeta sobre
        // el contenido, que es preferible a dejarla fuera de la vista.
        final double alturaUtil = alto - limiteArriba - limiteAbajo;
        final double minimoTarjeta = alturaUtil < 200 ? alturaUtil : 200.0;

        if (maxAltoTarjeta < minimoTarjeta) {
          maxAltoTarjeta = alturaUtil * 0.7;
          tooltipTop = limiteArriba + (alturaUtil - maxAltoTarjeta) / 2;
          tooltipBottom = null;
        }

        maxAltoTarjeta = maxAltoTarjeta.clamp(minimoTarjeta, alturaUtil);

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    painter: _SpotlightPainter(targetRect: _targetRect),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              top: tooltipTop,
              bottom: tooltipBottom,
              child: ConstrainedBox(
                // Techo al alto de la tarjeta: sin él, un texto largo o la letra
                // del sistema agrandada la estiraban hasta sacar el botón
                // «Siguiente» fuera de la pantalla.
                constraints: BoxConstraints(maxHeight: maxAltoTarjeta),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        color: Colors.white,
                        elevation: 16,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Guía de Uso • ${widget.currentStep + 1}/${widget.totalSteps}',
                                    style: const TextStyle(
                                      color: Colors.black38,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onSkip,
                                    child: const Text(
                                      'Saltar',
                                      style: TextStyle(
                                        color: Color(0xFFE28F83),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // El contenido del paso cede espacio antes que el pie:
                              // si no cabe, se desplaza aquí dentro y los controles de
                              // navegación siguen a la vista.
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFE28F83,
                                          ).withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          stepData['icon'] as IconData,
                                          color: const Color(0xFFE28F83),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              stepData['title'] as String,
                                              style: const TextStyle(
                                                color: Color(0xFF062B35),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              stepData['desc'] as String,
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                        widget.totalSteps,
                                        (i) {
                                          return Container(
                                            width: i == widget.currentStep
                                                ? 16
                                                : 6,
                                            height: 6,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: i == widget.currentStep
                                                  ? const Color(0xFFE28F83)
                                                  : Colors.black12,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE28F83),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: widget.onNext,
                                    child: Text(
                                      widget.currentStep ==
                                              widget.totalSteps - 1
                                          ? 'Comenzar'
                                          : 'Siguiente',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _getStepData() {
    switch (widget.currentStep) {
      case 0:
        return {
          'icon': Icons.swap_horizontal_circle_rounded,
          'title': 'Carrusel de Recomendados',
          'desc':
              'Desliza de izquierda a derecha sobre las bebidas en la parte superior para explorar lo más recomendado.',
        };
      case 1:
        return {
          'icon': Icons.category_rounded,
          'title': 'Pestañas de Categoría',
          'desc':
              'Pulsa sobre las categorías para cambiar de sección y filtrar las bebidas al instante.',
        };
      case 2:
      default:
        return {
          'icon': Icons.swipe_vertical_rounded,
          'title': 'Desliza y Explora',
          'desc':
              'Desliza hacia abajo para ver la lista completa. Pulsa (+) para añadir directamente al carrito o presiona la tarjeta para ver toppings.',
        };
    }
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double borderRadius;

  _SpotlightPainter({this.targetRect, this.borderRadius = 20});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.70);
    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final backgroundPath = Path()..addRect(Offset.zero & size);
    final targetPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(targetRect!, Radius.circular(borderRadius)),
      );

    final path = Path.combine(
      PathOperation.difference,
      backgroundPath,
      targetPath,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _FeaturedCarouselWidget extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductTap;

  const _FeaturedCarouselWidget({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  @override
  State<_FeaturedCarouselWidget> createState() =>
      _FeaturedCarouselWidgetState();
}

class _FeaturedCarouselWidgetState extends State<_FeaturedCarouselWidget> {
  late final PageController _carouselController;
  int _carouselActiveIndex = 0;
  List<Widget> _carouselItems = [];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.65)
      ..addListener(() {
        if (mounted) {
          final page = _carouselController.page ?? 0.0;
          final rounded = page.round();
          if (rounded != _carouselActiveIndex) {
            setState(() {
              _carouselActiveIndex = rounded;
            });
          }
        }
      });
    _buildCarouselItems();
  }

  void _buildCarouselItems() {
    _carouselItems = widget.products.map((product) {
      return _KeepAliveWrapper(
        key: ValueKey<int>(product.id),
        child: GestureDetector(
          onTap: () => widget.onProductTap(product),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _getCarouselPastelBg(product.id),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ClipOval(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: _PremiumGridImage(
                    key: ValueKey<String>(product.image),
                    pathOrUrl: product.image,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  void didUpdateWidget(_FeaturedCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.products != oldWidget.products) {
      _carouselActiveIndex = 0;
      _buildCarouselItems();
      if (_carouselController.hasClients) {
        _carouselController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Color _getCarouselPastelBg(int id) {
    final colors = [
      const Color(0xFFFFF0EC),
      const Color(0xFFEAF8EB),
      const Color(0xFFEAF6FF),
      const Color(0xFFFFFDE7),
      const Color(0xFFF7EBF9),
    ];
    return colors[id % colors.length];
  }

  String _capitalizeText(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .where((w) => w.isNotEmpty)
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final featured = widget.products;
    if (featured.isEmpty) return const SizedBox.shrink();

    final activeIndex = _carouselActiveIndex.clamp(0, featured.length - 1);
    final activeProduct = featured[activeIndex];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Recomendado para ti',
                  style: TextStyle(
                    color: Color(0xFF062B35),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 180,
            child: PageView.builder(
              key: const PageStorageKey('featured_carousel_page_view'),
              controller: _carouselController,
              itemCount: _carouselItems.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return _carouselItems[index];
              },
            ),
          ),
          const SizedBox(height: 12),

          Column(
            children: [
              Text(
                _capitalizeText(activeProduct.name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE28F83),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'S/. ${activeProduct.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF062B35),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({super.key, required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class _MenuSkeletonLoader extends StatefulWidget {
  const _MenuSkeletonLoader();

  @override
  State<_MenuSkeletonLoader> createState() => _MenuSkeletonLoaderState();
}

class _MenuSkeletonLoaderState extends State<_MenuSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(
      begin: 0.35,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        final opacity = _opacityAnim.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 27, 111, 129),
                  ),
                ),
              ),
            ),
            // Skeleton: Carousel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: 180,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 140,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Skeleton: Category Chips
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final widths = [80.0, 100.0, 90.0, 110.0];
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 16,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Container(
                      width: widths[index % widths.length],
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(opacity),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Skeleton: Product Grid (List)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withOpacity(0.03)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.grey.withOpacity(opacity),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 120,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            height: 100,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(opacity),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 140,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(
                                            opacity,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 80,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(
                                            opacity,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 60,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(
                                            opacity,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

List<Category> _parseCategoriesIsolate(String rawJson) {
  final List<dynamic> data = jsonDecode(rawJson) as List<dynamic>;
  return data
      .whereType<Map<String, dynamic>>()
      .map(Category.fromJson)
      .where((c) => c.status.toUpperCase() == 'ACTIVO')
      .where((c) => c.products.isNotEmpty)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}
