import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'CartPage.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'menu_page.dart';
import 'dart:ui';

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
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1,
                  ),
                ),
                child: Icon(_iconoPorTipo(tipo), color: Colors.white, size: 24),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                    width: 1,
                  ),
                ),
                child: const Row(
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
            ],
          ),
        ),
      ),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final keyPoints = '$_puntosCacheKeyPrefix${user.uid}';
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
    } finally {
      _isFetching = false;
    }
  }

  // =============================
  // CARRITO (SharedPreferences)
  // =============================
  Future<List<Map<String, dynamic>>> _loadCartFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
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
    return items;
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        puntos = 0;
        _actualizarNivelYProgreso();
      });
      return;
    }

    final String keyPuntos = 'puntos_${user.uid}';
    final String cacheKey = '$_puntosCacheKeyPrefix${user.uid}';
    final String cacheTimeKey = '$_puntosCacheTimeKeyPrefix${user.uid}';

    try {
      final rawToken = prefs.getString('access_token');

      // Si no hay token, usa local
      if (rawToken == null || rawToken.trim().isEmpty) {
        final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
        if (!mounted) return;
        setState(() {
          puntos = storedPoints;
          _actualizarNivelYProgreso();
        });
        return;
      }

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
        await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

        if (!mounted) return;
        setState(() {
          puntos = backendPoints;
          _actualizarNivelYProgreso();
        });
      } else {
        final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
        if (!mounted) return;
        setState(() {
          puntos = storedPoints;
          _actualizarNivelYProgreso();
        });
      }
    } catch (_) {
      final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
      if (!mounted) return;
      setState(() {
        puntos = storedPoints;
        _actualizarNivelYProgreso();
      });
    }
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
      final uri = BackendConfig.api('bubblesplash/ofertas/disponibles/');

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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);

        if (body is List) {
          final ofertas = body
              .whereType<Map<String, dynamic>>()
              .where(
                (o) =>
                    (o['txt_status'] ?? '').toString().toUpperCase() ==
                    'ACTIVO',
              )
              .toList();

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
        setState(() {
          _isLoadingOfertas = false;
          _ofertasError = 'Error al cargar ofertas: $e';
        });
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
      appBar: const CustomAppBar(title: 'Beneficios', tipo: ''),
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
                                                value: progreso,
                                                minHeight: 10,
                                                color: Colors.white,
                                                backgroundColor: Colors.white24,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              faltanParaSiguiente == 0
                                                  ? '¡Nivel máximo alcanzado!'
                                                  : 'Te faltan $faltanParaSiguiente pts para llegar a $nextThreshold',
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

                        // ======= OFERTAS ESPECIALES (header)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Ofertas Especiales',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _textDark,
                                  ),
                                ),
                              ),
                              _OfertasDisponiblesTag(count: _ofertas.length),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_isLoadingOfertas && _ofertas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_ofertasError != null && _ofertas.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              _ofertasError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (_ofertas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'No hay ofertas disponibles por el momento.',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textMute,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 168,
                            child: PageView.builder(
                              controller: PageController(
                                viewportFraction: 0.92,
                              ),
                              itemCount: _ofertas.length,
                              itemBuilder: (context, index) {
                                final oferta = _ofertas[index];

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

                                final String tipo =
                                    (oferta['off_txt_type'] ?? '').toString();
                                final double descuentoPercent =
                                    double.tryParse(
                                      (oferta['off_de_discountpercent'] ?? '0')
                                          .toString(),
                                    ) ??
                                    0.0;

                                final String minSpend =
                                    (oferta['off_de_mintotalspend'] ?? '0')
                                        .toString();
                                final int minOrders =
                                    int.tryParse(
                                      (oferta['off_int_minorderscount'] ?? '0')
                                          .toString(),
                                    ) ??
                                    0;

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 8,
                                  ),
                                  child: _OfferHighlightCard(
                                    title: titulo,
                                    description: descripcion,
                                    tipo: tipo,
                                    descuentoPercent: descuentoPercent,
                                    minSpend: minSpend,
                                    minOrders: minOrders,
                                    puntosReq: puntosReq,
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),

                        // ======= RECOMPENSAS
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Recompensas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

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
                                  children: _ofertas.map((oferta) {
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

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: RewardCard(
                                        title: titulo,
                                        subtitle: descripcion,
                                        pointsCost: puntosReq,
                                        offerId: offerId,
                                        discountPercent: discountPercent,
                                        onPointsChanged: () =>
                                            _cargarPuntos(background: true),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),

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
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF22C55E)],
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
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
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
                                text: '${descuentoPercent.toStringAsFixed(0)}% OFF',
                                icon: Icons.percent,
                              ),
                            if (hasMinSpend)
                              _Pill(text: 'Min S/ $minSpend', icon: Icons.payments),
                            if (minOrders > 0)
                              _Pill(
                                text: 'Min $minOrders pedidos',
                                icon: Icons.receipt,
                              ),
                            if (puntosReq > 0)
                              _Pill(text: '$puntosReq pts', icon: Icons.stars_rounded),
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
  final VoidCallback? onPointsChanged;

  const RewardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pointsCost,
    required this.offerId,
    required this.discountPercent,
    this.onPointsChanged,
  });

  static const Color _textDark = Color(0xFF1F2A37);
  static const Color _brandDeep = Color(0xFF0F3D4A);

  @override
  Widget build(BuildContext context) {
    final bool isPaid = pointsCost > 0;
    final String buttonText = isPaid ? 'Canjear' : 'Ver beneficio';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F3D4A), Color(0xFF128FA0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_offer, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.trim().isEmpty ? ' ' : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (discountPercent > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.percent,
                            size: 16,
                            color: Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${discountPercent.toStringAsFixed(0)}% de descuento',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isPaid ? _textDark : const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPaid ? '$pointsCost' : 'Gratis',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final bool? confirmar = await showDialog<bool>(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black.withOpacity(0.55),
                  builder: (ctx) {
                    return _ConfirmRedeemDialog(
                      title: 'Confirmar canje',
                      message:
                          'Este beneficio solo se puede usar una vez.\n¿Deseas canjearlo ahora?',
                      highlight: pointsCost > 0 ? '-$pointsCost pts' : 'Gratis',
                    );
                  },
                );

                if (confirmar != true) return;

                final double descuento = discountPercent / 100.0;

                final prefs = await SharedPreferences.getInstance();
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
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

                final String keyPuntos = 'puntos_${user.uid}';
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
                  );

                  if (response.statusCode == 401 &&
                      await AuthService.refreshToken()) {
                    final newToken = prefs.getString('access_token')?.trim();
                    if (newToken != null && newToken.isNotEmpty) {
                      response = await http.post(
                        uri,
                        headers: {
                          'Content-Type': 'application/json',
                          'Accept': 'application/json',
                          'Authorization': 'Bearer $newToken',
                        },
                      );
                    }
                  }

                  if (response.statusCode == 200 ||
                      response.statusCode == 201) {
                    if (pointsCost > 0) {
                      final int newPoints = currentPoints - pointsCost;
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

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuPage(descuento: descuento),
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRedeemDialog extends StatelessWidget {
  final String title;
  final String message;
  final String highlight;

  const _ConfirmRedeemDialog({
    required this.title,
    required this.message,
    required this.highlight,
  });

  static const Color _brandDeep = Color(0xFF0F3D4A);
  static const Color _brandMid = Color(0xFF128FA0);

  @override
  Widget build(BuildContext context) {
    const IconData benefitsIcon = Icons.card_giftcard_rounded;

    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    // ✅ máximo alto del modal, restando teclado si existe
    final maxH = (screenH * 0.82).clamp(260.0, screenH - 48);
    final effectiveH = (maxH - (viewInsetsBottom > 0 ? viewInsetsBottom * 0.2 : 0))
        .clamp(260.0, maxH);

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
              border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 26,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: SizedBox(
              height: effectiveH, // ✅ acota SIEMPRE
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // HEADER
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.26),
                              width: 1,
                            ),
                          ),
                          child: const Icon(benefitsIcon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Beneficios • Bubble Splash',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white.withOpacity(0.95),
                          splashRadius: 22,
                        ),
                      ],
                    ),
                  ),

                  // BODY (SCROLL)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.stars_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      highlight,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Acción irreversible',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFF0F3D4A)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Una vez canjeado, el beneficio quedará marcado como usado.',
                                    style: TextStyle(
                                      color: Color(0xFF374151),
                                      fontSize: 12.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),

                  // ACTIONS
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
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
                                  padding: const EdgeInsets.symmetric(vertical: 13),
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
      ),
    );
  }
}