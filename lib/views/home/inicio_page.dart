// ignore_for_file: unused_import, prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:bubblesplash/widgets/custom_appbar.dart';
import 'package:bubblesplash/services/session_manager.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/routes/app_routes.dart';
import 'package:bubblesplash/widgets/connection_error_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bubblesplash/widgets/canjear_puntos_page.dart';

import 'CartPage.dart';

/// Carrusel horizontal con imágenes circulares (para Marcas Aliadas)
class _HorizontalCarouselMarcasAliadas extends StatefulWidget {
  const _HorizontalCarouselMarcasAliadas();

  @override
  State<_HorizontalCarouselMarcasAliadas> createState() => _HorizontalCarouselMarcasAliadasState();
}

class _HorizontalCarouselMarcasAliadasState extends State<_HorizontalCarouselMarcasAliadas> {
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _isUserScrolling = false;

  static const List<Map<String, String>> _baseItems = [
    {'asset': 'assets/fimo.png', 'label': 'Fimo'},
    {'asset': 'assets/bubble.png', 'label': 'Splash Bubble'},
    {'asset': 'assets/dateanddo.png', 'label': 'Date & Do'},
    {'asset': 'assets/finhold.png', 'label': 'Finhold'},
    {'asset': 'assets/fintbot.jpg', 'label': 'Fintbot'},
    {'asset': 'assets/fintour.jpg', 'label': 'Fintour'},
    {'asset': 'assets/alini.jpg', 'label': 'Alini'},
    {'asset': 'assets/fintpay.jpg', 'label': 'Fintpay'},
    {'asset': 'assets/loggia.png', 'label': 'Loggia'},
    {'asset': 'assets/losthorde.jpg', 'label': 'Lost Horde'},
    {'asset': 'assets/pasa.jpeg', 'label': 'Pasa'},
    {'asset': 'assets/ttvfinared.jpg', 'label': 'TV Finared'},
    {'asset': 'assets/xambio.png', 'label': 'Xambio'},
  ];
  late final List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    // Duplicar los ítems para simular infinito
    _items = List.generate(100, (i) => _baseItems[i % _baseItems.length]);
    _scrollController = ScrollController(initialScrollOffset: _baseItems.length * 80.0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _isUserScrolling) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final minScroll = 0.0;
      final currentScroll = _scrollController.position.pixels;
      final middle = (_items.length / 2) * 80.0;

      if (currentScroll >= maxScroll - 10) {
        _scrollController.jumpTo(middle);
      } else if (currentScroll <= minScroll + 10) {
        _scrollController.jumpTo(middle);
      } else {
        _scrollController.animateTo(
          currentScroll + 1,
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _isUserScrolling = true;
        } else if (notification is ScrollEndNotification) {
          _isUserScrolling = false;
          _startAutoScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 8,
              right: index == _items.length - 1 ? 16 : 8,
            ),
            child: _LocalCircularImage(
              assetPath: item['asset']!,
              label: item['label']!,
            ),
          );
        },
      ),
    );
  }
}
/// Imagen circular local para Marcas Aliadas
class _LocalCircularImage extends StatelessWidget {
  final String assetPath;
  final String label;
  const _LocalCircularImage({
    required this.assetPath,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipOval(
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.black38,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF111827),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

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
  static const String _bannersCacheKey = 'home_banners_cache_v1';
  String _displayName = '';
  bool _isLoadingHome = false;
  String? _homeError;
  List<_HomeBanner> _banners = [];

  int _cartCount = 0;

  // =============================
  // ✅ FAB DRAGGABLE + PERSISTENTE
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
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_bannersCacheKey);

    if (cached != null && cached.trim().isNotEmpty) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(cached) as Map<String, dynamic>;
        final List<dynamic> bannersJson =
            (data['banners'] as List<dynamic>?) ?? <dynamic>[];
        final banners = bannersJson
            .whereType<Map<String, dynamic>>()
            .map(_HomeBanner.fromJson)
            .where((b) => b.status.toUpperCase() == 'ACTIVO')
            .toList();

        if (mounted) {
          setState(() {
            _banners = banners;
            _homeError = null;
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error al cargar banners desde caché: $e');
      }
    }

    if (_banners.isEmpty) {
      setState(() {
        _isLoadingHome = true;
        _homeError = null;
      });
    }

    try {
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        // Si por algún motivo llegamos aquí sin token, aseguramos
        // marcar la sesión como cerrada y redirigir al login.
        await prefs.setBool('isLoggedIn', false);

        if (!mounted) return;
        setState(() {
          _homeError = 'No hay access token. Inicia sesión nuevamente.';
        });

        // Navegamos al login limpiando la ruta actual, para evitar
        // que el usuario se quede en un estado inconsistente.
        Navigator.pushReplacementNamed(context, AppRoutes.login);
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

        await prefs.setString(_bannersCacheKey, response.body);

        setState(() {
          _banners = banners;
          _homeError = null;
        });

        // ✅ Precache + prefetch (carga más rápida)
        for (final b in banners) {
          final u = b.imageUrl.trim();
          if (u.startsWith('http')) {
            precacheImage(CachedNetworkImageProvider(u), context);
            unawaited(kBannerCacheManager.downloadFile(u));
          }
        }
      } else if (response.statusCode == 401) {
        setState(
          () => _homeError = 'Sesión expirada. Inicia sesión nuevamente.',
        );
      } else {
        if (_banners.isEmpty) {
          setState(
            () => _homeError =
                'Error cargando home (${response.statusCode}). Intenta nuevamente.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('clientexception') ||
          errStr.contains('handshake') ||
          errStr.contains('network') ||
          errStr.contains('connection')) {
        if (_banners.isEmpty) {
          setState(() {
            _homeError =
                'No se pudo conectar con el servidor. Por favor, comprueba tu conexión a Internet e intenta nuevamente.';
          });
        }
        if (mounted) {
          showConnectionErrorDialog(context, onRetry: _refreshAll);
        }
      } else {
        if (_banners.isEmpty) {
          setState(() => _homeError = 'Ocurrió un error cargando home: $e');
        }
      }
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingHome = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadUserName();
    await _loadHomeData();
    await _loadCartCount();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F7FB);

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

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _QuickActionsRow(onTabChange: widget.onTabChange),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: _buildInviteCard(context),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      if (_homeError != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _ErrorCard(
                              text: _homeError!,
                              onRetry: _refreshAll,
                            ),
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
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

                      // Duplicado: Otra sección similar a Novedades
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _SectionHeader(
                            title: "Marcas Aliadas",
                            subtitle: "Empresas que confían",
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 130,
                          child: _HorizontalCarouselMarcasAliadas(),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _SectionHeader(
                            title: "Novedades",
                            subtitle: "Lo nuevo para ti",
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 155,
                          child: _HorizontalCarouselNovedades(),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
                ),

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
                      if (!_didDragFab && delta.distance > 3)
                        _didDragFab = true;

                      final newX = (startOffset.dx + delta.dx).clamp(
                        minX,
                        maxX,
                      );
                      final newY = (startOffset.dy + delta.dy).clamp(
                        minY,
                        maxY,
                      );

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

  Widget _buildInviteCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EEF5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B6F81).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF1B6F81),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Comparte Beneficios",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F3E47),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Tus amigos obtienen puntos de regalo",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Comparte el enlace con tus amigos. Al descargar la app, podrán ganar puntos de regalo ingresando el código de invitación que encontrarán en los banners de novedades.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: '¡Hola! Te invito a descargar Splash Bubble para disfrutar de las mejores bebidas. Al registrarte, busca el código promocional en los banners de novedades para obtener tus primeros puntos de regalo. Descarga la app aquí: https://play.google.com/store/apps/details?id=com.finatech.bubblesplash',
                        subject: '¡Descarga Splash Bubble!',
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1B6F81), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF1B6F81)),
                  label: const Text(
                    "Compartir Enlace",
                    style: TextStyle(color: Color(0xFF1B6F81), fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CanjearPuntosPage()),
                    ).then((_) {
                      _refreshAll();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6F81),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.confirmation_num_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    "Ingresar Código",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ],
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

class _QuickActionsRow extends StatelessWidget {
  final void Function(int)? onTabChange;

  const _QuickActionsRow({this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionItem(
            context: context,
            icon: Icons.local_drink_rounded,
            label: 'Ver Menú',
            color: const Color(0xFF1B6F81),
            onTap: () {
              if (onTabChange != null) {
                onTabChange!(2); // Pestaña de menú (index 2)
              }
            },
          ),
          _buildActionItem(
            context: context,
            icon: Icons.card_giftcard_rounded,
            label: 'Cupones',
            color: const Color(0xFF1B6F81),
            onTap: () {
              if (onTabChange != null) {
                onTabChange!(3); // Pestaña de beneficios (index 3)
              }
            },
          ),
          // _buildActionItem(
          //   context: context,
          //   icon: Icons.qr_code_scanner_rounded,
          //   label: 'Escanear QR',
          //   color: Colors.grey.shade400,
          //   isLocked: true,
          //   onTap: () => _showComingSoon(context, 'Escanear QR'),
          // ),
          // _buildActionItem(
          //   context: context,
          //   icon: Icons.account_balance_wallet_rounded,
          //   label: 'Recargar',
          //   color: Colors.grey.shade400,
          //   isLocked: true,
          //   onTap: () => _showComingSoon(context, 'Recargar'),
          // ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey.shade100 : color.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLocked ? Colors.grey.shade200 : color.withOpacity(0.15),
                  width: 1.2,
                ),
              ),
              child: Icon(
                icon,
                color: isLocked ? Colors.grey.shade500 : color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isLocked ? Colors.grey.shade500 : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // void _showComingSoon(BuildContext context, String featureName) {
  //   ScaffoldMessenger.of(context).clearSnackBars();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Row(
  //         children: [
  //           const Icon(Icons.info_outline, color: Colors.white),
  //           const SizedBox(width: 8),
  //           Text(
  //             '¡$featureName estará disponible próximamente!',
  //             style: const TextStyle(fontWeight: FontWeight.w700),
  //           ),
  //         ],
  //       ),
  //       backgroundColor: const Color(0xFF1B6F81),
  //       behavior: SnackBarBehavior.floating,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       duration: const Duration(seconds: 2),
  //     ),
  //   );
  // }
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
  final VoidCallback? onRetry;
  const _ErrorCard({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isSessionOrNetworkError = text.toLowerCase().contains('sesión') || 
                                    text.toLowerCase().contains('token') ||
                                    text.toLowerCase().contains('401') ||
                                    text.toLowerCase().contains('unauthorized') ||
                                    text.toLowerCase().contains('conexión') ||
                                    text.toLowerCase().contains('internet') ||
                                    text.toLowerCase().contains('servidor');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (isSessionOrNetworkError || onRetry != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onRetry != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Reintentar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B6F81),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 1,
                        ),
                      ),
                    ),
                  ),
                if (isSessionOrNetworkError)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await SessionManager.forceLogout();
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
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

  int _index = 0;
  bool _userInteracting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);

    _controller.addListener(() {
      if (_controller.hasClients && _controller.position.hasContentDimensions) {
        final p = _controller.page ?? 0.0;
        _index = p.round().clamp(0, (widget.banners.length - 1).clamp(0, 9999));
      }
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

                  return _KeepAliveWrapper(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _PremiumBannerCard(
                        banner: banner,
                        onOpenGallery: () => widget.onOpenGallery(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            double page = 0.0;
            if (_controller.hasClients && _controller.position.hasContentDimensions) {
              page = _controller.page ?? 0.0;
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.banners.length, (i) {
                final selected = (page.round() == i);
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
            );
          },
        ),
      ],
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class _PremiumBannerCard extends StatelessWidget {
  final _HomeBanner banner;
  final VoidCallback onOpenGallery;

  const _PremiumBannerCard({required this.banner, required this.onOpenGallery});

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
                      banner.subtitle.isNotEmpty
                          ? banner.subtitle
                          : "Toca para ver",
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

/// ✅ Thumbnail circular pequeño para novedades
class _CircularBannerThumbnail extends StatelessWidget {
  final _HomeBanner banner;
  final VoidCallback onTap;
  const _CircularBannerThumbnail({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipOval(
                  child: _NetworkImagePremium(
                    url: banner.imageUrl,
                    small: true,
                    showFull: false,
                  ),
                ),
                ClipOval(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.30),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 90,
            child: Text(
              banner.title.isNotEmpty ? banner.title : "Novedad",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF111827),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ Carrusel horizontal con desplazamiento automático lento
class _HorizontalCarouselNovedades extends StatefulWidget {
  const _HorizontalCarouselNovedades();

  @override
  State<_HorizontalCarouselNovedades> createState() =>
      _HorizontalCarouselNovedadesState();
}

class _HorizontalCarouselNovedadesState
    extends State<_HorizontalCarouselNovedades> {
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _isUserScrolling = false;

  static const List<Map<String, String>> _baseItems = [
    {'asset': 'assets/fimos.jpg', 'label': 'Fimo'},
    {'asset': 'assets/bubble.png', 'label': 'Splash Bubble'},

  ];
  late final List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    // Duplicar los ítems para simular infinito
    _items = List.generate(100, (i) => _baseItems[i % _baseItems.length]);
    _scrollController = ScrollController(initialScrollOffset: _baseItems.length * 110.0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _isUserScrolling) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final minScroll = 0.0;
      final currentScroll = _scrollController.position.pixels;
      final middle = (_items.length / 2) * 110.0;

      if (currentScroll >= maxScroll - 10) {
        _scrollController.jumpTo(middle);
      } else if (currentScroll <= minScroll + 10) {
        _scrollController.jumpTo(middle);
      } else {
        _scrollController.animateTo(
          currentScroll + 1,
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _isUserScrolling = true;
        } else if (notification is ScrollEndNotification) {
          _isUserScrolling = false;
          _startAutoScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 8,
              right: index == _items.length - 1 ? 16 : 8,
            ),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            item['asset']!,
                            fit: BoxFit.contain,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 32),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: _RectangularNovedadImage(
                assetPath: item['asset']!,
                label: item['label']!,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ✅ Imagen rectangular local para novedades
class _RectangularNovedadImage extends StatelessWidget {
  final String assetPath;
  final String label;
  const _RectangularNovedadImage({
    required this.assetPath,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.black38,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF111827),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

/// ===============================
/// THUMBNAIL CIRCULAR PEQUEÑO PARA NOVEDADES (no usado)
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

    // Detectar si realmente es base64 y no un URL largo de red
    final bool isBase64 = u.startsWith('data:image') ||
        (!u.startsWith('http') && !u.startsWith('/') && !u.startsWith('assets/') && u.length > 100);

    ImageProvider provider;
    if (isBase64) {
      try {
        final base64Str = u.contains(',') ? u.split(',').last : u;
        final bytes = base64Decode(base64Str.replaceAll('\n', '').replaceAll('\r', '').trim());
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
      if (isBase64) {
        // Para imágenes en memoria (base64) no hay tiempo de red
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

      // Para red, cargamos con CachedNetworkImage para tener shimmer de carga
      return CachedNetworkImage(
        imageUrl: u,
        cacheManager: kBannerCacheManager,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        memCacheWidth: small ? 420 : 1000,
        memCacheHeight: small ? 420 : 600,
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
        imageBuilder: (context, imageProvider) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: imageProvider,
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
                  image: imageProvider,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          );
        },
      );
    }

    if (!u.startsWith('http')) return placeholder;

    return CachedNetworkImage(
      imageUrl: u,
      cacheManager: kBannerCacheManager,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
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
  State<_SoftShimmerPlaceholder> createState() =>
      _SoftShimmerPlaceholderState();
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
          decoration: const BoxDecoration(color: Color(0xFFE9EEF0)),
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
