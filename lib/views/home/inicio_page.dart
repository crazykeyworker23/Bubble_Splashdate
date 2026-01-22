import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:bubblesplash/widgets/custom_appbar.dart';
import 'package:bubblesplash/services/session_manager.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

/// Mock UI (luego lo conectas a tu API real)
class _MiniProduct {
  final String name;
  final String imageUrl; // puede ser url o vacío
  final double price;
  final String tag;

  const _MiniProduct({
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.tag,
  });
}

class InicioPage extends StatefulWidget {
  final void Function(int)? onTabChange;
  const InicioPage({super.key, this.onTabChange});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  String _displayName = '';
  bool _isLoadingHome = false;
  String? _homeError;
  List<_HomeBanner> _banners = [];

  // Mock data (puedes reemplazar por data real de tu backend)
  final List<_MiniProduct> _recommended = const [
    _MiniProduct(name: "Taro Milk Tea", imageUrl: "", price: 12.90, tag: "Top"),
    _MiniProduct(name: "Brown Sugar", imageUrl: "", price: 13.50, tag: "Nuevo"),
    _MiniProduct(name: "Matcha Latte", imageUrl: "", price: 14.00, tag: "Premium"),
    _MiniProduct(name: "Fruit Tea Mango", imageUrl: "", price: 11.90, tag: "Fresh"),
  ];

  final List<String> _popularCategories = const [
    "Bubble Tea",
    "Fruit Tea",
    "Frappé",
    "Coffee",
    "Toppings",
    "Ofertas",
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadHomeData();
  }

  Future<void> _loadUserName() async {
    final fullName = await SessionManager.getFullName();
    if (!mounted) return;

    setState(() {
      if (fullName != null && fullName.trim().isNotEmpty) {
        _displayName = fullName.trim();
      } else {
        _displayName = 'Usuario';
      }
    });
  }

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
          _isLoadingHome = false;
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
        final refreshedPrefs = await SharedPreferences.getInstance();
        final newToken = refreshedPrefs.getString('access_token')?.trim();
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

        setState(() {
          _banners = banners;
          _isLoadingHome = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _isLoadingHome = false;
          _homeError =
              'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.';
        });
      } else {
        setState(() {
          _isLoadingHome = false;
          _homeError =
              'Error al cargar información de inicio (${response.statusCode}).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHome = false;
        _homeError = 'Error al cargar información de inicio: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      appBar: CustomAppBar(title: 'BUBBLE SPLASH', subtitle: _displayName),
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
          key: const PageStorageKey<String>('inicio_page_scroll'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            if (_homeError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _homeError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            if (_isLoadingHome && _banners.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_banners.isEmpty && _homeError == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay banners disponibles en este momento.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: _PremiumBannerCarousel(
                  banners: _banners,
                  onTap: (banner) {
                    // Navegar a detalle de promoción
                    Navigator.pushNamed(
                      context,
                      '/promoDetail',
                      arguments: banner,
                    );
                  },
                ),
              ),

            // ✅ NUEVO: Accesos rápidos
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: "Accesos rápidos",
                subtitle: "Lo que más usas, a un toque",
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _QuickActionsRow(
                  onTapMenu: () {
                    widget.onTabChange?.call(2); // Menú
                  },
                  onTapCart: () {
                    Navigator.pushNamed(context, '/cart');
                  },
                  onTapOrders: () {
                    widget.onTabChange?.call(1); // Pagos
                  },
                  onTapProfile: () {
                    widget.onTabChange?.call(3); // Beneficios
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ✅ NUEVO: banner puntos/beneficios
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RewardsCard(
                  points: 120,
                  subtitle: "Canjea toppings y bebidas con tus puntos",
                  onTap: () {
                    Navigator.pushNamed(context, '/rewards');
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ✅ NUEVO: Categorías populares
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: "Categorías populares",
                subtitle: "Explora por tipo",
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _popularCategories.map((c) {
                    return _CategoryChip(
                      label: c,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/category',
                          arguments: c,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ✅ NUEVO: Recomendados
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: "Recomendados para ti",
                subtitle: "Los más pedidos esta semana",
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 190,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, i) {
                    final p = _recommended[i];
                    return _MiniProductCard(
                      product: p,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/product',
                          arguments: p,
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: _recommended.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ✅ NUEVO: Últimos pedidos (placeholder)
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: "Tus últimos pedidos",
                subtitle: "Estado y repetición rápida",
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LastOrdersCard(
                  onTapViewAll: () {
                    Navigator.pushNamed(context, '/orders');
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 22)),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// UI SECTIONS PREMIUM
/// ===============================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F3E47),
              letterSpacing: 0.3,
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
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onTapMenu;
  final VoidCallback onTapCart;
  final VoidCallback onTapOrders;
  final VoidCallback onTapProfile;

  const _QuickActionsRow({
    required this.onTapMenu,
    required this.onTapCart,
    required this.onTapOrders,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.local_drink_rounded,
            label: "Menú",
            onTap: onTapMenu,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.shopping_cart_rounded,
            label: "Carrito",
            onTap: onTapCart,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.receipt_long_rounded,
            label: "Pedidos",
            onTap: onTapOrders,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.person_rounded,
            label: "Perfil",
            onTap: onTapProfile,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primary),

            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Color(0xFF0F3E47),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsCard extends StatelessWidget {
  final int points;
  final String subtitle;
  final VoidCallback onTap;

  const _RewardsCard({
    required this.points,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              primary.withOpacity(0.95),
              const Color(0xFF134B56).withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 16, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.stars_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$points puntos",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F3E47),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniProductCard extends StatelessWidget {
  final _MiniProduct product;
  final VoidCallback onTap;

  const _MiniProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: product.imageUrl.trim().isEmpty
                  ? Container(
                      color: const Color(0xFFE9EEF0),
                      alignment: Alignment.center,
                      child: const Icon(Icons.local_drink_rounded, size: 44, color: Colors.black38),
                    )
                  : Image.network(product.imageUrl, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.70)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  product.tag,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        "S/. ${product.price.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.90),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastOrdersCard extends StatelessWidget {
  final VoidCallback onTapViewAll;

  const _LastOrdersCard({required this.onTapViewAll});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Últimos pedidos",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF0F3E47),
                  ),
                ),
              ),
              InkWell(
                onTap: onTapViewAll,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primary.withOpacity(0.18)),
                  ),
                  child: const Text(
                    "Ver todo",
                    style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _orderRow(
            title: "Pedido #1201",
            subtitle: "En preparación • 2 productos",
            statusColor: Colors.orange,
          ),
          const SizedBox(height: 10),
          _orderRow(
            title: "Pedido #1188",
            subtitle: "Listo para recoger • 1 producto",
            statusColor: Colors.green,
          ),
          const SizedBox(height: 10),
          _orderRow(
            title: "Pedido #1172",
            subtitle: "Entregado • 3 productos",
            statusColor: Colors.blueGrey,
          ),
        ],
      ),
    );
  }

  Widget _orderRow({
    required String title,
    required String subtitle,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F3E47))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Colors.black45),
      ],
    );
  }
}

/// ===============================
/// CARRUSEL PREMIUM (sin paquetes)
/// ===============================
class _PremiumBannerCarousel extends StatefulWidget {
  final List<_HomeBanner> banners;
  final void Function(_HomeBanner banner) onTap;

  const _PremiumBannerCarousel({
    required this.banners,
    required this.onTap,
  });

  @override
  State<_PremiumBannerCarousel> createState() => _PremiumBannerCarouselState();
}

class _PremiumBannerCarouselState extends State<_PremiumBannerCarousel> {
  late final PageController _controller;
  double _page = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header elegante
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Promociones",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F3E47),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withOpacity(0.18)),
                ),
                child: Text(
                  "${widget.banners.length} disponibles",
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 330,
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
                      onTap: () => widget.onTap(banner),
                    ),
                  ),
                ),
              );
            },
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

        const SizedBox(height: 8),
      ],
    );
  }
}

class _PremiumBannerCard extends StatelessWidget {
  final _HomeBanner banner;
  final VoidCallback onTap;

  const _PremiumBannerCard({
    required this.banner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B6F81);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetworkImagePremium(url: banner.imageUrl),

              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.88),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 14,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bubble_chart_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "BUBBLE SPLASH",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.title.isNotEmpty ? banner.title : "Promoción especial",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        banner.subtitle.isNotEmpty ? banner.subtitle : "Descubre lo nuevo en Bubble Splash",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.90),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                "Ver detalle",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
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

class _NetworkImagePremium extends StatelessWidget {
  final String url;
  const _NetworkImagePremium({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFE9EEF0),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    final u = url.trim();
    if (u.isEmpty) return placeholder;

    // Si tu backend te manda rutas tipo "/media/banner.jpg", descomenta:
    // final fixed = u.startsWith('/') ? 'https://services.fintbot.pe$u' : u;
    final fixed = u;

    return Image.network(
      fixed,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return placeholder;
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error cargando banner: $error');
        debugPrint('URL del banner: $fixed');
        return Container(
          color: const Color(0xFFE9EEF0),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_rounded, color: Colors.black38, size: 42),
        );
      },
    );
  }
}
