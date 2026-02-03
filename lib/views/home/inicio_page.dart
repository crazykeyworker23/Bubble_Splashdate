// ignore_for_file: unused_import, prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:bubblesplash/widgets/custom_appbar.dart';
import 'package:bubblesplash/services/session_manager.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';

import 'CartPage.dart';

/// ✅ Cache manager más agresivo (mejor carga + menos re-descargas)
final CacheManager kBannerCacheManager = CacheManager(
  Config(
    'bubblesplash_banner_cache_v1',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 250,
    repo: JsonCacheInfoRepository(databaseName: 'bubblesplash_banner_cache_v1'),
    fileService: HttpFileService(),
  ),
);

/// ===============================
/// BUBBLE ANIMATION (multi-color premium)
/// ===============================
/// 
/// 
class _BubbleRefreshOverlay extends StatefulWidget {
  final bool visible;
  const _BubbleRefreshOverlay({required this.visible});

  @override
  State<_BubbleRefreshOverlay> createState() => _BubbleRefreshOverlayState();
}

class _BubbleRefreshOverlayState extends State<_BubbleRefreshOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_BubbleData> _bubbles;

  // 🎨 Colores Splash Bubble
  static const List<Color> _palette = [
    Color(0xFF22D3EE), // celeste
    Color(0xFF34D399), // verde
    Color(0xFFFFA94D), // anaranjado
  ];

  // ✅ “Filas” (columnas)
  static const int _rows = 9;

  // ✅ cuántas burbujas por fila (más = más visible/denso)
  static const int _perRow = 9;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    final total = _rows * _perRow;
    _bubbles = List.generate(
      total,
      (i) => _BubbleData.fromRow(i, _rows, _perRow, _palette),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = _controller.value;

            return Stack(
              children: _bubbles.map((b) {
                final progress = (t + b.offset) % 1.0;

                // ✅ Desde abajo -> arriba (pantalla completa)
                final startY = size.height + 90; // más abajo para que “nazcan” claro
                final endY = -b.radius - 90;     // salen arriba
                final dy = lerpDouble(
                  startY,
                  endY,
                  (progress * b.speed).clamp(0.0, 1.0),
                )!;

                // ✅ x fijo por fila
                final dx = (b.x * size.width)
                    .clamp(10.0, size.width - 10.0);

                // ✅ Opacidad más alta (que se noten)
                final fade = (1.0 - progress).clamp(0.0, 1.0);
                final opacity = (fade * 0.85).clamp(0.20, 0.85); // mínimo 0.20

                return Positioned(
                  left: dx - b.radius / 2,
                  top: dy,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: b.radius,
                      height: b.radius,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        // ✅ Relleno más marcado
                        color: b.color.withOpacity(0.30),

                        // ✅ Borde más fuerte y más grueso
                        border: Border.all(
                          color: b.color.withOpacity(0.65),
                          width: 1.8,
                        ),

                        // ✅ Glow intenso + halo
                        boxShadow: [
                          BoxShadow(
                            color: b.color.withOpacity(0.45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.18),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _BubbleData {
  final double x; // centro de fila (0..1)
  final double radius;
  final double speed;
  final double offset;
  final Color color;

  _BubbleData(this.x, this.radius, this.speed, this.offset, this.color);

  factory _BubbleData.fromRow(
    int index,
    int rows,
    int perRow,
    List<Color> palette,
  ) {
    final row = index % rows;          // fila/columna
    final layer = index ~/ rows;       // 0..perRow-1

    final spacing = 1.0 / rows;

    // ✅ centro exacto de la fila + pequeña variación por layer (no se enciman)
    final baseX = spacing * row + spacing / 2;
    final jitter = (layer - (perRow - 1) / 2) * (spacing * 0.18);
    final x = (baseX + jitter).clamp(0.06, 0.94);

    // ✅ color fijo por fila (bonito)
    final color = palette[row % palette.length];

    // ✅ tamaños MÁS GRANDES para que se noten
    final radius = 26.0 + (layer * 10.0); // 26, 36, 46

    // ✅ velocidad con variación ligera
    final speed = 0.85 + (layer * 0.18);

    // ✅ offsets para que no salgan todas juntas
    final offset = layer * 0.28;

    return _BubbleData(x, radius, speed, offset, color);
  }
}



class _HomeBanner {
  final int id;
  final String status;
  final String title;
  final String subtitle;
  final String imageUrl;

  const _HomeBanner({
    required this.id,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  factory _HomeBanner.fromJson(Map<String, dynamic> json) {
    return _HomeBanner(
      id: (json['ban_int_id'] ?? 0) is int
          ? json['ban_int_id'] as int
          : int.tryParse((json['ban_int_id'] ?? '0').toString()) ?? 0,
      status: (json['txt_status'] ?? '').toString(),
      title: (json['ban_txt_title'] ?? '').toString(),
      subtitle: (json['ban_txt_subtitle'] ?? '').toString(),
      imageUrl: (json['ban_txt_imageurl'] ?? '').toString(),
    );
  }
}

class InicioPage extends StatefulWidget {
  final void Function(int)? onTabChange; // opcional si usas bottom tabs
  const InicioPage({super.key, this.onTabChange});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  String _displayName = '';
  bool _isLoadingHome = false;
  String? _homeError;
  List<_HomeBanner> _banners = [];

  int _cartCount = 0;

  // =============================
  //  FAB DRAGGABLE + PERSISTENTE
  // =============================
  static const String _fabXFracKey = 'inicio_cart_fab_x_frac';
  static const String _fabYFracKey = 'inicio_cart_fab_y_frac';

  double? _fabXFrac;
  double? _fabYFrac;
  Offset? _fabOffset;

  Offset? _fabDragStartGlobal;
  Offset? _fabDragStartOffset;

  bool _isDraggingFab = false;
  bool _didDragFab = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadHomeData();
    _loadCartCount();
    _loadFabPosition();
  }

  // =============================
  // CARRITO (prefs cart_pedidos)
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

  Future<void> _loadCartCount() async {
    final pedidos = await _loadCartFromPrefs();
    if (!mounted) return;

    final count = pedidos.fold<int>(0, (sum, e) {
      final q = int.tryParse((e['quantity'] ?? 1).toString()) ?? 1;
      return sum + (q <= 0 ? 1 : q);
    });

    setState(() => _cartCount = count);
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
  // ✅ FAB POSICIÓN (load/save)
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

    final snappedX = (current.dx - minX) <= (maxX - current.dx) ? minX : maxX;
    final snappedY = current.dy.clamp(minY, maxY);

    final xRange = (maxX - minX).abs() < 0.001 ? 1 : (maxX - minX);
    final yRange = (maxY - minY).abs() < 0.001 ? 1 : (maxY - minY);
    final xFrac = ((snappedX - minX) / xRange).clamp(0.0, 1.0);
    final yFrac = ((snappedY - minY) / yRange).clamp(0.0, 1.0);

    setState(() {
      _fabOffset = Offset(snappedX, snappedY);
      _fabXFrac = xFrac;
      _fabYFrac = yFrac;
    });

    _saveFabPosition(xFrac: xFrac, yFrac: yFrac);
  }

  Widget _buildCartFab({required int count}) {
    return FloatingActionButton(
      heroTag: 'inicio_cart_fab',
      backgroundColor: const Color.fromARGB(255, 27, 111, 129),
      onPressed: () {
        if (_isDraggingFab || _didDragFab) return;
        _openCart();
      },
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
  // USER
  // =============================
  Future<void> _loadUserName() async {
    final fullName = await SessionManager.getFullName();
    if (!mounted) return;

    setState(() {
      _displayName = (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : 'Usuario';
    });
  }

  // =============================
  // HOME DATA
  // =============================
  Future<void> _loadHomeData() async {
    setState(() {
      _isLoadingHome = true;
      _homeError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _homeError = 'No hay access token. Inicia sesión nuevamente.';
        });
        return;
      }

      final token = rawToken.trim();
      final uri = BackendConfig.api('bubblesplash/home/');

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
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final List<dynamic> bannersJson =
            (data['banners'] as List<dynamic>?) ?? <dynamic>[];

        final banners = bannersJson
            .whereType<Map<String, dynamic>>()
            .map(_HomeBanner.fromJson)
            .where((b) => b.status.toUpperCase() == 'ACTIVO')
            .toList();

        setState(() => _banners = banners);

        // ✅ Precache + prefetch (carga más rápida) usando TU cacheManager
        for (final b in banners) {
          final u = b.imageUrl.trim();
          if (u.startsWith('http')) {
            precacheImage(
              CachedNetworkImageProvider(u, cacheManager: kBannerCacheManager),
              context,
            );
            unawaited(kBannerCacheManager.downloadFile(u));
          }
        }
      } else if (response.statusCode == 401) {
        setState(
            () => _homeError = 'Sesión expirada. Inicia sesión nuevamente.');
      } else {
        setState(() => _homeError =
            'Error cargando home (${response.statusCode}). Intenta nuevamente.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _homeError = 'Ocurrió un error cargando home: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingHome = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7FB);

    Future<void> _refreshAll() async {
      await _loadUserName();
      await _loadHomeData();
      await _loadCartCount();
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: CustomAppBar(title: 'SPLASH BUBBLE', subtitle: _displayName),
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
              final double xRange =
                  (maxX - minX).abs() < 0.001 ? 0 : (maxX - minX);
              final double yRange =
                  (maxY - minY).abs() < 0.001 ? 0 : (maxY - minY);
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
                setState(() => _fabOffset = Offset(resolvedX, resolvedY));
              });
            }

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: CustomScrollView(
                    key: const PageStorageKey<String>('inicio_page_scroll'),
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      // ✅ Hero premium (SIN carrito)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _PremiumHeroWelcome(name: _displayName),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      if (_homeError != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _ErrorCard(text: _homeError!),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 18)),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _SectionHeader(
                            title: "Destacados",
                            subtitle: "Promos y novedades premium",
                            trailing: _SmallTag(
                              text: _banners.isEmpty
                                  ? "0"
                                  : "${_banners.length} disponibles",
                            ),
                          ),
                        ),
                      ),

                      if (_isLoadingHome && _banners.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (_banners.isEmpty && _homeError == null)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(
                              child: Text(
                                'No hay banners disponibles en este momento.',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _PremiumBannerCarousel(
                              key: ValueKey(_banners.length),
                              banners: _banners,
                              onOpenGallery: (initialIndex) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _BannerFullScreenPage(
                                      banners: _banners,
                                      initialIndex: initialIndex,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _SectionHeader(
                            title: "Novedades",
                            subtitle: "Lo último para ti",
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _banners.isEmpty
                              ? const _EmptySoftCard(
                                  text:
                                      "Aún no hay novedades. Vuelve en unos minutos ✨",
                                )
                              : Column(
                                  children: _banners.take(3).map((b) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _PromoListTile(
                                        banner: b,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _BannerFullScreenPage(
                                                banners: _banners,
                                                initialIndex:
                                                    _banners.indexOf(b),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
                ),

                // Overlay de burbujas durante el refresco (cubre todo)
                _BubbleRefreshOverlay(visible: _isLoadingHome),

                // ✅ FAB DRAGGABLE (carrito solo aquí)
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
                        _didDragFab = false;
                        _fabDragStartGlobal = details.globalPosition;
                        _fabDragStartOffset = Offset(resolvedX, resolvedY);
                      });
                    },
                    onPanUpdate: (details) {
                      final startGlobal = _fabDragStartGlobal;
                      final startOffset = _fabDragStartOffset;
                      if (startGlobal == null || startOffset == null) return;

                      final delta = details.globalPosition - startGlobal;
                      if (!_didDragFab && delta.distance > 3) _didDragFab = true;

                      final newX =
                          (startOffset.dx + delta.dx).clamp(minX, maxX);
                      final newY =
                          (startOffset.dy + delta.dy).clamp(minY, maxY);

                      setState(() => _fabOffset = Offset(newX, newY));
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

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _didDragFab = false);
                      });
                    },
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 120),
                      scale: _isDraggingFab ? 1.06 : 1.0,
                      child: _buildCartFab(count: _cartCount),
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
/// PREMIUM UI WIDGETS
/// ===============================
class _PremiumHeroWelcome extends StatelessWidget {
  final String name;
  const _PremiumHeroWelcome({required this.name});

  @override
  Widget build(BuildContext context) {
    const c1 = Color(0xFF0F3D4A);
    const c2 = Color(0xFF128FA0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.local_drink_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hola, $name 👋",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Hoy es un buen día para tu  Splash Bubble",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F3E47),
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String text;
  const _SmallTag({required this.text});

  @override
  Widget build(BuildContext context) {
    const c2 = Color(0xFF128FA0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c2.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c2.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: c2,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySoftCard extends StatelessWidget {
  final String text;
  const _EmptySoftCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// ===============================
/// CARRUSEL PREMIUM (AUTO + FULLSCREEN)
/// ===============================
class _PremiumBannerCarousel extends StatefulWidget {
  final List<_HomeBanner> banners;
  final void Function(int initialIndex) onOpenGallery;

  const _PremiumBannerCarousel({
    super.key,
    required this.banners,
    required this.onOpenGallery,
  });

  @override
  State<_PremiumBannerCarousel> createState() => _PremiumBannerCarouselState();
}

class _PremiumBannerCarouselState extends State<_PremiumBannerCarousel> {
  late final PageController _controller;
  double _page = 0.0;

  int _index = 0;
  bool _userInteracting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);

    _controller.addListener(() {
      final p = _controller.page ?? 0.0;
      if (!mounted) return;
      setState(() => _page = p);
      _index = p.round().clamp(0, (widget.banners.length - 1).clamp(0, 9999));
    });

    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_userInteracting) return;

      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _pauseTemporarily() {
    _userInteracting = true;
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _userInteracting = false;
    });
  }

  @override
  void didUpdateWidget(covariant _PremiumBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return Column(
      children: [
        SizedBox(
          height: 340,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) _pauseTemporarily();
              if (n is UserScrollNotification) _pauseTemporarily();
              return false;
            },
            child: GestureDetector(
              onPanDown: (_) => _pauseTemporarily(),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.banners.length,
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  final diff = (_page - index).abs();
                  final scale = (1 - (diff * 0.06)).clamp(0.90, 1.0);
                  final opacity = (1 - (diff * 0.25)).clamp(0.55, 1.0);

                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _PremiumBannerCard(
                          banner: banner,
                          onOpenGallery: () => widget.onOpenGallery(index),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (i) {
            final selected = (_page.round() == i);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: selected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? primary : Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PremiumBannerCard extends StatelessWidget {
  final _HomeBanner banner;
  final VoidCallback onOpenGallery;

  const _PremiumBannerCard({
    required this.banner,
    required this.onOpenGallery,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenGallery,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NetworkImagePremium(url: banner.imageUrl, showFull: true),

            // overlay suave
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.22),
                      Colors.black.withOpacity(0.78),
                    ],
                    stops: const [0.0, 0.60, 1.0],
                  ),
                ),
              ),
            ),

            // ✅ texto con scroll
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.title.isNotEmpty ? banner.title : "Promoción especial",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner.subtitle.isNotEmpty
                            ? banner.subtitle
                            : "Descubre lo nuevo en Splash Bubble",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.open_in_full_rounded,
                              size: 16, color: Colors.white.withOpacity(0.9)),
                          const SizedBox(width: 6),
                          Text(
                            "Toca para ampliar",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.90),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
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
    );
  }
}

/// Lista premium (reutiliza banners como “novedades”)
class _PromoListTile extends StatelessWidget {
  final _HomeBanner banner;
  final VoidCallback onTap;
  const _PromoListTile({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
              child: SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _NetworkImagePremium(
                      url: banner.imageUrl,
                      small: true,
                      showFull: false,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.06),
                            Colors.black.withOpacity(0.35),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.title.isNotEmpty ? banner.title : "Novedad",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      banner.subtitle.isNotEmpty ? banner.subtitle : "Toca para ver",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
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
}

/// ===============================
/// FULLSCREEN GALLERY (swipe + zoom + TEXTO COMPLETO)
/// ===============================
class _BannerFullScreenPage extends StatefulWidget {
  final List<_HomeBanner> banners;
  final int initialIndex;

  const _BannerFullScreenPage({required this.banners, this.initialIndex = 0});

  @override
  State<_BannerFullScreenPage> createState() => _BannerFullScreenPageState();
}

class _BannerFullScreenPageState extends State<_BannerFullScreenPage> {
  late final PageController _controller;
  late int _i;

  @override
  void initState() {
    super.initState();
    _i = widget.initialIndex.clamp(
      0,
      (widget.banners.length - 1).clamp(0, 9999),
    );
    _controller = PageController(initialPage: _i);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "${_i + 1}/${widget.banners.length}",
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.banners.length,
        onPageChanged: (v) => setState(() => _i = v),
        itemBuilder: (_, index) {
          final b = widget.banners[index];

          return Stack(
            children: [
              // ✅ imagen (zoom)
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: _NetworkImagePremium(
                    url: b.imageUrl,
                    showFull: true,
                    small: false,
                  ),
                ),
              ),

              // ✅ panel premium con texto completo (scroll)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title.isNotEmpty ? b.title : "Promoción",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            b.subtitle.isNotEmpty
                                ? b.subtitle
                                : "Novedades de Splash Bubble",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ===============================
/// NETWORK IMAGE PREMIUM (cache + base64 + full view)
/// ===============================
class _NetworkImagePremium extends StatelessWidget {
  final String url;
  final bool small;

  /// true = imagen completa (contain) + fondo blur premium
  /// false = cover rápido (para thumbnails)
  final bool showFull;

  const _NetworkImagePremium({
    required this.url,
    this.small = false,
    this.showFull = true,
  });

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    final placeholder = _SoftShimmerPlaceholder(small: small);

    if (u.isEmpty) return placeholder;

    final base64RegExp = RegExp(
      r'^(data:image\/[^;]+;base64,)?([A-Za-z0-9+\/\r\n]+={0,2})',
    );

    ImageProvider provider;
    if (base64RegExp.hasMatch(u) && u.length > 100) {
      try {
        final base64Str = u.contains(',') ? u.split(',').last : u;
        final bytes = base64Decode(base64Str);
        provider = MemoryImage(bytes);
      } catch (_) {
        return placeholder;
      }
    } else {
      provider = CachedNetworkImageProvider(
        u,
        cacheManager: kBannerCacheManager,
      );
    }

    if (showFull) {
      // ✅ imagen completa con blur premium detrás
      return Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: provider,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.black.withOpacity(0.16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      );
    }

    if (!u.startsWith('http')) return placeholder;

    return CachedNetworkImage(
      imageUrl: u,
      cacheManager: kBannerCacheManager,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 80),
      fadeOutDuration: Duration.zero,
      memCacheWidth: small ? 420 : 1200,
      memCacheHeight: small ? 420 : 800,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFE9EEF0),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_rounded,
          color: Colors.black38,
          size: 42,
        ),
      ),
    );
  }
}

/// ✅ placeholder premium sin dependencias extra (rápido)
class _SoftShimmerPlaceholder extends StatefulWidget {
  final bool small;
  const _SoftShimmerPlaceholder({required this.small});

  @override
  State<_SoftShimmerPlaceholder> createState() => _SoftShimmerPlaceholderState();
}

class _SoftShimmerPlaceholderState extends State<_SoftShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFE9EEF0),
          ),
          child: CustomPaint(
            painter: _ShimmerPainter(t),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double t;
  _ShimmerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final base = const Color(0xFFE9EEF0);
    final hi = Colors.white.withOpacity(0.55);

    final dx = (t * (size.width + 120)) - 120;
    final rect = Rect.fromLTWH(dx, 0, 120, size.height);

    paint.shader = LinearGradient(
      colors: [base, hi, base],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);

    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.t != t;
}
