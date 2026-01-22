import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'menu_page.dart';

/// ===============================
/// APP BAR PREMIUM (REUTILIZABLE)
/// ===============================
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData icon;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F3D4A),
            Color(0xFF128FA0),
          ],
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
                child: Icon(icon, color: Colors.white, size: 24),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      'Premium',
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

class _BeneficiosPageState extends State<BeneficiosPage> {
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

  // Colores / estilo
  static const Color _bg = Color(0xFFF6F7FB);
  static const Color _textDark = Color(0xFF1F2A37);
  static const Color _textMute = Color(0xFF6B7280);
  static const Color _brand = Color(0xFF128FA0);
  static const Color _brandDeep = Color(0xFF0F3D4A);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _cargarPuntos();
    await _cargarOfertas();
  }

  Future<void> _cargarPuntos() async {
    final prefs = await SharedPreferences.getInstance();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        puntos = 0;
        _actualizarNivelYProgreso();
      });
      return;
    }

    final String keyPuntos = 'puntos_${user.uid}';

    try {
      final rawToken = prefs.getString('access_token');

      // Fallback local si no hay token
      if (rawToken == null || rawToken.trim().isEmpty) {
        final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
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

      // Reintento con refresh si expira
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
            backendPoints = int.tryParse(
                  (pointsObj['upo_int_totalpoints'] ?? '0').toString(),
                ) ??
                0;
          }
        }

        await prefs.setInt(keyPuntos, backendPoints);

        setState(() {
          puntos = backendPoints;
          _actualizarNivelYProgreso();
        });
      } else {
        final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
        setState(() {
          puntos = storedPoints;
          _actualizarNivelYProgreso();
        });
      }
    } catch (_) {
      final int storedPoints = prefs.getInt(keyPuntos) ?? 0;
      setState(() {
        puntos = storedPoints;
        _actualizarNivelYProgreso();
      });
    }
  }

  void _actualizarNivelYProgreso() {
    // Bronce: 0-299 (meta 300)
    // Plata : 300-599 (meta 600)
    // Oro   : 600-999 (meta 1000)
    // Platino: 1000+
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

  Future<void> _cargarOfertas() async {
    setState(() {
      _isLoadingOfertas = true;
      _ofertasError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        setState(() {
          _isLoadingOfertas = false;
          _ofertasError =
              'No hay access token. Inicia sesión nuevamente para ver tus ofertas.';
        });
        return;
      }

      final token = rawToken.trim();
      final uri = BackendConfig.api('bubblesplash/ofertas/disponibles/');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is List) {
          final ofertas = body
              .whereType<Map<String, dynamic>>()
              .where((o) =>
                  (o['txt_status'] ?? '').toString().toUpperCase() == 'ACTIVO')
              .toList();

          setState(() {
            _ofertas = ofertas;
            _isLoadingOfertas = false;
          });
        } else {
          setState(() {
            _isLoadingOfertas = false;
            _ofertasError = 'Formato inesperado de la respuesta de ofertas.';
          });
        }
      } else {
        setState(() {
          _isLoadingOfertas = false;
          _ofertasError = 'Error al cargar ofertas (${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingOfertas = false;
        _ofertasError = 'Error al cargar ofertas: $e';
      });
    }
  }

  Future<void> _onRefresh() async {
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: const CustomAppBar(
        title: 'Ofertas & Recompensas',
        icon: Icons.local_offer,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
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
                      // Glow decorativo
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.18),
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

                            // Card interior
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.16),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Nivel: $nivel',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.16),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '$puntos pts',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
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

              // ======= OFERTAS ESPECIALES (Carrusel)
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

              if (_isLoadingOfertas)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_ofertasError != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    controller: PageController(viewportFraction: 0.92),
                    itemCount: _ofertas.length,
                    itemBuilder: (context, index) {
                      final oferta = _ofertas[index];

                      final String titulo =
                          (oferta['off_txt_title'] ?? 'Oferta especial')
                              .toString();
                      final String descripcion =
                          (oferta['off_txt_description'] ?? '').toString();
                      final int puntosReq = int.tryParse(
                            (oferta['off_int_pointscost'] ?? '0').toString(),
                          ) ??
                          0;

                      final String tipo =
                          (oferta['off_txt_type'] ?? '').toString();
                      final double descuentoPercent = double.tryParse(
                            (oferta['off_de_discountpercent'] ?? '0').toString(),
                          ) ??
                          0.0;

                      final String minSpend =
                          (oferta['off_de_mintotalspend'] ?? '0').toString();
                      final int minOrders = int.tryParse(
                            (oferta['off_int_minorderscount'] ?? '0').toString(),
                          ) ??
                          0;

                      return Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
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

              // ======= RECOMPENSAS (Listado)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
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
                              (oferta['off_txt_title'] ?? 'Oferta especial')
                                  .toString();
                          final String descripcion =
                              (oferta['off_txt_description'] ?? '').toString();
                          final int puntosReq = int.tryParse(
                                (oferta['off_int_pointscost'] ?? '0').toString(),
                              ) ??
                              0;

                          final int offerId = int.tryParse(
                                (oferta['off_int_id'] ?? '0').toString(),
                              ) ??
                              0;

                          final double discountPercent = double.tryParse(
                                (oferta['off_de_discountpercent'] ?? '0')
                                    .toString(),
                              ) ??
                              0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RewardCard(
                              title: titulo,
                              subtitle: descripcion,
                              pointsCost: puntosReq,
                              offerId: offerId,
                              discountPercent: discountPercent,
                              onPointsChanged: _cargarPuntos,
                            ),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _brand.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.info_outline, color: _brand),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tip: Desliza hacia abajo para actualizar puntos y ofertas.',
                          style: TextStyle(
                            color: _textMute,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
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
                      _Pill(text: 'Min $minOrders pedidos', icon: Icons.receipt),
                    if (puntosReq > 0)
                      _Pill(text: '$puntosReq pts', icon: Icons.stars_rounded),
                  ],
                ),
              ],
            ),
          )
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
                          const Icon(Icons.percent,
                              size: 16, color: Color(0xFF22C55E)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                  barrierDismissible: false,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Confirmar canje'),
                      content: const Text(
                        'Este beneficio solo se puede usar una vez. ¿Deseas canjearlo ahora?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Sí, canjear'),
                        ),
                      ],
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
                      content: Text('Debes iniciar sesión para canjear beneficios.'),
                    ),
                  );
                  return;
                }

                final rawToken = prefs.getString('access_token');
                if (rawToken == null || rawToken.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No hay access token. Inicia sesión nuevamente.'),
                    ),
                  );
                  return;
                }

                if (offerId <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo identificar la oferta a canjear.'),
                    ),
                  );
                  return;
                }

                final String keyPuntos = 'puntos_${user.uid}';
                int currentPoints = prefs.getInt(keyPuntos) ?? 0;

                if (pointsCost > 0 && currentPoints < pointsCost) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No tienes suficientes puntos para canjear este beneficio.'),
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

                  if (response.statusCode == 200 || response.statusCode == 201) {
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
                        const SnackBar(content: Text('Beneficio canjeado correctamente.')),
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
                    SnackBar(content: Text('Error al canjear el beneficio: $e')),
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
