import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/constants/enlaces_app.dart';
import 'package:bubblesplash/services/app_http.dart' as http;

/// Código de referido del usuario: verlo, copiarlo y compartirlo.
///
/// El código es único y permanente: lo crea el servidor la primera vez que se
/// pide y ya no cambia aunque el usuario cierre sesión, cambie de teléfono o
/// reinstale la app.
///
/// AQUÍ NO SE DICE CUÁNTOS PUNTOS SE GANAN, a propósito. La cifra la fija el
/// negocio y puede cambiar; anunciarla en pantalla convierte cualquier ajuste
/// en una promesa incumplida ante quien ya había compartido su código. Se
/// habla de «ganar puntos» y el importe real se ve acreditado en el saldo.
class ReferidosPage extends StatefulWidget {
  const ReferidosPage({super.key});

  @override
  State<ReferidosPage> createState() => _ReferidosPageState();
}

class _ReferidosPageState extends State<ReferidosPage> {
  static const Color _brandTeal = Color(0xFF1B6F81);
  static const Color _brandDark = Color(0xFF0F3E47);
  static const Color _coral = Color(0xFFE28F83);

  bool _cargando = true;
  String? _error;

  String _codigo = '';
  int _montoMinimo = 0;
  int _totalInvitados = 0;
  int _pendientes = 0;
  int _puntosGanados = 0;

  /// ¿Puede todavía escribir el código de quien lo invitó?
  ///
  /// Solo antes de su primera compra o recarga. Hace falta aquí porque no
  /// todos llegan por el formulario de registro: quien entra con Google o
  /// Apple nunca vio ese campo.
  bool _puedeIngresarCodigo = false;
  bool _yaFueReferido = false;
  String? _referidoPor;
  bool _enviandoCodigo = false;

  /// ¿Los puntos se entregan al canjear o tras la primera compra?
  /// Lo decide el servidor; la app solo redacta el mensaje acorde.
  bool _recompensaInmediata = false;

  final TextEditingController _codigoAmigoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final response = await http.get(
        BackendConfig.api('bubblesplash/referidos/mi-codigo/'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer __placeholder__',
        },
      );

      if (response.statusCode != 200) {
        setState(() {
          _cargando = false;
          _error = 'No pudimos obtener tu código. Inténtalo de nuevo.';
        });
        return;
      }

      final d = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;

      setState(() {
        _codigo = (d['codigo'] ?? '').toString();
        _montoMinimo = int.tryParse((d['monto_minimo'] ?? 0).toString()) ?? 0;
        _totalInvitados =
            int.tryParse((d['total_invitados'] ?? 0).toString()) ?? 0;
        _pendientes = int.tryParse((d['pendientes'] ?? 0).toString()) ?? 0;
        _puntosGanados =
            int.tryParse((d['puntos_ganados'] ?? 0).toString()) ?? 0;
        _puedeIngresarCodigo = d['puede_ingresar_codigo'] == true;
        _recompensaInmediata = d['recompensa_inmediata'] == true;
        _yaFueReferido = d['ya_fue_referido'] == true;
        _referidoPor = (d['referido_por'] ?? '').toString().trim().isEmpty
            ? null
            : d['referido_por'].toString();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  /// Mensaje que se envía al amigo.
  ///
  /// La condición se toma del servidor, no se escribe a mano: cuando la
  /// recompensa es inmediata, prometer puntos «con tu primera compra» sería
  /// mentirle a quien lo recibe, y era lo que pasaba.
  String get _mensajeParaCompartir {
    final comoSeGana = _recompensaInmediata
        ? 'Los dos ganamos puntos al instante.'
        : 'Los dos ganamos puntos con tu primera compra desde '
              'S/ $_montoMinimo.';

    return '¡Descarga Splash Bubble y usa mi código de referido $_codigo al '
        'registrarte! $comoSeGana\n\n'
        '${EnlacesApp.descargas}';
  }

  /// Aplica el código de quien invitó a este usuario.
  Future<void> _aplicarCodigoAmigo() async {
    final codigo = _codigoAmigoController.text.trim().toUpperCase();
    if (codigo.isEmpty) return;

    setState(() => _enviandoCodigo = true);
    try {
      final response = await http.post(
        BackendConfig.api('bubblesplash/referidos/aplicar/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer __placeholder__',
        },
        body: jsonEncode({'codigo': codigo}),
      );

      final decoded = jsonDecode(response.body);
      final mensaje = (decoded is Map && decoded['detail'] != null)
          ? decoded['detail'].toString()
          : 'No se pudo aplicar el código.';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: response.statusCode == 201
              ? _brandTeal
              : Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 201) {
        _codigoAmigoController.clear();
        await _cargar();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa tu conexión e inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviandoCodigo = false);
    }
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _codigo));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Código de referido',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _tarjetaCodigo(),
                  const SizedBox(height: 16),
                  if (_puedeIngresarCodigo || _yaFueReferido) ...[
                    _codigoDeAmigo(),
                    const SizedBox(height: 16),
                  ],
                  _comoFunciona(),
                  const SizedBox(height: 16),
                  _misInvitados(),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaCodigo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandDark, _brandTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Text(
            'Tu código',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          // El código se muestra grande y espaciado: se dicta y se teclea a
          // mano, así que la legibilidad importa más que la estética.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _codigo.isEmpty ? '········' : _codigo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _codigo.isEmpty ? null : _copiar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.2),
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'Copiar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _codigo.isEmpty
                      ? null
                      : () => SharePlus.instance.share(
                          ShareParams(
                            text: _mensajeParaCompartir,
                            subject: '¡Únete a Splash Bubble!',
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _coral,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Compartir',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Campo para escribir el código de quien te invitó.
  ///
  /// Vive aquí y no solo en el registro porque hay varias formas de crear la
  /// cuenta —formulario, Google, Apple— y únicamente la primera mostraba ese
  /// campo. Quien entró con Google se quedaba sin poder usar su código.
  Widget _codigoDeAmigo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EEF5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Te invitó un amigo?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _brandDark,
            ),
          ),
          const SizedBox(height: 6),
          if (_yaFueReferido) ...[
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: _brandTeal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _referidoPor == null
                        ? 'Ya usaste el código de un amigo.'
                        : 'Te invitó $_referidoPor.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              _recompensaInmediata
                  ? 'Escribe su código y los dos ganan puntos al instante.'
                  // «Próxima» y no «primera»: también puede canjear quien ya
                  // venía comprando, y a ese la primera ya le pasó.
                  : 'Escribe su código y los dos ganan puntos con tu próxima '
                        'compra o recarga desde S/ $_montoMinimo.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigoAmigoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Código de tu amigo',
                      filled: true,
                      fillColor: const Color(0xFFF4F6FA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: _enviandoCodigo ? null : _aplicarCodigoAmigo,
                  child: Text(
                    _enviandoCodigo ? '…' : 'Aplicar',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _comoFunciona() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EEF5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo funciona',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _brandDark,
            ),
          ),
          const SizedBox(height: 12),
          _paso(
            '1',
            'Comparte tu código',
            'Tu amigo lo escribe al registrarse en la app.',
          ),
          _paso(
            '2',
            'Tu amigo gana puntos de bienvenida',
            _recompensaInmediata
                ? 'Se le acreditan en cuanto escribe tu código.'
                : 'Se le acreditan con su primera compra o recarga desde '
                      'S/ $_montoMinimo.',
          ),
          _paso(
            '3',
            'Tú también ganas puntos',
            'Y por cada persona que invites. No hay límite.',
            ultimo: true,
          ),
        ],
      ),
    );
  }

  Widget _paso(String n, String titulo, String detalle, {bool ultimo = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _coral.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                color: _coral,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _brandDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _misInvitados() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EEF5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mis invitados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _brandDark,
            ),
          ),
          const SizedBox(height: 14),
          // Solo dos cifras: cuánta gente invitó y qué ha ganado por ello.
          //
          // Antes había una tercera, «Ya compraron», heredada de cuando la
          // recompensa esperaba a la primera compra del invitado. Ahora los
          // puntos se dan al escribir el código, así que esa columna contaba
          // algo que no condiciona nada y sembraba la duda de si hacía falta
          // que el amigo comprara para cobrar.
          Row(
            children: [
              _dato('$_totalInvitados', 'Invitados'),
              _dato('$_puntosGanados', 'Puntos ganados'),
            ],
          ),
          if (!_recompensaInmediata && _pendientes > 0) ...[
            const SizedBox(height: 14),
            Text(
              _pendientes == 1
                  ? 'Tienes 1 invitado que aún no hace su primera compra.'
                  : 'Tienes $_pendientes invitados que aún no hacen su primera compra.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dato(String valor, String etiqueta) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _brandTeal,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
