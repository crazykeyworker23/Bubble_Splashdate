import 'dart:convert';

import 'package:bubblesplash/utils/tamanos.dart';
import 'package:bubblesplash/views/home/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/views/home/beneficios_page.dart';

class CanjearPuntosPage extends StatefulWidget {
  const CanjearPuntosPage({super.key});

  @override
  State<CanjearPuntosPage> createState() => _CanjearPuntosPageState();
}

class _CanjearPuntosPageState extends State<CanjearPuntosPage> {
  static const Color _brandDark = Color(0xFF0F3D4A);
  static const Color _brandTeal = Color(0xFF128FA0);
  static const Color _bg = Color(0xFFF4FAFF);

  final TextEditingController _controller = TextEditingController();
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );
  bool _isProcessingRedeem = false;

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        title: const Text(
          'Canjear puntos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                  child: _cardCanje(context),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                _brandTeal,
                _brandDark,
                Colors.amber,
                Colors.pink,
                Colors.blueAccent,
              ],
              emissionFrequency: 0.08,
              numberOfParticles: 30,
              maxBlastForce: 30,
              minBlastForce: 10,
              gravity: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandDark, _brandTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Canjea tus puntos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Ingresa el código que recibiste para canjear tus puntos.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _cardCanje(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Canjear código',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _brandDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sirve para códigos de puntos, de descuento y de referido. '
            'Escribe el tuyo y detectamos de cuál se trata.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Ingresa tu código aquí',
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _brandTeal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isProcessingRedeem
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      final code = _controller.text.trim();

                      if (code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Por favor, ingresa un código para canjear.',
                            ),
                          ),
                        );
                        return;
                      }

                      setState(() => _isProcessingRedeem = true);
                      try {
                        await _redeemPromoCode(context, code);
                      } finally {
                        if (mounted) {
                          setState(() => _isProcessingRedeem = false);
                        }
                      }
                    },
              child: _isProcessingRedeem
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Canjear',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso de código de DESCUENTO canjeado.
  ///
  /// A diferencia de los puntos, aquí el cliente ya tiene el beneficio en la
  /// mano: lo único que falta es elegir la bebida. Por eso el botón principal
  /// lleva directo al menú con el descuento aplicado, en vez de dejarlo
  /// buscándolo por su cuenta.
  Future<void> _mostrarDescuentoCanjeado(
    BuildContext context, {
    required double porcentaje,
    required int ofcIntId,
    required String tamanoPermitido,
    int puntos = 0,
  }) async {
    final String pct = porcentaje % 1 == 0
        ? porcentaje.toStringAsFixed(0)
        : porcentaje.toStringAsFixed(2);

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
                color: _brandTeal.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: _brandTeal,
                size: 34,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '¡Código canjeado!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: _brandDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Obtuviste $pct% de descuento.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _brandTeal,
              ),
            ),
            // Un código de descuento puede además entregar puntos; si es el
            // caso, se dice, porque son dos beneficios distintos.
            if (puntos > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Y sumaste $puntos ${puntos == 1 ? 'punto' : 'puntos'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _brandDark,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              (tamanoPermitido.trim().isEmpty
                      ? 'Elige la bebida que quieras y verás el descuento aplicado.'
                      : 'Aplica en vaso ${etiquetaTamano(tamanoPermitido)}. '
                            'Elige tu bebida y verás el descuento aplicado.') +
                  '\n\nSi lo dejas para después, lo encontrarás en '
                      'Beneficios → Mis descuentos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Usarlo después',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => MenuPage(
                    descuento: porcentaje / 100,
                    ofcIntId: ofcIntId > 0 ? ofcIntId : null,
                    allowedSize: tamanoPermitido.trim().isEmpty
                        ? null
                        : tamanoPermitido,
                  ),
                ),
              );
            },
            child: const Text(
              'Elegir mi bebida',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  /// Intenta el código como código de referido.
  ///
  /// Devuelve `true` si se aplicó, o si el servidor respondió algo que deja
  /// claro que SÍ era un código de referido aunque no se pudiera usar («ya
  /// usaste uno antes», «no puedes usar el tuyo»). En ese caso se muestra ese
  /// mensaje, que es el útil: decirle «código inválido» cuando el problema es
  /// que ya lo canjeó sería desorientarle.
  Future<bool> _aplicarComoReferido(
    BuildContext context,
    String code,
    String token,
  ) async {
    try {
      final response = await http.post(
        BackendConfig.api('bubblesplash/referidos/aplicar/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'codigo': code}),
      );

      String mensaje = '';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          mensaje = (decoded['detail'] ?? '').toString().trim();
        }
      } catch (_) {}

      final bool aplicado =
          response.statusCode >= 200 && response.statusCode < 300;

      if (aplicado) {
        _controller.clear();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                mensaje.isEmpty ? 'Código de referido aplicado.' : mensaje,
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return true;
      }

      // «No existe» significa que tampoco era un referido: que siga el flujo
      // normal y se muestre el error del código promocional.
      final esOtroProblema =
          mensaje.isNotEmpty && !mensaje.toLowerCase().contains('no existe');

      if (esOtroProblema && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.orange),
        );
        return true;
      }
    } catch (_) {
      // Sin red o error inesperado: no se traga el error del canje normal.
    }
    return false;
  }

  Future<void> _redeemPromoCode(BuildContext context, String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay sesión activa para canjear el código.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      rawToken = rawToken.trim();
      final uri = BackendConfig.api('bubblesplash/promo-codes/redeem/');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $rawToken',
        },
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String message = 'Código canjeado correctamente.';
        int puntos = 0;
        // ✅ Orientación que envía el backend: cuántas ofertas ya puede canjear
        //    y con qué mensaje invitarlo a la sección Beneficios.
        String guiaMensaje = '';
        int ofertasDisponibles = 0;
        int totalPuntos = 0;

        try {
          final decoded = jsonDecode(response.body);

          // Un código de DESCUENTO no da puntos: entrega un canje listo para
          // usar. Se avisa con su propio mensaje y se ofrece ir directo al
          // menú con el descuento ya aplicado, que es lo que el cliente
          // espera hacer a continuación.
          if (decoded is Map<String, dynamic> &&
              (decoded['tipo'] ?? '').toString().toUpperCase() == 'DESCUENTO') {
            if (!context.mounted) return;
            await _mostrarDescuentoCanjeado(
              context,
              porcentaje:
                  double.tryParse(
                    (decoded['descuento_porcentaje'] ?? '0').toString(),
                  ) ??
                  0,
              ofcIntId:
                  int.tryParse((decoded['ofc_int_id'] ?? '').toString()) ?? 0,
              tamanoPermitido: (decoded['off_txt_allowed_size'] ?? '')
                  .toString(),
            );
            return;
          }

          if (decoded is Map<String, dynamic>) {
            final dynamic m =
                decoded['message'] ?? decoded['detail'] ?? decoded['msg'];
            if (m is String && m.trim().isNotEmpty) {
              message = m.trim();
            }
            // Buscar puntos en la respuesta
            final dynamic pts =
                decoded['points_added'] ??
                decoded['puntos'] ??
                decoded['cantidad'] ??
                decoded['amount'];
            if (pts is int) {
              puntos = pts;
            } else if (pts is String) {
              puntos = int.tryParse(pts) ?? 0;
            }

            final dynamic total = decoded['total_points'];
            if (total is int) {
              totalPuntos = total;
            } else if (total != null) {
              totalPuntos = int.tryParse(total.toString()) ?? 0;
            }

            final dynamic disponibles = decoded['ofertas_disponibles'];
            if (disponibles is int) {
              ofertasDisponibles = disponibles;
            } else if (disponibles != null) {
              ofertasDisponibles = int.tryParse(disponibles.toString()) ?? 0;
            }

            final dynamic nextAction = decoded['next_action'];
            if (nextAction is Map<String, dynamic>) {
              final dynamic guia = nextAction['message'];
              if (guia is String && guia.trim().isNotEmpty) {
                guiaMensaje = guia.trim();
              }
            }
          }
        } catch (_) {}

        // Respaldo si el backend aún no envía `next_action`.
        if (guiaMensaje.isEmpty) {
          guiaMensaje = ofertasDisponibles > 0
              ? 'Ya puedes canjear $ofertasDisponibles '
                    '${ofertasDisponibles == 1 ? "oferta" : "ofertas"} en la sección Beneficios.'
              : 'Ve a la sección Beneficios para ver las ofertas que puedes canjear con tus puntos.';
        }

        // Actualizar el caché local de puntos para reflejar el cambio de inmediato en la interfaz
        User? user;
        try {
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {}
        final String? email =
            prefs.getString('google_email') ?? prefs.getString('savedEmail');
        final String? userUniqueId =
            user?.uid ?? (email != null && email.isNotEmpty ? email : null);
        if (userUniqueId != null) {
          final keyPoints = 'beneficios_puntos_cache_$userUniqueId';
          final keyPuntosAlt = 'puntos_$userUniqueId';
          final currentPoints = prefs.getInt(keyPoints) ?? 0;

          // Hacemos fetch al progreso para obtener el total actualizado del servidor
          int backendPoints = currentPoints;
          try {
            final progUri = BackendConfig.api('bubblesplash/progreso/');
            final progResponse = await http.get(
              progUri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $rawToken',
              },
            );
            debugPrint(
              'GET bubblesplash/progreso/ (canje) status: ${progResponse.statusCode}',
            );
            debugPrint(
              'GET bubblesplash/progreso/ (canje) body: ${progResponse.body}',
            );
            if (progResponse.statusCode == 200) {
              final dynamic body = jsonDecode(progResponse.body);
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
            }
          } catch (e) {
            debugPrint('Error al actualizar puntos de progreso: $e');
          }

          if (backendPoints != currentPoints && backendPoints > 0) {
            final diff = backendPoints - currentPoints;
            if (diff > 0) {
              puntos = diff;
            }
            await prefs.setInt(keyPoints, backendPoints);
            await prefs.setInt(keyPuntosAlt, backendPoints);
          } else if (puntos > 0) {
            await prefs.setInt(keyPoints, currentPoints + puntos);
            await prefs.setInt(keyPuntosAlt, currentPoints + puntos);
          }
        }

        _controller.clear();
        _confettiController.play();
        if (context.mounted) {
          final bool? irABeneficios = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (ctx) {
              return _BonitaAnimacionDialog(
                puntos: puntos > 0 ? puntos : 100,
                brandTeal: _brandTeal,
                brandDark: _brandDark,
                mensaje: message,
                guia: guiaMensaje,
                totalPuntos: totalPuntos,
              );
            },
          );

          // ✅ Lleva al cliente directo a Beneficios: es el paso siguiente que
          //    muchos usuarios no encuentran solos después de sumar puntos.
          if (irABeneficios == true && context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BeneficiosPage()),
            );
          }
        }
      } else {
        String errorMessage = 'No se pudo canjear el código.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic m =
                decoded['error'] ?? decoded['detail'] ?? decoded['message'];
            if (m is String && m.trim().isNotEmpty) {
              errorMessage = m.trim();
            }
          } else if (decoded is List && decoded.isNotEmpty) {
            final dynamic first = decoded.first;
            if (first is String && first.trim().isNotEmpty) {
              errorMessage = first.trim();
            }
          }
        } catch (_) {
          if (response.body.isNotEmpty) {
            errorMessage = 'Error ${response.statusCode}: ${response.body}';
          } else {
            errorMessage = 'Error ${response.statusCode} al canjear el código.';
          }
        }

        // No era un código promocional. Antes de darlo por malo se prueba
        // como código de referido: el cliente escribe un código sin saber de
        // qué tipo es, y obligarle a acertar de pantalla es trabajo suyo que
        // puede hacer la app.
        if (await _aplicarComoReferido(context, code, rawToken)) return;

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al canjear el código: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _BonitaAnimacionDialog extends StatefulWidget {
  final int puntos;
  final String mensaje;
  final Color brandTeal;
  final Color brandDark;

  /// Texto que orienta al cliente sobre qué hacer con sus puntos.
  final String guia;

  /// Total de puntos acumulados después del canje.
  final int totalPuntos;

  const _BonitaAnimacionDialog({
    required this.puntos,
    required this.mensaje,
    required this.brandTeal,
    required this.brandDark,
    this.guia = '',
    this.totalPuntos = 0,
  });

  @override
  State<_BonitaAnimacionDialog> createState() => _BonitaAnimacionDialogState();
}

class _BonitaAnimacionDialogState extends State<_BonitaAnimacionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _pointsAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pointsAnimation = IntTween(
      begin: 0,
      end: widget.puntos,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, color: widget.brandTeal, size: 56),
            const SizedBox(height: 12),
            Text(
              '¡Puntos canjeados!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: widget.brandDark,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _pointsAnimation,
              builder: (context, child) {
                return Text(
                  '+${_pointsAnimation.value} pts',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: widget.brandTeal,
                    shadows: [
                      Shadow(
                        color: widget.brandTeal.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (widget.totalPuntos > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Tienes ${widget.totalPuntos} puntos en total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.brandDark.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              widget.mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),

            // ✅ Guía: le decimos explícitamente qué hacer ahora con sus puntos.
            if (widget.guia.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.brandTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.brandTeal.withOpacity(0.22)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      color: widget.brandTeal,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Y ahora qué hago?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: widget.brandDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.guia,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.brandTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // `true` => la pantalla anterior navega a Beneficios.
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Ver mis beneficios',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Más tarde',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.brandDark.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
