import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'CartPage.dart';
import 'package:bubblesplash/utils/route_observer.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';

import 'package:bubblesplash/models/category.dart';
import 'package:bubblesplash/models/product.dart';
import 'package:bubblesplash/models/topping.dart';

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
  const MenuPage({super.key, this.descuento = 0.0});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

// --------------------
// CustomAppBar simple
// --------------------
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(110);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.local_cafe_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'BUBBLE TEA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'BEBIDAS ESPECIALES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 7, color: Colors.white),
                    SizedBox(width: 6),
                    Icon(Icons.circle, size: 7, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'BUBBLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------
// CUERPO PRINCIPAL
// --------------------
class _MenuPageState extends State<MenuPage>
    with RouteAware, WidgetsBindingObserver {
  Timer? _refreshTimer;

  List<Map<String, dynamic>> pedidos = [];
  bool _suppressNextReload = false;

  List<Category> _categories = [];
  bool _isLoadingProducts = false;
  String? _productsError;

  // ✅ optimización: evita solapes y reprocesado
  bool _isFetchingCategories = false;
  String? _lastCategoriesBody;

  static const String _cartFabXFracKey = 'menu_cart_fab_x_frac';
  static const String _cartFabYFracKey = 'menu_cart_fab_y_frac';
  final GlobalKey _cartFabStackKey = GlobalKey();

  double? _cartFabXFrac;
  double? _cartFabYFrac;
  Offset? _cartFabOffset;

  Offset? _cartFabDragStartGlobal;
  Offset? _cartFabDragStartOffset;
  bool _isDraggingCartFab = false;

  static const String _categoriesCacheKey = 'menu_categories_cache';
  static const String _categoriesCacheTimeKey = 'menu_categories_cache_time';
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cargarPedidosGuardados();
    _cargarCategorias();
    _loadCartFabPosition();

    // ✅ refresco sano (no spamear cada 3s)
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _actualizarCategoriasDesdeApi(background: true);
    });
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
    _refreshTimer?.cancel();
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
      pedidos = data
          .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
          .toList();
    });
  }

  Future<void> _guardarPedidos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = pedidos.map((p) => jsonEncode(p)).toList();
    await prefs.setStringList('cart_pedidos', data);
  }

  Future<void> _openCart() async {
    _suppressNextReload = true;
    List<Map<String, dynamic>>? updatedPedidos;
    try {
      updatedPedidos = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CartPage(initialPedidos: pedidos, descuento: widget.descuento),
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
  Future<void> _cargarCategorias() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCache = prefs.getInt(_categoriesCacheTimeKey) ?? 0;
    final isCacheValid = (now - lastCache) < _cacheDuration.inMilliseconds;
    final cached = prefs.getString(_categoriesCacheKey);

    // Mostrar caché inmediatamente si existe
    if (cached != null) {
      final List<dynamic> data = jsonDecode(cached) as List<dynamic>;
      final categories =
          data
              .whereType<Map<String, dynamic>>()
              .map(Category.fromJson)
              .where((c) => c.status.toUpperCase() == 'ACTIVO')
              .where((c) => c.products.isNotEmpty)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoadingProducts = false;
        _productsError = null;
      });

      // ✅ guarda last body para evitar reprocesado si es igual
      _lastCategoriesBody = cached;
    }

    // Si el caché es válido, refresca en background
    if (isCacheValid && cached != null) {
      _actualizarCategoriasDesdeApi(background: true);
      return;
    }

    // Si no hay caché válido, sí bloquea la UI
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
      if (rawToken == null || rawToken.trim().isEmpty) {
        if (!mounted) return;
        if (!background) {
          setState(() {
            _isLoadingProducts = false;
            _productsError =
                'No hay access token. Inicia sesión nuevamente para ver el menú.';
          });
        }
        return;
      }

      final token = rawToken.trim();
      final uri = BackendConfig.api('bubblesplash/categorias/');

      http.Response response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // refrescar token 1 vez
      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (!mounted) return;

      if (response.statusCode == 401) {
        if (!background) {
          setState(() {
            _isLoadingProducts = false;
            _productsError =
                'Tu sesión ha expirado. Inicia sesión nuevamente para ver el menú.';
          });
        }
        return;
      }

      if (response.statusCode != 200) {
        if (!background) {
          setState(() {
            _isLoadingProducts = false;
            _productsError =
                'Error al cargar productos (${response.statusCode}).';
          });
        }
        return;
      }

      // ✅ si el body es igual al anterior, no reproceses
      if (_lastCategoriesBody != null && _lastCategoriesBody == response.body) {
        if (!background) setState(() => _isLoadingProducts = false);
        return;
      }
      _lastCategoriesBody = response.body;

      // Guardar en cache
      await prefs.setString(_categoriesCacheKey, response.body);
      await prefs.setInt(_categoriesCacheTimeKey, now);

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final categories =
          data
              .whereType<Map<String, dynamic>>()
              .map(Category.fromJson)
              .where((c) => c.status.toUpperCase() == 'ACTIVO')
              .where((c) => c.products.isNotEmpty)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));

      // ✅ actualiza solo si cambió algo relevante
      bool same = _categories.length == categories.length;
      if (same) {
        for (int i = 0; i < categories.length; i++) {
          if (_categories[i].id != categories[i].id ||
              _categories[i].products.length != categories[i].products.length) {
            same = false;
            break;
          }
        }
      }

      setState(() {
        if (!same) _categories = categories;
        if (!background) _isLoadingProducts = false;
        _productsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!background) {
        setState(() {
          _isLoadingProducts = false;
          _productsError = 'Error al cargar productos: $e';
        });
      }
    } finally {
      _isFetchingCategories = false;
    }
  }

  // --------------------
  // GRID: abrir detalle y agregar
  // --------------------
  Future<void> _openProductAndAdd({
    required BuildContext context,
    required Product product,
  }) async {
    _suppressNextReload = true;
    dynamic rawPedido;

    try {
      rawPedido = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProductDetailPage(product: product, descuento: widget.descuento),
        ),
      );
    } finally {
      _suppressNextReload = false;
    }

    if (rawPedido != null) {
      final Map<String, dynamic> pedido = Map<String, dynamic>.from(
        rawPedido as Map,
      );

      setState(() => pedidos.add(pedido));
      await _guardarPedidos();

      if (!context.mounted) return;

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
      appBar: const CustomAppBar(),
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
                padding: const EdgeInsets.only(bottom: 120),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // 🔹 Banner superior
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 26,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        image: const DecorationImage(
                          image: AssetImage('assets/franela.jpg'),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Text(
                          'Elige tu bebida favorita y disfruta tu momento',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

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
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
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
                      Column(
                        children: [
                          for (int i = 0; i < _categories.length; i++) ...[
                            _buildCategorySectionGrid(
                              context: context,
                              categoryId: _categories[i].id,
                              title: _categories[i].name,
                              products: _categories[i].products,
                            ),
                            if (i < _categories.length - 1)
                              const SizedBox(height: 14),
                          ],
                        ],
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
            ],
          );
        },
      ),
    );
  }

  // --------------------
  // SECCIÓN DE CATEGORÍA (PREMIUM + GRID 2 COLS)
  // --------------------
  Widget _buildCategorySectionGrid({
    required BuildContext context,
    required int categoryId,
    required String title,
    required List<Product> products,
  }) {
    final theme = Theme.of(context);

    const int maxPreview = 4;
    final bool hasMore = products.length > maxPreview;
    final int visibleCount = hasMore ? maxPreview : products.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 26,
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
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B6F81).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${products.length} items',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1B6F81),
                  ),
                ),
              ),
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () async {
                      final resultPedidos =
                          await Navigator.push<List<Map<String, dynamic>>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryProductsPage(
                                categoryId: categoryId,
                                categoryTitle: title,
                                products: products,
                                descuento: widget.descuento,
                                initialPedidos: pedidos,
                              ),
                            ),
                          );
                      if (resultPedidos != null) {
                        setState(() => pedidos = resultPedidos);
                        await _guardarPedidos();
                      }
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0B3D4A).withOpacity(0.08),
                            const Color(0xFF128FA0).withOpacity(0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF128FA0).withOpacity(0.22),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 6,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 14,
                            color: Color(0xFF0B3D4A),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Ver más',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0B3D4A),
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: Color(0xFF0B3D4A),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleCount,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              final precioOriginal = product.price;
              final precioFinal = precioOriginal * (1 - widget.descuento);
              return _PremiumProductGridTile(
                product: product,
                descuento: widget.descuento,
                precioOriginal: precioOriginal,
                precioFinal: precioFinal,
                onAdd: () =>
                    _openProductAndAdd(context: context, product: product),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --------------------
// TILE PREMIUM para GRID (2 columnas)
// --------------------
class _PremiumProductGridTile extends StatelessWidget {
  const _PremiumProductGridTile({
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
  Widget build(BuildContext context) {
    final hasDiscount = descuento > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onAdd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _PremiumGridImage(pathOrUrl: product.image),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.55),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
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
                        '-${(descuento * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'S/. ${precioFinal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 10),
                              ],
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 10),
                            Text(
                              'S/. ${precioOriginal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.lineThrough,
                                decorationThickness: 2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: _GlassAddButton(onTap: onAdd),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassAddButton extends StatelessWidget {
  const _GlassAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Agregar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
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
  const _PremiumGridImage({required this.pathOrUrl});
  final String pathOrUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.grey[200],
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Icon(Icons.local_cafe_rounded, size: 34, color: Colors.black26),
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
      return Image.network(
        pathOrUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Image.asset(
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

  const ProductDetailPage({
    super.key,
    required this.product,
    this.descuento = 0.0,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _SelectableTopping {
  final Topping topping;
  final bool selected;

  const _SelectableTopping({required this.topping, this.selected = false});

  _SelectableTopping copyWith({Topping? topping, bool? selected}) {
    return _SelectableTopping(
      topping: topping ?? this.topping,
      selected: selected ?? this.selected,
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
    final selectedToppings = toppings.where((t) => t.selected);
    final toppingsTotal = selectedToppings.fold<double>(
      0.0,
      (sum, t) => sum + t.topping.price,
    );

    final unitTotal = basePrice + sizeExtra + iceExtra + toppingsTotal;

    final pedido = {
      'id': widget.product.id,
      'name': widget.product.name,
      'desc': widget.product.description,
      'image': widget.product.image,
      'price': unitTotal,
      'basePrice': basePrice,
      'sizeExtra': sizeExtra,
      'iceExtra': iceExtra,
      'toppingsTotal': toppingsTotal,
      'size': selectedSize,
      'ice': selectedIce,
      'toppings': toppings
          .where((t) => t.selected)
          .map(
            (t) => {
              'id': t.topping.id,
              'name': t.topping.name,
              'price': t.topping.price,
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

  String selectedSize = 'Normal';
  String selectedIce = 'Normal';

  late double basePrice;
  double totalPrice = 0.0;

  bool _isLoadingDetail = false;
  String? _detailError;

  // Precios adicionales por tamaño de vaso (se llenan desde API)
  Map<String, double> _sizePrices = {'Normal': 0.0};

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
    basePrice = widget.product.price * (1 - widget.descuento);
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
      final rawToken = prefs.getString('access_token');
      if (rawToken == null || rawToken.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoadingDetail = false;
          _detailError =
              'No hay access token para cargar el detalle del producto.';
        });
        return;
      }

      final token = rawToken.trim();
      final uri = Uri.parse(
        'https://services.fintbot.pe/api/bubblesplash/productos/$id/',
      );

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Reintento si expiró
      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final String priceStr = (data['pro_de_baseprice'] ?? '0').toString();
        final double backendPrice = double.tryParse(priceStr) ?? basePrice;

        setState(() {
          basePrice = backendPrice * (1 - widget.descuento);
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
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');
      if (rawToken == null || rawToken.trim().isEmpty) {
        debugPrint('No hay access token para cargar toppings');
        return;
      }

      final token = rawToken.trim();
      final uri = Uri.parse(
        'https://services.fintbot.pe/api/bubblesplash/toppings/',
      );

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (response.statusCode != 200) {
        debugPrint(
          'Error al cargar toppings: ${response.statusCode} ${response.body}',
        );
        return;
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
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
            final String name = (item['top_txt_name'] ?? '').toString();
            final String priceStr = (item['top_de_price'] ?? '0').toString();
            final double price = double.tryParse(priceStr) ?? 0.0;
            return _SelectableTopping(
              topping: Topping(id: id, name: name, price: price),
              selected: false,
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
      final rawToken = prefs.getString('access_token');
      if (rawToken == null || rawToken.trim().isEmpty) {
        debugPrint('No hay access token para cargar tamaños de vaso');
        return;
      }

      final token = rawToken.trim();
      final uri = Uri.parse(
        'https://services.fintbot.pe/api/bubblesplash/productos-sizes/',
      );

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (response.statusCode != 200) {
        debugPrint(
          'Error al cargar tamaños: ${response.statusCode} ${response.body}',
        );
        return;
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final Map<String, double> newSizes = {};

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
      }

      if (newSizes.isEmpty || !mounted) return;
      setState(() {
        _sizePrices = newSizes;
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

  double _calcularTotal() {
    final sizeExtra = _sizePrices[selectedSize] ?? 0.0;
    final iceExtra = _icePrices[selectedIce] ?? 0.0;
    final toppingsTotal = toppings
        .where((t) => t.selected)
        .fold<double>(0.0, (sum, t) => sum + t.topping.price);

    return basePrice + sizeExtra + iceExtra + toppingsTotal;
  }

  void _toggleTopping(int index) {
    final selectedCount = toppings.where((t) => t.selected).length;
    final isSelected = toppings[index].selected;

    if (!isSelected && selectedCount >= 3) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _PremiumFeedbackModal(
          message: 'Solo puedes elegir hasta 3 toppings.',
        ),
      );
      return;
    }

    setState(() {
      toppings[index] = toppings[index].copyWith(selected: !isSelected);
      totalPrice = _calcularTotal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // =========================
          // HEADER PREMIUM (collapsible)
          // =========================
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 300,
            backgroundColor: const Color(0xFF0B3D4A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
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
                  _buildDetailImage(widget.product.image),
                  // Overlay premium
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.10),
                          Colors.black.withOpacity(0.60),
                          const Color(0xFF0B3D4A).withOpacity(0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Info bottom sobre la imagen
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 14),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PricePill(
                              text: 'S/. ${basePrice.toStringAsFixed(2)}',
                              icon: Icons.sell_rounded,
                            ),
                            if (widget.descuento > 0)
                              _DiscountPill(
                                text: '-${(widget.descuento * 100).toInt()}%',
                              ),
                            if (_isLoadingDetail)
                              const _StatusPill(text: 'Actualizando precio...'),
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

          // =========================
          // BODY
          // =========================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mensaje de error (detalle)
                  if (_detailError != null) ...[
                    _SectionCard(
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
                    const SizedBox(height: 12),
                  ],

                  // Descripción
                  if (widget.product.description.trim().isNotEmpty) ...[
                    _SectionTitle(title: 'Descripción'),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Text(
                        widget.product.description,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tamaños
                  _SectionTitle(title: 'Tamaño de vaso'),
                  const SizedBox(height: 10),
                  _SectionCard(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          (_sizePrices.keys.isNotEmpty
                                  ? _sizePrices.keys.toList()
                                  : ['Normal'])
                              .map((size) {
                                final selected = selectedSize == size;
                                final extra = _sizePrices[size] ?? 0.0;
                                String label = _labelSize(size);
                                if (extra > 0.0) {
                                  label +=
                                      ' (+S/. ' +
                                      extra.toStringAsFixed(2) +
                                      ')';
                                } else if (extra < 0.0) {
                                  label +=
                                      ' (-S/. ' +
                                      (-extra).toStringAsFixed(2) +
                                      ')';
                                }
                                return ChoiceChip(
                                  label: Text(label),
                                  selected: selected,
                                  onSelected: (v) {
                                    if (!v) return;
                                    setState(() {
                                      selectedSize = size;
                                      totalPrice = _calcularTotal();
                                    });
                                  },
                                  selectedColor: const Color(0xFF128FA0),
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                    fontWeight: FontWeight.w900,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    side: BorderSide(
                                      color: selected
                                          ? Colors.transparent
                                          : const Color(
                                              0xFF111827,
                                            ).withOpacity(0.08),
                                    ),
                                  ),
                                  elevation: 0,
                                  pressElevation: 0,
                                );
                              })
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toppings
                  _SectionTitle(title: 'Toppings (máx. 3)'),
                  const SizedBox(height: 10),
                  _SectionCard(
                    child: toppings.isEmpty
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
                            children: List.generate(toppings.length, (index) {
                              final t = toppings[index];
                              return FilterChip(
                                selected: t.selected,
                                onSelected: (_) => _toggleTopping(index),
                                label: Text(
                                  '${t.topping.name} (+S/. ${t.topping.price.toStringAsFixed(2)})',
                                ),
                                selectedColor: const Color(0xFF22C55E),
                                backgroundColor: const Color(0xFFF3F4F6),
                                labelStyle: TextStyle(
                                  color: t.selected
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                  fontWeight: t.selected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: BorderSide(
                                    color: t.selected
                                        ? Colors.transparent
                                        : const Color(
                                            0xFF111827,
                                          ).withOpacity(0.08),
                                  ),
                                ),
                                elevation: 0,
                                pressElevation: 0,
                              );
                            }),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Hielo
                  _SectionTitle(title: 'Nivel de hielo'),
                  const SizedBox(height: 10),
                  _SectionCard(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ['Normal', 'Extra hielo', 'Poco hielo'].map((
                        ice,
                      ) {
                        final selected = selectedIce == ice;
                        return ChoiceChip(
                          label: Text(_labelIce(ice)),
                          selected: selected,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              selectedIce = ice;
                              totalPrice = _calcularTotal();
                            });
                          },
                          selectedColor: const Color(0xFF128FA0),
                          backgroundColor: const Color(0xFFF3F4F6),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF111827),
                            fontWeight: FontWeight.w900,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: selected
                                  ? Colors.transparent
                                  : const Color(0xFF111827).withOpacity(0.08),
                            ),
                          ),
                          elevation: 0,
                          pressElevation: 0,
                        );
                      }).toList(),
                    ),
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
        ],
      ),

      // =========================
      // BOTTOM BAR PREMIUM
      // =========================
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, -10),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF111827).withOpacity(0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'S/. ${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B3D4A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text(
                    'Agregar',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF128FA0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _handleAddToCartPremium, // 👇 lo agregamos abajo
                ),
              ),
            ],
          ),
        ),
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
      return Image.network(
        pathOrUrl,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return placeholder;
        },
      );
    }

    return Image.asset(
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

  const CategoryProductsPage({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.products,
    required this.descuento,
    required this.initialPedidos,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  late List<Map<String, dynamic>> _pedidos;
  String _q = '';

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
        builder: (_) =>
            CartPage(initialPedidos: _pedidos, descuento: widget.descuento),
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
    final rawPedido = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailPage(product: product, descuento: widget.descuento),
      ),
    );

    if (!mounted) return;

    if (rawPedido != null) {
      final pedido = Map<String, dynamic>.from(rawPedido as Map);

      setState(() => _pedidos.add(pedido));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'cart_pedidos',
        _pedidos.map((p) => jsonEncode(p)).toList(),
      );

      if (!mounted) return;

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
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.74,
                            ),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final precioOriginal = product.price;
                          final precioFinal =
                              precioOriginal * (1 - widget.descuento);

                          return _PremiumProductGridTile(
                            product: product,
                            descuento: widget.descuento,
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
