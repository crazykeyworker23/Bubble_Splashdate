import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bubblesplash/constants/api_constants.dart';
import 'package:bubblesplash/services/auth_service.dart';

class CanjearPuntosPage extends StatelessWidget {
  const CanjearPuntosPage({super.key});

  static const Color _brandDark = Color(0xFF0F3D4A);
  static const Color _brandTeal = Color(0xFF128FA0);
  static const Color _bg = Color(0xFFF4FAFF);

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
      body: SingleChildScrollView(
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
    final TextEditingController controller = TextEditingController();

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
            controller: controller,
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
                final code = controller.text.trim();

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
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic m = decoded['message'] ?? decoded['detail'] ?? decoded['msg'];
            if (m is String && m.trim().isNotEmpty) {
              message = m.trim();
            }
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
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
            errorMessage = 'Error ${response.statusCode}: ${response.body}';
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
