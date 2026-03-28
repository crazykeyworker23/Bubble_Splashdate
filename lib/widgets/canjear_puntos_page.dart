import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bubblesplash/constants/api_constants.dart';
import 'package:bubblesplash/services/auth_service.dart';


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
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 2));

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
            'Ingresar código',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _brandDark,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Ingresa tu código aquí',
              filled: true,
              fillColor: const Color(0xFFF4F6FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final code = _controller.text.trim();

                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, ingresa un código para canjear.')),
                  );
                  return;
                }
                await _redeemPromoCode(context, code);
              },
              child: const Text(
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

  Future<void> _redeemPromoCode(BuildContext context, String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay sesión activa para canjear el código.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      rawToken = rawToken.trim();

      Future<http.Response> _postWithToken(String token) {
        final uri = Uri.parse(
          ApiConstants.baseUrl + '/bubblesplash/promo-codes/redeem/',
        );

        return http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'code': code}),
        );
      }

      http.Response response = await _postWithToken(rawToken);

      // Si el token expiró, intentamos refrescarlo una vez.
      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          final newToken = (prefs.getString('access_token') ?? '').trim();
          if (newToken.isNotEmpty) {
            response = await _postWithToken(newToken);
          }
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String message = 'Código canjeado correctamente.';
        int puntos = 0;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic m = decoded['message'] ?? decoded['detail'] ?? decoded['msg'];
            if (m is String && m.trim().isNotEmpty) {
              message = m.trim();
            }
            // Buscar puntos en la respuesta
            final dynamic pts = decoded['puntos'] ?? decoded['points'] ?? decoded['cantidad'] ?? decoded['amount'];
            if (pts is int) {
              puntos = pts;
            } else if (pts is String) {
              puntos = int.tryParse(pts) ?? 0;
            }
          }
        } catch (_) {}

        _controller.clear();
        _confettiController.play();
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            return _BonitaAnimacionDialog(
              puntos: puntos > 0 ? puntos : 100,
              mensaje: message,
              brandTeal: _brandTeal,
              brandDark: _brandDark,
            );
          },
        );
      } else {
        String errorMessage = 'No se pudo canjear el código.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic m = decoded['error'] ?? decoded['detail'] ?? decoded['message'];
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
            errorMessage = 'Error  20${response.statusCode}: ${response.body}';
          } else {
            errorMessage = 'Error ${response.statusCode} al canjear el código.';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al canjear el código: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

}

class _BonitaAnimacionDialog extends StatefulWidget {
  final int puntos;
  final String mensaje;
  final Color brandTeal;
  final Color brandDark;
  const _BonitaAnimacionDialog({
    required this.puntos,
    required this.mensaje,
    required this.brandTeal,
    required this.brandDark,
  });

  @override
  State<_BonitaAnimacionDialog> createState() => _BonitaAnimacionDialogState();
}

class _BonitaAnimacionDialogState extends State<_BonitaAnimacionDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _pointsAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pointsAnimation = IntTween(begin: 0, end: widget.puntos).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
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
            const SizedBox(height: 10),
            Text(
              widget.mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.brandTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Text(
                  '¡Gracias!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
