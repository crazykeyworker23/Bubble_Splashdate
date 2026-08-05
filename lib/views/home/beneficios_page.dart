import 'package:bubblesplash/utils/carrito_promos.dart';
import 'package:bubblesplash/views/home/mis_descuentos_page.dart';
import 'package:bubblesplash/services/canjes_service.dart';
import 'package:bubblesplash/views/home/menu_page.dart';
import 'package:bubblesplash/utils/tamanos.dart';
import 'package:bubblesplash/utils/iconos_oferta.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bubblesplash/services/app_http.dart' as http;

import 'CartPage.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'menu_page.dart';
import 'dart:ui';
import 'package:bubblesplash/widgets/connection_error_dialog.dart';

/// ===============================
/// ✅ ICONO POR TIPO (GLOBAL)
/// ===============================
IconData _iconoPorTipo(String tipo) {
  switch (tipo.toLowerCase()) {
    case 'descuento':
      return Icons.percent;
    case 'envío':
    case 'envio':
      return Icons.local_shipping;
    case 'regalo':
      return Icons.card_giftcard;
    case 'puntos':
      return Icons.stars_rounded;
    default:
      return Icons.local_offer;
  }
}

/// ===============================
/// APP BAR PREMIUM (REUTILIZABLE)
/// ===============================
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String tipo;

  const CustomAppBar({super.key, required this.title, this.tipo = ''});

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
            colors: [Color(0xFF0F3D4A), Color(0xFF128FA0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
      ),
      titleSpacing: 18,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Icon(_iconoPorTipo(tipo), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(right: 18),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Bubble',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

/// ===============================
/// BENEFICIOS / OFERTAS (PREMIUM)
/// ===============================
class BeneficiosPage extends StatefulWidget {
  const BeneficiosPage({super.key});

  @override
  State<BeneficiosPage> createState() => _BeneficiosPageState();
}

class _BeneficiosPageState extends State<BeneficiosPage>
    with WidgetsBindingObserver {
  // Progreso
  double progreso = 0.0;
  int puntos = 0;
  String nivel = 'Bronce ⭐';
  int nextThreshold = 300;
  int faltanParaSiguiente = 300;

  // Ofertas backend
  List<Map<String, dynamic>> _ofertas = [];
  bool _isLoadingOfertas = false;
  String? _ofertasError;

  /// Cuántos descuentos tiene obtenidos y sin usar.
  ///
  /// Aquí solo interesa el NÚMERO: el detalle vive en su propia pantalla. Una
  /// pila de avisos empujaba el contenido de Beneficios hacia abajo en cuanto
  /// había más de un descuento.
  int _descuentosPendientes = 0;

  // Carrito (prefs)
  int _cartCount = 0;

  // Colores / estilo
  static const Color _bg = Color(0xFFF6F7FB);
  static const Color _textDark = Color(0xFF1F2A37);
  static const Color _textMute = Color(0xFF6B7280);

  // =============================
  // ✅ Cache: ofertas + puntos
  // =============================
  static const String _ofertasCacheKey = 'beneficios_ofertas_cache';
  static const String _ofertasCacheTimeKey = 'beneficios_ofertas_cache_time';
  static const String _puntosCacheKeyPrefix = 'beneficios_puntos_cache_';
  static const String _puntosCacheTimeKeyPrefix =
      'beneficios_puntos_cache_time_';
  static const Duration _cacheDuration = Duration(minutes: 5);

  // =============================
  // ✅ FAB Draggable persistente
  // =============================
  static const String _fabXFracKey = 'beneficios_cart_fab_x_frac';
  static const String _fabYFracKey = 'beneficios_cart_fab_y_frac';
  double? _fabXFrac;
  double? _fabYFrac;
  Offset? _fabOffset;
  Offset? _fabDragStartGlobal;
  Offset? _fabDragStartOffset;
  bool _isDraggingFab = false;

  // Evita solapes de fetch
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadFabPosition();
    _loadCartCount();

    // ✅ 1) pinta cache instantáneo
    _loadCachedPuntosAndOfertas();
    // ✅ 2) refresca en background
    _bootstrap(background: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bootstrap(background: true);
      _loadCartCount();
    }
  }

  Future<void> _loadCachedPuntosAndOfertas() async {
    final prefs = await SharedPreferences.getInstance();

    // ---- puntos cache
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final String? email =
        prefs.getString('google_email') ?? prefs.getString('savedEmail');
    final String userUniqueId =
        user?.uid ??
        (email != null && email.isNotEmpty ? email : 'current_user');
    if (true) {
      final keyPoints = '$_puntosCacheKeyPrefix$userUniqueId';
      final storedPoints = prefs.getInt(keyPoints);
      if (storedPoints != null) {
        if (!mounted) return;
        setState(() {
          puntos = storedPoints;
          _actualizarNivelYProgreso();
        });
      }
    }

    // ---- ofertas cache
    final cached = prefs.getString(_ofertasCacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          final ofertas = decoded
              .whereType<Map<String, dynamic>>()
              .where(
                (o) =>
                    (o['txt_status'] ?? '').toString().toUpperCase() ==
                    'ACTIVO',
              )
              .toList();
          if (!mounted) return;
          setState(() {
            _ofertas = ofertas;
            _isLoadingOfertas = false;
            _ofertasError = null;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _bootstrap({bool background = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      await _cargarPuntos(background: background);
      await _cargarOfertas(background: background);
      await _cargarCanjesPendientes();
    } finally {
      _isFetching = false;
    }
  }

  // =============================
  // CARRITO (SharedPreferences)
  // =============================
  Future<List<Map<String, dynamic>>> _loadCartFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Esta pantalla abre el carrito SIN canje, así que cualquier precio
    // promocional guardado se revierte antes de mostrarlo.
    final raw = prefs.getStringList('cart_pedidos') ?? <String>[];

    final items = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map<String, dynamic>) {
          decoded['quantity'] = (decoded['quantity'] ?? decoded['qty'] ?? 1);
          items.add(decoded);
        }
      } catch (_) {}
    }
    // Estas pantallas no manejan canje: se revierten los precios
    // promocionales para que lo mostrado sea lo que cobrará el servidor.
    return sanearCarritoGuardado(items, hayCanjeActivo: false);
  }

  Future<void> _saveCartToPrefs(List<Map<String, dynamic>> pedidos) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = pedidos.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('cart_pedidos', encoded);
  }

  int _sumCartQty(List<Map<String, dynamic>> pedidos) {
    return pedidos.fold<int>(0, (sum, e) {
      final q = int.tryParse((e['quantity'] ?? 1).toString()) ?? 1;
      return sum + (q <= 0 ? 1 : q);
    });
  }

  Future<void> _loadCartCount() async {
    final pedidos = await _loadCartFromPrefs();
    if (!mounted) return;
    setState(() => _cartCount = _sumCartQty(pedidos));
  }

  Future<void> _openCart() async {
    final pedidos = await _loadCartFromPrefs();

    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(builder: (_) => CartPage(initialPedidos: pedidos)),
    );

    if (updated != null) {
      await _saveCartToPrefs(updated);
    }
    await _loadCartCount();
  }

  // =============================
  // ✅ FAB: guardar / cargar / snap
  // =============================
  Future<void> _loadFabPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_fabXFracKey);
    final y = prefs.getDouble(_fabYFracKey);
    if (!mounted) return;
    setState(() {
      _fabXFrac = x;
      _fabYFrac = y;
      _fabOffset = null;
    });
  }

  Future<void> _saveFabPosition({
    required double xFrac,
    required double yFrac,
  }) async {
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

    final double snappedX = (current.dx - minX) <= (maxX - current.dx)
        ? minX
        : maxX;
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

    _saveFabPosition(xFrac: xFrac, yFrac: yFrac);
  }

  Widget _buildCartFabButton({required int count}) {
    return FloatingActionButton(
      heroTag: 'beneficios_cart_fab',
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

  // =============================
  // PUNTOS (optimizado + cache)
  // =============================
  Future<void> _cargarPuntos({bool background = false}) async {
    final prefs = await SharedPreferences.getInstance();

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final String? email =
        prefs.getString('google_email') ?? prefs.getString('savedEmail');
    final String? rawToken = prefs.getString('access_token');

    if (rawToken == null || rawToken.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        puntos = 0;
        _actualizarNivelYProgreso();
      });
      return;
    }

    final String userUniqueId =
        user?.uid ??
        (email != null && email.isNotEmpty ? email : 'current_user');
    final String keyPuntos = 'puntos_$userUniqueId';
    final String cacheKey = '$_puntosCacheKeyPrefix$userUniqueId';
    final String cacheTimeKey = '$_puntosCacheTimeKeyPrefix$userUniqueId';

    try {
      // Siempre consultar el backend para puntos reales
      if (rawToken.trim().isNotEmpty) {
        final token = rawToken.trim();
        final uri = BackendConfig.api('bubblesplash/progreso/');

        http.Response response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        debugPrint('GET bubblesplash/progreso/ status: ${response.statusCode}');
        debugPrint('GET bubblesplash/progreso/ body: ${response.body}');

        if (response.statusCode == 200) {
          final dynamic body = jsonDecode(response.body);
          int backendPoints = 0;

          if (body is Map<String, dynamic>) {
            final dynamic pointsObj = body['points'];
            if (pointsObj is Map<String, dynamic>) {
              backendPoints =
                  int.tryParse(
                    (pointsObj['upo_int_totalpoints'] ?? '0').toString(),
                  ) ??
                  0;
            }
          }

          await prefs.setInt(keyPuntos, backendPoints);
          await prefs.setInt(cacheKey, backendPoints);
          await prefs.setInt(
            cacheTimeKey,
            DateTime.now().millisecondsSinceEpoch,
          );

          if (!mounted) return;
          setState(() {
            puntos = backendPoints;
            _actualizarNivelYProgreso();
          });
          return;
        }
      }
      // Si no hay token o falla el backend, usa local
      final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
      if (!mounted) return;
      setState(() {
        puntos = storedPoints;
        _actualizarNivelYProgreso();
      });
    } catch (e) {
      debugPrint('❌ Excepción en _cargarPuntos: $e');
      final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
      if (!mounted) return;
      setState(() {
        puntos = storedPoints;
        _actualizarNivelYProgreso();
      });
    }
  }

  /// Explica el programa en una hoja inferior.
  ///
  /// No dice cuántos puntos da cada cosa: esas cifras las fija el negocio y
  /// anunciarlas convierte cualquier ajuste en una promesa incumplida.
  void _mostrarComoFunciona() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Cómo funciona',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F3D4A),
              ),
            ),
            const SizedBox(height: 14),
            _puntoAyuda(
              Icons.local_cafe_rounded,
              'Acumula puntos',
              'Cada pedido que haces suma puntos a tu cuenta.',
            ),
            _puntoAyuda(
              Icons.lock_open_rounded,
              'Desbloquea recompensas',
              'Al llegar a los puntos que pide cada beneficio, se '
                  'desbloquea y puedes canjearlo.',
            ),
            _puntoAyuda(
              Icons.card_giftcard_rounded,
              'Canjea cuando quieras',
              'Toca el beneficio desbloqueado y confirma. Se descuentan los '
                  'puntos y lo aplicas en tu próximo pedido.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _puntoAyuda(IconData icono, String titulo, String detalle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: const Color(0xFF128FA0), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102A33),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 12.8,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Avance hacia la próxima recompensa, entre 0 y 1.
  ///
  /// Se mide desde el último hito ya conseguido, no desde cero: si acaba de
  /// desbloquear una recompensa de 250 y la siguiente es de 400, la barra
  /// debe arrancar vacía otra vez y no casi llena.
  double get _progresoMostrado {
    final meta = _metaMostrada;
    if (meta <= 0 || puntos >= meta) return 1.0;

    int base = 0;
    for (final o in _ofertasEnCamino) {
      final c = _costeDeOferta(o);
      if (c <= puntos && c > base) base = c;
    }

    final recorrido = puntos - base;
    final tramo = meta - base;
    if (tramo <= 0) return 1.0;
    return (recorrido / tramo).clamp(0.0, 1.0);
  }

  /// Meta que se enseña en la barra de arriba.
  ///
  /// Es la próxima recompensa por alcanzar; si ya las tiene todas, se cae al
  /// siguiente nivel. Antes siempre mostraba el nivel, y con 318 puntos decía
  /// «faltan 282 para 600» mientras a 82 puntos había una recompensa
  /// esperándole: la cifra que menos le servía.
  int get _metaMostrada {
    final meta = _proximaMetaPuntos;
    return meta > puntos ? meta : nextThreshold;
  }

  List<dynamic>? _caminoCache;
  List<dynamic>? _caminoOrigen;
  int? _caminoPuntos;

  int _costeDeOferta(dynamic o) =>
      int.tryParse((o['off_int_pointscost'] ?? '0').toString()) ?? 0;

  /// Puntos del primer beneficio que aún no alcanza.
  ///
  /// Es la meta que de verdad le importa al usuario, y también la que manda en
  /// la barra de arriba: decirle «te faltan 282 para el nivel Oro» cuando a 82
  /// puntos tiene una recompensa esperándole es enseñarle la cifra que menos
  /// le sirve.
  int get _proximaMetaPuntos {
    for (final o in _ofertasEnCamino) {
      final c = _costeDeOferta(o);
      if (c > puntos) return c;
    }
    return 0;
  }

  /// Recompensas ordenadas como un camino: primero lo que ya alcanzó, y
  /// dentro de cada grupo, de menos a más puntos.
  ///
  /// Sin ordenar, una recompensa de 600 puntos podía salir antes que una de
  /// 72 y la pantalla no contaba ninguna historia: no se veía qué toca ahora
  /// ni cuánto falta para lo siguiente.
  List<dynamic> get _ofertasEnCamino {
    int costeDe(dynamic o) =>
        int.tryParse((o['off_int_pointscost'] ?? '0').toString()) ?? 0;

    // El resultado se guarda: este getter lo consultan la cabecera y cada
    // tarjeta, así que sin memoria se reordenaba la lista una vez por
    // beneficio y por frame. Con pocas ofertas no se nota; con muchas, sí.
    if (_caminoCache != null &&
        identical(_caminoOrigen, _ofertas) &&
        _caminoPuntos == puntos) {
      return _caminoCache!;
    }

    final lista = List<dynamic>.from(_ofertas);
    lista.sort((a, b) {
      final ca = costeDe(a);
      final cb = costeDe(b);
      // Canjeado y desbloqueado cuentan igual para el orden: los dos son
      // peldaños ya pisados y deben quedar por encima de la línea punteada.
      final alcanzaA = ca <= puntos || a['ya_canjeada'] == true;
      final alcanzaB = cb <= puntos || b['ya_canjeada'] == true;
      if (alcanzaA != alcanzaB) return alcanzaA ? -1 : 1;
      return ca.compareTo(cb);
    });

    _caminoCache = lista;
    _caminoOrigen = _ofertas;
    _caminoPuntos = puntos;
    return lista;
  }

  void _actualizarNivelYProgreso() {
    if (puntos >= 1000) {
      nivel = 'Platino ⭐';
      progreso = 1.0;
      nextThreshold = 1000;
      faltanParaSiguiente = 0;
    } else if (puntos >= 600) {
      nivel = 'Oro ⭐';
      progreso = (puntos - 600) / 400;
      nextThreshold = 1000;
      faltanParaSiguiente = (1000 - puntos).clamp(0, 1000);
    } else if (puntos >= 300) {
      nivel = 'Plata ⭐';
      progreso = (puntos - 300) / 300;
      nextThreshold = 600;
      faltanParaSiguiente = (600 - puntos).clamp(0, 600);
    } else {
      nivel = 'Bronce ⭐';
      progreso = puntos / 300;
      nextThreshold = 300;
      faltanParaSiguiente = (300 - puntos).clamp(0, 300);
    }

    if (progreso < 0) progreso = 0;
    if (progreso > 1) progreso = 1;
  }

  // =============================
  // OFERTAS (optimizado + cache)
  // =============================
  /// Cuenta los descuentos pendientes para el acceso de la cabecera.
  Future<void> _cargarCanjesPendientes() async {
    final pendientes = await CanjesService.pendientes();
    if (!mounted) return;
    setState(() => _descuentosPendientes = pendientes.length);
  }

  Future<void> _cargarOfertas({bool background = false}) async {
    if (!mounted) return;

    if (!background) {
      setState(() {
        _isLoadingOfertas = true;
        _ofertasError = null;
      });
    } else {
      _ofertasError = null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        if (!mounted) return;
        if (!background) {
          setState(() {
            _isLoadingOfertas = false;
            _ofertasError =
                'No hay access token. Inicia sesión nuevamente para ver tus ofertas.';
          });
        }
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final lastCache = prefs.getInt(_ofertasCacheTimeKey) ?? 0;
      final isCacheValid = (now - lastCache) < _cacheDuration.inMilliseconds;

      if (background && isCacheValid) {
        // ok, igual refrescamos si quieres mantenerlo actualizado
      }

      final token = rawToken.trim();
      // Se piden también las que aún no alcanza: son los peldaños que faltan
      // del camino. Sin ellas la pantalla solo enseñaría lo ya conseguido y no
      // habría ninguna meta a la vista.
      final uri = BackendConfig.api(
        'bubblesplash/ofertas/disponibles/?incluir_bloqueadas=1',
      );

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);

        // Soportar tanto lista directa como envoltorios tipo {results: [...]} / {ofertas: [...]} / {data: [...]}.
        List<dynamic>? rawList;
        if (body is List) {
          rawList = body;
        } else if (body is Map<String, dynamic>) {
          for (final key in ['results', 'ofertas', 'data']) {
            final value = body[key];
            if (value is List) {
              rawList = value;
              break;
            }
          }
        }

        if (rawList != null) {
          var ofertas = rawList.whereType<Map<String, dynamic>>().toList();

          // Filtrar por estado ACTIVO si existe el campo, pero si ningún
          // elemento lo trae, usamos todos para no dejar la sección vacía
          // cuando el backend cambió el esquema.
          final filtradas = ofertas
              .where(
                (o) =>
                    (o['txt_status'] ?? '').toString().toUpperCase() ==
                    'ACTIVO',
              )
              .toList();
          if (filtradas.isNotEmpty) {
            ofertas = filtradas;
          }

          await prefs.setString(_ofertasCacheKey, jsonEncode(ofertas));
          await prefs.setInt(_ofertasCacheTimeKey, now);

          setState(() {
            _ofertas = ofertas;
            _isLoadingOfertas = false;
            _ofertasError = null;
          });
        } else {
          if (!background) {
            setState(() {
              _isLoadingOfertas = false;
              _ofertasError = 'Formato inesperado de la respuesta de ofertas.';
            });
          }
        }
      } else {
        if (!background) {
          setState(() {
            _isLoadingOfertas = false;
            _ofertasError = 'Error al cargar ofertas (${response.statusCode}).';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (!background) {
        final errStr = e.toString().toLowerCase();
        final isNetwork =
            errStr.contains('socketexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('clientexception') ||
            errStr.contains('handshake') ||
            errStr.contains('network') ||
            errStr.contains('connection');

        setState(() {
          _isLoadingOfertas = false;
          _ofertasError = isNetwork
              ? 'No se pudo conectar con el servidor. Por favor, comprueba tu conexión a Internet e intenta nuevamente.'
              : 'Error al cargar ofertas: $e';
        });

        if (isNetwork && mounted) {
          showConnectionErrorDialog(context, onRetry: _onRefresh);
        }
      }
    } finally {
      if (!mounted) return;
      if (!background) {
        setState(() => _isLoadingOfertas = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _bootstrap(background: false);
    await _loadCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: const CustomAppBar(title: 'Beneficios', tipo: 'regalo'),
      body: SafeArea(
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double margin = 16;
            const double fabDiameter = 56;

            final double minX = margin;
            final double minY = margin;
            final double maxX = (constraints.maxWidth - fabDiameter - margin)
                .clamp(minX, 99999);
            final double maxY = (constraints.maxHeight - fabDiameter - margin)
                .clamp(minY, 99999);

            double resolvedX;
            double resolvedY;

            if (_fabOffset != null) {
              resolvedX = _fabOffset!.dx;
              resolvedY = _fabOffset!.dy;
            } else if (_fabXFrac != null && _fabYFrac != null) {
              final double xRange = (maxX - minX).abs() < 0.001
                  ? 0
                  : (maxX - minX);
              final double yRange = (maxY - minY).abs() < 0.001
                  ? 0
                  : (maxY - minY);
              resolvedX = minX + (_fabXFrac!.clamp(0.0, 1.0) * xRange);
              resolvedY = minY + (_fabYFrac!.clamp(0.0, 1.0) * yRange);
            } else {
              resolvedX = maxX;
              resolvedY = maxY;
            }

            resolvedX = resolvedX.clamp(minX, maxX);
            resolvedY = resolvedY.clamp(minY, maxY);

            if (_fabOffset == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _fabOffset = Offset(resolvedX, resolvedY);
                });
              });
            }

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),

                        // ======= HERO PROGRESO (premium)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F3D4A), Color(0xFF128FA0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -60,
                                  top: -60,
                                  child: Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: -50,
                                  bottom: -50,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.06),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.18,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.stars_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Tu Progreso',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Desbloquea beneficios con tus puntos',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.16,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Nivel: $nivel',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '$puntos pts',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: _progresoMostrado,
                                                minHeight: 10,
                                                color: Colors.white,
                                                backgroundColor: Colors.white24,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              faltanParaSiguiente == 0
                                                  ? '¡Nivel máximo alcanzado!'
                                                  : 'Te faltan ${_metaMostrada - puntos} pts para llegar a $_metaMostrada',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ======= OFERTAS ESPECIALES (header visual mejorado)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF0F3D4A,
                                            ).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.local_offer_rounded,
                                            color: Color(0xFF0F3D4A),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Ofertas especiales',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.2,
                                              color: _textDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Beneficios exclusivos pensados para ti',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _textMute,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _OfertasDisponiblesTag(count: _ofertas.length),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // El carrusel de ofertas que había aquí mostraba la
                        // MISMA lista `_ofertas` que la sección «Recompensas»
                        // de abajo, pero sin ninguna acción: era decorativo.
                        // El resultado era que cada oferta aparecía dos veces
                        // y solo una de las dos se podía canjear.
                        //
                        // Se conserva únicamente la lista que sí permite
                        // canjear; el contador de ofertas disponibles sigue
                        // arriba, en la cabecera.
                        if (_isLoadingOfertas && _ofertas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_ofertasError != null && _ofertas.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _ofertasError!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textMute,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // ======= AVISO DE DESCUENTOS PENDIENTES
                        //
                        // Un solo acceso con el contador, no una pila de
                        // tarjetas: el detalle está en «Mis descuentos». Así
                        // da igual que el cliente acumule uno o diez, la
                        // pantalla no se llena.
                        if (_descuentosPendientes > 0) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MisDescuentosPage(),
                                  ),
                                ).then((_) => _cargarCanjesPendientes());
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F6F8),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFF1B6F81),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Icono con el número, al estilo de una
                                    // notificación: se ve de un vistazo
                                    // cuántos hay sin abrir nada.
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const Icon(
                                          Icons.local_offer_rounded,
                                          color: Color(0xFF1B6F81),
                                        ),
                                        Positioned(
                                          right: -6,
                                          top: -6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE28F83),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$_descuentosPendientes',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _descuentosPendientes == 1
                                                ? 'Tienes 1 descuento sin usar'
                                                : 'Tienes $_descuentosPendientes descuentos sin usar',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: Color(0xFF0F3E47),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Toca para verlos y aplicarlos',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF1B6F81),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ======= CAMINO DE BENEFICIOS
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Camino de beneficios',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F3D4A),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Gana puntos, desbloquea recompensas y '
                                      'disfruta más Bubble.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Atajo a «Cómo funciona». Antes esa explicación
                              // no tenía puerta de entrada desde aquí.
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _mostrarComoFunciona,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF128FA0),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: Color(0xFF128FA0),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _ofertas.isEmpty
                              ? const Text(
                                  'Aún no tienes recompensas disponibles.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _textMute,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Column(
                                  children: _ofertasEnCamino.asMap().entries.map((
                                    entrada,
                                  ) {
                                    final int indice = entrada.key;
                                    final dynamic oferta = entrada.value;
                                    final List<dynamic> camino =
                                        _ofertasEnCamino;
                                    final String titulo =
                                        (oferta['off_txt_title'] ??
                                                'Oferta especial')
                                            .toString();
                                    final String descripcion =
                                        (oferta['off_txt_description'] ?? '')
                                            .toString();
                                    final int puntosReq =
                                        int.tryParse(
                                          (oferta['off_int_pointscost'] ?? '0')
                                              .toString(),
                                        ) ??
                                        0;

                                    final int offerId =
                                        int.tryParse(
                                          (oferta['off_int_id'] ?? '0')
                                              .toString(),
                                        ) ??
                                        0;

                                    final double discountPercent =
                                        double.tryParse(
                                          (oferta['off_de_discountpercent'] ??
                                                  '0')
                                              .toString(),
                                        ) ??
                                        0.0;

                                    String allowedSize =
                                        (oferta['off_txt_allowed_size'] ?? '')
                                            .toString();

                                    if (allowedSize.trim().isEmpty) {
                                      final lowerT = titulo.toLowerCase();
                                      final lowerD = descripcion.toLowerCase();
                                      if (lowerT.contains('median') ||
                                          lowerD.contains('median')) {
                                        allowedSize = 'MEDIANO';
                                      } else if (lowerT.contains('pequeñ') ||
                                          lowerD.contains('pequeñ') ||
                                          lowerT.contains('pequen')) {
                                        allowedSize = 'PEQUENO';
                                      } else if (lowerT.contains('grand') ||
                                          lowerD.contains('grand')) {
                                        allowedSize = 'GRANDE';
                                      }
                                    }

                                    // El riel es continuo: nada de separación
                                    // entre tarjetas, o la línea se corta.
                                    return RewardCard(
                                      title: titulo,
                                      subtitle: descripcion,
                                      pointsCost: puntosReq,
                                      offerId: offerId,
                                      discountPercent: discountPercent,
                                      allowedSize: allowedSize,
                                      puntosUsuario: puntos,
                                      yaCanjeada: oferta['ya_canjeada'] == true,
                                      iconoClave: (oferta['off_txt_icon'] ?? '')
                                          .toString(),
                                      esPremioEnTienda:
                                          (oferta['off_txt_type'] ?? '')
                                              .toString()
                                              .toUpperCase() ==
                                          'PREMIO',
                                      canje: oferta['canje'] is Map
                                          ? Map<String, dynamic>.from(
                                              oferta['canje'],
                                            )
                                          : null,
                                      esPrimera: indice == 0,
                                      esUltima: indice == camino.length - 1,
                                      esProximaMeta:
                                          _costeDeOferta(oferta) == _proximaMetaPuntos,
                                      anteriorLogrado:
                                          indice > 0 &&
                                          (_costeDeOferta(camino[indice - 1]) <=
                                                  puntos ||
                                              camino[indice - 1]['ya_canjeada'] ==
                                                  true),
                                      onPointsChanged: () =>
                                          _cargarPuntos(background: true),
                                    );
                                  }).toList(),
                                ),
                        ),

                        // Cierre del camino.
                        if (_ofertas.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Color(0xFF128FA0),
                                    size: 26,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cada punto te acerca a nuevas '
                                          'experiencias.',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF102A33),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '¡Sigue así!',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),

                // ✅ FAB DRAGGABLE + PERSISTENTE
                AnimatedPositioned(
                  left: resolvedX,
                  top: resolvedY,
                  duration: _isDraggingFab
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      setState(() {
                        _isDraggingFab = true;
                        _fabDragStartGlobal = details.globalPosition;
                        _fabDragStartOffset = Offset(resolvedX, resolvedY);
                      });
                    },
                    onPanUpdate: (details) {
                      final startGlobal = _fabDragStartGlobal;
                      final startOffset = _fabDragStartOffset;
                      if (startGlobal == null || startOffset == null) return;

                      final delta = details.globalPosition - startGlobal;
                      final newX = (startOffset.dx + delta.dx).clamp(
                        minX,
                        maxX,
                      );
                      final newY = (startOffset.dy + delta.dy).clamp(
                        minY,
                        maxY,
                      );

                      setState(() {
                        _fabOffset = Offset(newX, newY);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _isDraggingFab = false;
                        _fabDragStartGlobal = null;
                        _fabDragStartOffset = null;
                      });

                      _snapFabToEdge(
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                      );
                    },
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: _isDraggingFab ? 1.06 : 1.0,
                      child: _buildCartFabButton(count: _cartCount),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ===============================
/// TAG: Ofertas disponibles
/// ===============================
class _OfertasDisponiblesTag extends StatelessWidget {
  final int count;

  const _OfertasDisponiblesTag({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 Oferta' : '$count Ofertas';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_offer_rounded,
            size: 14,
            color: Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// Card destacada del carrusel
/// ===============================
class _OfferHighlightCard extends StatelessWidget {
  final String title;
  final String description;
  final String tipo;
  final double descuentoPercent;
  final String minSpend;
  final int minOrders;
  final int puntosReq;

  const _OfferHighlightCard({
    required this.title,
    required this.description,
    required this.tipo,
    required this.descuentoPercent,
    required this.minSpend,
    required this.minOrders,
    required this.puntosReq,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasOff = descuentoPercent > 0;
    final bool hasMinSpend =
        minSpend.trim().isNotEmpty && minSpend != '0.00' && minSpend != '0';

    return Container(
      decoration: BoxDecoration(
        // Fondo más "bubble" con toque acuoso, menos de tienda.
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFFECFEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000033),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F3D4A), Color(0xFF128FA0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_iconoPorTipo(tipo), color: Colors.white),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 110, // Ajusta este valor según tu diseño
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (hasOff)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${descuentoPercent.toStringAsFixed(0)}% desc.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              )
                            else if (puntosReq > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$puntosReq pts',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (tipo.trim().isNotEmpty)
                              _Pill(text: 'Tipo: $tipo', icon: Icons.category),
                            if (hasOff)
                              _Pill(
                                text:
                                    'Descuento ${descuentoPercent.toStringAsFixed(0)}%',
                                icon: Icons.percent,
                              ),
                            if (hasMinSpend)
                              _Pill(
                                text: 'Min S/ $minSpend',
                                icon: Icons.payments,
                              ),
                            if (minOrders > 0)
                              _Pill(
                                text: 'Min $minOrders pedidos',
                                icon: Icons.receipt,
                              ),
                            if (puntosReq > 0)
                              _Pill(
                                text: '$puntosReq pts',
                                icon: Icons.stars_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Pill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0F3D4A)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// TARJETA DE RECOMPENSA (PREMIUM)
/// ===============================
class RewardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int pointsCost;
  final int offerId;
  final double discountPercent;
  final String? allowedSize;
  final VoidCallback? onPointsChanged;

  /// Puntos que tiene el usuario ahora mismo.
  ///
  /// Es lo que decide si el beneficio está desbloqueado. Antes la tarjeta no
  /// lo sabía: todas ofrecían «Canjear» por igual y el rechazo por puntos
  /// insuficientes solo aparecía después de pulsar, que es la peor forma de
  /// enterarse.
  final int puntosUsuario;

  /// Posición dentro del camino. La calcula la pantalla: una tarjeta no puede
  /// saber qué hay antes o después de ella.
  final bool esProximaMeta;
  final bool esPrimera;
  final bool esUltima;
  final bool anteriorLogrado;

  /// Imagen del producto asociado, si la oferta tiene uno.
  final String? imagenUrl;

  /// Ya lo canjeó y tiene el beneficio esperando a usarse.
  final bool yaCanjeada;

  /// Icono elegido por el administrador en el panel. Vacío = se deduce.
  final String? iconoClave;

  /// El premio se entrega en el local, no se canjea sobre una bebida.
  final bool esPremioEnTienda;

  /// Datos del canje ya realizado: referencia, estado y fecha.
  final Map<String, dynamic>? canje;

  const RewardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pointsCost,
    required this.offerId,
    required this.discountPercent,
    required this.puntosUsuario,
    this.esProximaMeta = false,
    this.esPrimera = false,
    this.esUltima = false,
    this.anteriorLogrado = false,
    this.imagenUrl,
    this.yaCanjeada = false,
    this.iconoClave,
    this.esPremioEnTienda = false,
    this.canje,
    this.allowedSize,
    this.onPointsChanged,
  });

  /// ¿Alcanza ya para este beneficio?
  ///
  /// Lo YA CANJEADO cuenta siempre como alcanzado, aunque los puntos actuales
  /// no lleguen: canjearlo es precisamente lo que los gastó. Comparando solo
  /// los puntos de ahora, un premio de 1000 puntos volvía a salir bloqueado
  /// justo después de canjearlo —el cliente se queda a 0— y la tarjeta dejaba
  /// de responder al toque, así que no había forma de volver a ver su código.
  bool get desbloqueado =>
      yaCanjeada || pointsCost <= 0 || puntosUsuario >= pointsCost;

  /// Cuántos puntos le faltan. 0 si ya lo tiene.
  int get puntosFaltantes =>
      desbloqueado ? 0 : pointsCost - puntosUsuario;

  /// Lo que falta, en singular o plural según toque.
  ///
  /// «Te faltan 1 pts» justo antes de desbloquear un premio es la frase que
  /// más gente va a leer, porque es el momento en que están mirando.
  String get _textoFaltan => puntosFaltantes == 1
      ? 'Te falta 1 punto'
      : 'Te faltan $puntosFaltantes pts';

  static const Color _textDark = Color(0xFF1F2A37);
  static const Color _brandDeep = Color(0xFF0F3D4A);


  /// Descripción de la oferta, o una redactada si el administrador no puso
  /// ninguna.
  ///
  /// Dejar ese hueco en blanco al confirmar es peor que una frase genérica: el
  /// usuario está a punto de gastar puntos y no se le puede pedir que adivine
  /// qué está comprando.
  String get _descripcionLegible {
    final texto = subtitle.trim();
    if (texto.isNotEmpty) return texto;

    if (discountPercent > 0) {
      return 'Obtienes un ${discountPercent.toStringAsFixed(0)}% de descuento '
          'en tu próximo pedido.';
    }
    return 'Un beneficio para usar en tu próximo pedido.';
  }

  /// Condiciones concretas del beneficio, en frases sueltas.
  List<String> get _condiciones {
    final lista = <String>[];

    if (discountPercent > 0) {
      lista.add(
        '${discountPercent.toStringAsFixed(0)}% de descuento sobre el precio.',
      );
    }

    final tam = (allowedSize ?? '').trim();
    if (tam.isNotEmpty) {
      lista.add('Válido en tamaño ${etiquetaTamano(tam)}.');
    } else {
      lista.add('Válido en cualquier tamaño.');
    }

    if (pointsCost > 0) {
      lista.add('Se descuentan $pointsCost puntos de tu cuenta.');
    }

    // Un premio de tienda no se aplica a ningún carrito: se recoge en el
    // local. Prometer lo contrario al confirmar sería engañarle.
    if (esPremioEnTienda) {
      lista.add('Se recoge en la tienda, no se aplica a un pedido.');
    } else {
      lista.add('Se aplica al añadir el producto al carrito.');
    }
    return lista;
  }

  /// « el 5 de agosto», o vacío si el servidor aún no manda la fecha.
  ///
  /// Que el cliente pueda ver CUÁNDO se le entregó evita la discusión de
  /// mostrador más incómoda: «a mí nadie me dio nada».
  String get _fechaEntrega {
    final crudo = (canje?['entregado_el'] ?? '').toString();
    final fecha = DateTime.tryParse(crudo);
    if (fecha == null) return '';

    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final local = fecha.toLocal();
    return ' el ${local.day} de ${meses[local.month - 1]}';
  }

  /// Detalle de un beneficio YA canjeado.
  ///
  /// Reutiliza el mismo aviso que sale al canjear un premio, para que el
  /// cliente vuelva a ver su código en el mostrador. Para un descuento el
  /// mensaje es otro: ahí lo que necesita es recordar que lo tiene esperando
  /// y cómo usarlo.
  Future<void> _mostrarDetalleCanjeado(BuildContext context) async {
    final referencia = (canje?['referencia'] ?? '').toString();
    final estado = (canje?['estado'] ?? '').toString().toUpperCase();
    final entregado = estado == 'USADO';

    if (esPremioEnTienda) {
      await _mostrarPremioEnTienda(context, {
        'titulo': entregado ? 'Premio ya recogido' : 'Tu premio te espera',
        'premio': title,
        'message': entregado
            ? 'Entregado en tienda${_fechaEntrega}. ¡Que lo disfrutes!'
            : (_descripcionLegible),
        // El código se enseña SIEMPRE, también si ya se entregó: es el
        // identificador con el que tu personal encuentra el canje en el panel.
        // Ocultarlo dejaba al cliente sin nada que dar en el mostrador cuando
        // había cualquier duda.
        'referencia': referencia,
        'entregado': entregado,
        'label': 'Cerrar',
      });
      return;
    }

    // Descuento sobre una bebida.
    const Color brandTeal = Color(0xFF128FA0);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          entregado ? 'Beneficio ya usado' : 'Beneficio listo para usar',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F3D4A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF102A33),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entregado
                  ? 'Ya lo aplicaste en un pedido.'
                  : 'Lo tienes esperando. Se aplica al añadir tu bebida al '
                        'carrito.',
              style: const TextStyle(
                fontSize: 13.2,
                height: 1.4,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            ..._condiciones.map(
              (c) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle,
                        size: 14,
                        color: brandTeal,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 12.3,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cerrar',
              style: TextStyle(fontWeight: FontWeight.w800, color: brandTeal),
            ),
          ),
          if (!entregado)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuPage(
                      descuento: discountPercent / 100.0,
                      ofcIntId: int.tryParse(referencia),
                      allowedSize: allowedSize,
                    ),
                  ),
                );
              },
              child: const Text(
                'Usarlo ahora',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }

  /// Aviso para los premios que se entregan en el local.
  ///
  /// El texto es la descripción que el administrador escribió en el
  /// formulario de la oferta: es donde explica qué es el premio y cómo
  /// reclamarlo, así que se muestra tal cual en lugar de una frase inventada
  /// aquí que se quedaría desactualizada.
  Future<void> _mostrarPremioEnTienda(
    BuildContext context,
    Map<String, dynamic> accion,
  ) async {
    const Color brandTeal = Color(0xFF128FA0);
    const Color brandDeep = Color(0xFF0F3D4A);

    final premio = (accion['premio'] ?? title).toString();
    final mensaje = (accion['message'] ?? '').toString().trim();
    // Puede llegar vacía a propósito: un premio ya entregado no enseña
    // código, porque volver a mostrarlo invita a llevarlo otra vez al
    // mostrador.
    final referencia = (accion['referencia'] ?? '').toString().trim();
    final yaEntregado = accion['entregado'] == true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: brandTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: brandTeal,
                size: 34,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (accion['titulo'] ?? '¡Premio desbloqueado!').toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: brandDeep,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              premio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: brandDeep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mensaje.isEmpty
                  ? 'Acércate a la tienda para reclamar tu premio.'
                  : mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (referencia.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Si no ves tu código, pide en tienda que busquen tu premio '
                'por tu nombre.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (referencia.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB6E3DF)),
                ),
                child: Column(
                  children: [
                    Text(
                      yaEntregado
                          ? 'CÓDIGO DE TU PREMIO (YA ENTREGADO)'
                          : 'ENSEÑA ESTE CÓDIGO EN EL MOSTRADOR',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#$referencia',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: brandTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Lo encontrarás también en Beneficios, marcado como canjeado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onPointsChanged?.call();
            },
            child: Text(
              (accion['label'] ?? 'Entendido').toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  /// Ejecuta el canje del beneficio.
  ///
  /// Vive fuera de `build` porque ahora se dispara desde la tarjeta entera y
  /// ya no desde un botón: la lógica no debía duplicarse ni moverse de sitio
  /// al cambiar el diseño.
  Future<void> _canjear(BuildContext context) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        return _ConfirmRedeemDialog(
          title: 'Confirmar canje',
          beneficio: title,
          descripcion: _descripcionLegible,
          condiciones: _condiciones,
          message:
              'Solo se puede usar una vez. Los puntos se descuentan al '
              'confirmar.',
          highlight: pointsCost > 0 ? '-$pointsCost pts' : 'Gratis',
        );
      },
    );

    if (confirmar != true) return;

    final double descuento = discountPercent / 100.0;

    final prefs = await SharedPreferences.getInstance();
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final String? email =
        prefs.getString('google_email') ??
        prefs.getString('savedEmail');

    if (user == null && (email == null || email.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes iniciar sesión para canjear beneficios.',
          ),
        ),
      );
      return;
    }

    final rawToken = prefs.getString('access_token');
    if (rawToken == null || rawToken.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay access token. Inicia sesión nuevamente.',
          ),
        ),
      );
      return;
    }

    if (offerId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo identificar la oferta a canjear.',
          ),
        ),
      );
      return;
    }

    final String userUniqueId = user?.uid ?? email!;
    final String keyPuntos = 'puntos_$userUniqueId';
    int currentPoints = prefs.getInt(keyPuntos) ?? 0;

    if (pointsCost > 0 && currentPoints < pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No tienes suficientes puntos para canjear este beneficio.',
          ),
        ),
      );
      return;
    }

    try {
      final token = rawToken.trim();
      final uri = BackendConfig.api(
        'bubblesplash/ofertas/$offerId/canjear/',
      );

      http.Response response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'off_int_id': offerId}),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        int? ofcIntId;
        int? backendPoints;
        Map<String, dynamic>? siguiente;

        // Intentar extraer ofc_int_id (id del canje) y puntos desde la respuesta
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic canje = decoded['canje'];
            if (canje is Map<String, dynamic>) {
              final dynamic rawOfc = canje['ofc_int_id'];
              if (rawOfc is int) {
                ofcIntId = rawOfc;
              } else {
                ofcIntId = int.tryParse(rawOfc?.toString() ?? '');
              }
            }

            final dynamic accion = decoded['next_action'];
            if (accion is Map<String, dynamic>) siguiente = accion;

            final dynamic points = decoded['points'];
            if (points is Map<String, dynamic>) {
              final dynamic rawTotal =
                  points['upo_int_totalpoints'];
              if (rawTotal is int) {
                backendPoints = rawTotal;
              } else if (rawTotal != null) {
                backendPoints = int.tryParse(rawTotal.toString());
              }
            }
          }
        } catch (_) {}

        if (pointsCost > 0) {
          final int newPoints =
              backendPoints ?? (currentPoints - pointsCost);
          await prefs.setInt(keyPuntos, newPoints);
          onPointsChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Canje exitoso: -$pointsCost pts. Te quedan $newPoints pts.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Beneficio canjeado correctamente.'),
            ),
          );
        }

        // Premio que se recoge en el local: no hay bebida que elegir, así que
        // llevarle al menú sería mandarle a una pantalla que no le sirve.
        //
        // Se mira TAMBIÉN el tipo de la propia oferta, no solo lo que responde
        // el servidor al canjear: la app ya sabe que es un premio de tienda
        // desde que cargó la lista, y así el aviso sale aunque el servidor
        // todavía no tenga desplegada esa respuesta.
        if (esPremioEnTienda ||
            (siguiente?['route'] ?? '').toString() == 'tienda') {
          if (!context.mounted) return;
          await _mostrarPremioEnTienda(context, {
            'titulo': '¡Premio desbloqueado!',
            'premio': title,
            'message': _descripcionLegible,
            // El id del canje es la referencia que enseñará en el mostrador.
            'referencia': (ofcIntId ?? '').toString(),
            'label': 'Entendido',
            // Lo que mande el servidor manda sobre lo anterior.
            ...?siguiente,
          });
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuPage(
              descuento: descuento,
              // Usar el id REAL del canje (ofc_int_id), no el id de la oferta
              ofcIntId: ofcIntId,
              allowedSize: allowedSize,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo canjear el beneficio (${response.statusCode}).',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al canjear el beneficio: $e'),
        ),
      );
    }
  }

  // Paleta del camino de beneficios.
  static const Color _rielActivo = Color(0xFF128FA0);
  static const Color _rielInactivo = Color(0xFFCBD5D8);
  static const Color _fondoLogrado = Color(0xFFE7F4F3);
  static const Color _fondoBloqueado = Color(0xFFF1F3F4);
  static const Color _grisTexto = Color(0xFF9AA5AB);

  @override
  Widget build(BuildContext context) {
    final bool isPaid = pointsCost > 0;

    // Tres estados posibles, y solo tres: logrado, próxima meta, bloqueado.
    // La «próxima meta» la decide la pantalla (es la primera bloqueada), no la
    // tarjeta: ninguna sabe qué hay antes o después de ella.
    final bool logrado = desbloqueado;
    final bool proximaMeta = !logrado && esProximaMeta;

    final Color colorAcento = logrado
        ? _rielActivo
        : proximaMeta
        ? _rielActivo
        : _grisTexto;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- Riel de la izquierda ----------
          SizedBox(width: 56, child: _riel(logrado, proximaMeta)),

          // ---------- Tarjeta ----------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  // Solo se puede tocar lo que ya está desbloqueado. Una
                  // tarjeta bloqueada que responde al toque promete algo que
                  // luego no ocurre.
                  // Lo canjeado también responde al toque, pero para
                  // CONSULTAR: el cliente necesita volver a ver el código de
                  // su premio, y una tarjeta muda parecía estropeada.
                  onTap: !logrado
                      ? null
                      : yaCanjeada
                      ? () => _mostrarDetalleCanjeado(context)
                      : () => _canjear(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: yaCanjeada
                          ? const Color(0xFFE9F7EE)
                          : logrado
                          ? _fondoLogrado
                          : proximaMeta
                          ? Colors.white
                          : _fondoBloqueado,
                      borderRadius: BorderRadius.circular(18),
                      border: proximaMeta
                          ? Border.all(color: _rielActivo, width: 2)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Row(
                            children: [
                              _miniatura(logrado, proximaMeta),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isPaid ? '$pointsCost pts' : 'Gratis',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: colorAcento,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: logrado || proximaMeta
                                            ? const Color(0xFF102A33)
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      yaCanjeada
                                          ? 'Ya canjeado · toca para ver'
                                          : logrado
                                          ? 'Desbloqueado'
                                          : proximaMeta
                                          ? 'Tu próxima meta'
                                          : 'Bloqueado',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: yaCanjeada
                                            ? const Color(0xFF16A34A)
                                            : logrado
                                            ? _rielActivo
                                            : _grisTexto,
                                      ),
                                    ),
                                    // Cuánto falta. No está en el diseño, pero
                                    // sin esto la meta no dice qué la separa
                                    // de estar cumplida.
                                    if (proximaMeta) ...[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: LinearProgressIndicator(
                                          value: (puntosUsuario / pointsCost)
                                              .clamp(0.0, 1.0),
                                          minHeight: 5,
                                          backgroundColor:
                                              const Color(0xFFE5E7EB),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(_rielActivo),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _textoFaltan,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // La próxima meta no lleva sello: ese hueco lo
                              // ocupa la cinta.
                              if (!proximaMeta) _sello(logrado),
                            ],
                          ),
                        ),

                        // ---------- Cinta «PRÓXIMA META» ----------
                        if (proximaMeta)
                          Positioned(
                            top: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 62,
                              color: _rielActivo,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.adjust,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'PRÓXIMA\nMETA',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      height: 1.15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Riel vertical con el nodo de este hito.
  ///
  /// El tramo de arriba se pinta según el hito ANTERIOR y el de abajo según
  /// este: así la línea llega sólida hasta donde el usuario ha llegado y sigue
  /// punteada a partir de ahí, sin que ninguna tarjeta tenga que saber de las
  /// demás más allá de sus vecinas.
  Widget _riel(bool logrado, bool proximaMeta) {
    return Column(
      children: [
        Expanded(
          child: esPrimera
              ? const SizedBox.shrink()
              : _tramo(solido: anteriorLogrado),
        ),
        _nodo(logrado, proximaMeta),
        Expanded(
          child: esUltima
              ? const SizedBox.shrink()
              : _tramo(solido: logrado),
        ),
      ],
    );
  }

  Widget _tramo({required bool solido}) {
    if (solido) {
      return Container(width: 3, color: _rielActivo);
    }
    // Punteado dibujado a mano.
    //
    // Aquí NO se puede usar LayoutBuilder: este riel vive dentro de un
    // `IntrinsicHeight` —hace falta para que la línea llegue exactamente al
    // alto de la tarjeta— y Flutter no permite consultar dimensiones
    // intrínsecas a través de un LayoutBuilder. Lanzaba una excepción en cada
    // frame y la pantalla se quedaba congelada.
    //
    // `CustomPaint` no tiene ese problema: declara alto intrínseco 0 y se
    // estira con el Expanded que lo envuelve.
    return const CustomPaint(
      size: Size(3, 0),
      painter: _RielPunteado(),
    );
  }

  Widget _nodo(bool logrado, bool proximaMeta) {
    if (logrado) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: _rielActivo,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 20),
      );
    }

    if (proximaMeta) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _rielActivo, width: 3),
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: _rielActivo,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _rielInactivo, width: 2),
      ),
      child: const Icon(Icons.lock, color: _grisTexto, size: 16),
    );
  }

  /// Miniatura del beneficio.
  ///
  /// Las ofertas no guardan imagen propia, así que se usa la del producto
  /// requerido cuando existe y, si no, un icono sobre fondo de marca. Sale
  /// apagada mientras el hito siga bloqueado.
  Widget _miniatura(bool logrado, bool proximaMeta) {
    final bool encendida = logrado || proximaMeta;
    final String url = (imagenUrl ?? '').trim();

    Widget contenido;
    if (url.startsWith('http')) {
      contenido = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconoMiniatura(encendida),
      );
    } else {
      contenido = _iconoMiniatura(encendida);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 62,
        height: 62,
        child: encendida
            ? contenido
            : ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: contenido,
              ),
      ),
    );
  }

  /// Aspecto de la miniatura cuando la oferta no trae imagen.
  ///
  /// Se elige por lo que DICE la oferta, no por su posición: un «topping
  /// extra» y un «2x1» tienen que verse distintos aunque el administrador los
  /// cree en cualquier orden. Si el título no da ninguna pista, se reparte un
  /// aspecto por el id de la oferta, que es estable: la misma oferta se ve
  /// siempre igual, y dos ofertas seguidas no se ven iguales entre sí.
  _AspectoBeneficio get _aspecto {
    // Lo que eligió el administrador manda. La deducción por título es el
    // recurso para cuando no eligió nada, no una opinión que compita con la
    // suya.
    final elegido = aspectoElegido(iconoClave);
    if (elegido != null) {
      return _AspectoBeneficio(elegido.icono, elegido.color, elegido.fondo);
    }

    final texto = '$title $subtitle'.toLowerCase();

    bool dice(List<String> claves) => claves.any(texto.contains);

    if (dice(['topping', 'perla', 'tapioca'])) {
      return const _AspectoBeneficio(
        Icons.bubble_chart,
        Color(0xFF8B5E34),
        [Color(0xFFF6E7D2), Color(0xFFE9D2B4)],
      );
    }
    if (dice(['tamaño', 'tamano', 'upgrade', 'grande', 'agranda'])) {
      return const _AspectoBeneficio(
        Icons.arrow_circle_up,
        Color(0xFF2E7D32),
        [Color(0xFFDDF3DF), Color(0xFFC2E7C6)],
      );
    }
    if (dice(['2x1', '2 x 1', 'dos por', 'cupon', 'cupón'])) {
      return const _AspectoBeneficio(
        Icons.confirmation_number,
        Color(0xFF00838F),
        [Color(0xFFD3EFF3), Color(0xFFB2E2E8)],
      );
    }
    if (dice(['premium', 'vip', 'especial', 'exclusiv'])) {
      return const _AspectoBeneficio(
        Icons.workspace_premium,
        Color(0xFF7B3FA0),
        [Color(0xFFEDDDF6), Color(0xFFDCC2EC)],
      );
    }
    if (dice(['descuento', '%', 'oferta', 'rebaja'])) {
      return const _AspectoBeneficio(
        Icons.percent,
        Color(0xFFC2410C),
        [Color(0xFFFBE3D4), Color(0xFFF6CDB2)],
      );
    }
    // La bebida va ANTES que «gratis»: casi todo beneficio lleva esa palabra,
    // y sin este orden un «Bubble gratis» salía con icono de regalo en vez de
    // con el de la bebida.
    if (dice(['bubble', 'bebida', 'té', 'te ', 'refresco', 'smoothie'])) {
      return const _AspectoBeneficio(
        Icons.local_cafe,
        Color(0xFF128FA0),
        [Color(0xFFD5EFEC), Color(0xFFB6E3DF)],
      );
    }
    if (dice(['gratis', 'regalo', 'invita'])) {
      return const _AspectoBeneficio(
        Icons.card_giftcard,
        Color(0xFFB3245C),
        [Color(0xFFFBDCE7), Color(0xFFF5BFD2)],
      );
    }
    if (dice(['envio', 'envío', 'delivery'])) {
      return const _AspectoBeneficio(
        Icons.delivery_dining,
        Color(0xFF1565C0),
        [Color(0xFFD8E6F8), Color(0xFFBBD4F2)],
      );
    }

    // Sin pistas: variedad estable por id.
    const surtido = <_AspectoBeneficio>[
      _AspectoBeneficio(
        Icons.local_cafe,
        Color(0xFF128FA0),
        [Color(0xFFD5EFEC), Color(0xFFB6E3DF)],
      ),
      _AspectoBeneficio(
        Icons.emoji_food_beverage,
        Color(0xFF00695C),
        [Color(0xFFD2ECE6), Color(0xFFB3DED5)],
      ),
      _AspectoBeneficio(
        Icons.icecream,
        Color(0xFFAD1457),
        [Color(0xFFFBDDEA), Color(0xFFF4C0D6)],
      ),
      _AspectoBeneficio(
        Icons.star_rounded,
        Color(0xFFB27400),
        [Color(0xFFFBEED2), Color(0xFFF4DFAE)],
      ),
      _AspectoBeneficio(
        Icons.local_drink,
        Color(0xFF4527A0),
        [Color(0xFFE2DDF6), Color(0xFFCBC2EC)],
      ),
    ];
    return surtido[offerId.abs() % surtido.length];
  }

  Widget _iconoMiniatura(bool encendida) {
    final aspecto = _aspecto;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: encendida
              ? aspecto.fondo
              : const [Color(0xFFE3E7E9), Color(0xFFD2D8DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        aspecto.icono,
        color: encendida ? aspecto.color : _grisTexto,
        size: 30,
      ),
    );
  }

  Widget _sello(bool logrado) {
    // Lo canjeado se distingue de lo meramente desbloqueado: uno ya es tuyo,
    // el otro todavía hay que reclamarlo.
    final Color fondo = yaCanjeada
        ? const Color(0xFF16A34A)
        : logrado
        ? _rielActivo
        : const Color(0xFFCBD5D8);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Icon(
        yaCanjeada
            ? Icons.card_giftcard
            : logrado
            ? Icons.check
            : Icons.lock,
        color: Colors.white,
        size: logrado ? 19 : 16,
      ),
    );
  }
}

class _ConfirmRedeemDialog extends StatelessWidget {
  final String title;
  final String message;
  final String highlight;

  /// Nombre del beneficio que se va a canjear.
  final String beneficio;

  /// En qué consiste, tal como lo escribió el administrador.
  final String descripcion;

  /// Condiciones concretas: descuento, tamaño, producto, gasto mínimo.
  ///
  /// Se enseñan al confirmar y no solo en la tarjeta: el canje gasta puntos y
  /// es irreversible, así que las letras pequeñas tienen que estar delante en
  /// el momento de decidir, no una pantalla antes.
  final List<String> condiciones;

  const _ConfirmRedeemDialog({
    required this.title,
    required this.message,
    required this.highlight,
    this.beneficio = '',
    this.descripcion = '',
    this.condiciones = const [],
  });

  static const Color _brandDeep = Color(0xFF0F3D4A);
  static const Color _brandMid = Color(0xFF128FA0);

  @override
  Widget build(BuildContext context) {
    const IconData benefitsIcon = Icons.card_giftcard_rounded;

    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(18, 18, 18, 24 + viewInsetsBottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.90),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.65),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 26,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_brandDeep, _brandMid],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.26),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          benefitsIcon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white.withOpacity(0.95),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),

                // BODY (sin altura máxima)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  highlight,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (beneficio.trim().isNotEmpty) ...[
                        Text(
                          beneficio,
                          style: const TextStyle(
                            color: Color(0xFF0F3D4A),
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (descripcion.trim().isNotEmpty) ...[
                        Text(
                          descripcion,
                          style: const TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (condiciones.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F8F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Qué incluye',
                                style: TextStyle(
                                  color: Color(0xFF0F3D4A),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...condiciones.map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: Color(0xFF128FA0),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          c,
                                          style: const TextStyle(
                                            color: Color(0xFF374151),
                                            fontSize: 12.3,
                                            height: 1.3,
                                            fontWeight: FontWeight.w600,
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
                        const SizedBox(height: 10),
                      ],
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12.3,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ACTIONS
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_brandDeep, _brandMid],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Sí, canjear',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

/// Línea vertical de puntos del camino de beneficios.
class _RielPunteado extends CustomPainter {
  const _RielPunteado();

  static const double _diametro = 3;
  static const double _separacion = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || !size.height.isFinite) return;

    final pincel = Paint()..color = const Color(0xFFCBD5D8);
    final x = size.width / 2;

    for (double y = _diametro; y < size.height; y += _separacion) {
      canvas.drawCircle(Offset(x, y), _diametro / 2, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _RielPunteado oldDelegate) => false;
}

/// Icono y colores con los que se dibuja un beneficio sin imagen propia.
class _AspectoBeneficio {
  final IconData icono;
  final Color color;
  final List<Color> fondo;

  const _AspectoBeneficio(this.icono, this.color, this.fondo);
}
