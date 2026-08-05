import 'package:flutter/material.dart';

import 'package:bubblesplash/services/sede_service.dart';

/// Diálogo BLOQUEANTE para elegir sede.
///
/// Se muestra la primera vez que un usuario entra sin sede asignada (típico
/// del acceso con Google, donde no pasa por el formulario de registro).
///
/// No se puede cerrar: ni con el botón atrás, ni tocando fuera, ni con una X.
/// Hasta que no confirme una sede, la app no muestra menú, productos ni
/// beneficios, porque todo ese contenido depende de la sede.
class SedeObligatoriaDialog extends StatefulWidget {
  const SedeObligatoriaDialog({super.key});

  /// Abre el diálogo y devuelve la sede elegida (nunca `null` si se completó).
  static Future<Sede?> mostrar(BuildContext context) {
    return showDialog<Sede>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SedeObligatoriaDialog(),
    );
  }

  @override
  State<SedeObligatoriaDialog> createState() => _SedeObligatoriaDialogState();
}

class _SedeObligatoriaDialogState extends State<SedeObligatoriaDialog> {
  static const Color _brandDark = Color(0xFF0F3D4A);
  static const Color _brandTeal = Color(0xFF128FA0);

  List<Sede> _sedes = const [];
  Sede? _seleccionada;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSedes();
  }

  Future<void> _cargarSedes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final sedes = await SedeService.fetchSedes();

    if (!mounted) return;
    setState(() {
      _sedes = sedes;
      _cargando = false;
      _error = sedes.isEmpty
          ? (SedeService.lastError ?? 'No se pudieron cargar las sedes.')
          : null;
    });
  }

  Future<void> _confirmar() async {
    final sede = _seleccionada;
    if (sede == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final ok = await SedeService.updateMySede(sede);

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar tu sede. Revisa tu conexión e inténtalo otra vez.';
      });
      return;
    }

    Navigator.of(context).pop(sede);
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false bloquea el botón atrás del sistema.
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabecera
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_brandDark, _brandTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.storefront_rounded, color: Colors.white, size: 38),
                    SizedBox(height: 12),
                    Text(
                      '¿En qué sede nos visitas?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Elige tu local para mostrarte su carta, sus precios y sus '
                      'beneficios. Podrás cambiarlo luego desde Mi perfil.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: _buildContenido(),
                ),
              ),

              // Acción
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        (_seleccionada == null || _guardando) ? null : _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandTeal,
                      disabledBackgroundColor: const Color(0xFFD4D4D4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _seleccionada == null
                                ? 'Selecciona una sede'
                                : 'Continuar en ${_seleccionada!.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Cargando sedes…',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_sedes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _error ?? 'No se pudieron cargar las sedes.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _cargarSedes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._sedes.map(_buildOpcion),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpcion(Sede sede) {
    final elegida = _seleccionada?.id == sede.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _guardando ? null : () => setState(() => _seleccionada = sede),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: elegida ? _brandTeal.withOpacity(0.07) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: elegida ? _brandTeal : const Color(0xFFE0E0E0),
              width: elegida ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                elegida
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: elegida ? _brandTeal : const Color(0xFFBDBDBD),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sede.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _brandDark,
                      ),
                    ),
                    if (sede.city.isNotEmpty && sede.city != sede.name) ...[
                      const SizedBox(height: 2),
                      Text(
                        sede.city,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
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
