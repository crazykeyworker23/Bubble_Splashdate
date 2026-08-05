import 'package:flutter/material.dart';

import 'package:bubblesplash/services/canjes_service.dart';
import 'package:bubblesplash/utils/tamanos.dart';
import 'package:bubblesplash/views/home/menu_page.dart';

/// Descuentos obtenidos y todavía sin usar.
///
/// Existe como pantalla propia y no como una pila de avisos dentro de
/// Beneficios: con varios descuentos, esos avisos empujaban el contenido real
/// hacia abajo. Aquí caben todos sin estorbar, y Beneficios solo necesita
/// mostrar cuántos hay.
class MisDescuentosPage extends StatefulWidget {
  const MisDescuentosPage({super.key});

  @override
  State<MisDescuentosPage> createState() => _MisDescuentosPageState();
}

class _MisDescuentosPageState extends State<MisDescuentosPage> {
  static const Color _brandTeal = Color(0xFF1B6F81);
  static const Color _brandDark = Color(0xFF0F3E47);

  List<CanjePendiente> _canjes = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final canjes = await CanjesService.pendientes();
    if (!mounted) return;
    setState(() {
      _canjes = canjes;
      _cargando = false;
    });
  }

  void _usar(CanjePendiente canje) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuPage(
          descuento: canje.fraccion,
          ofcIntId: canje.id,
          allowedSize: canje.tamanoPermitido.trim().isEmpty
              ? null
              : canje.tamanoPermitido,
        ),
      ),
      // Al volver se recarga: si el descuento ya se usó, desaparece de la lista.
    ).then((_) => _cargar());
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
          'Mis descuentos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _canjes.isEmpty
                ? _vacio()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _canjes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _tarjeta(_canjes[index]),
                  ),
      ),
    );
  }

  /// La lista vacía va dentro de un scroll para que el gesto de recargar
  /// funcione igual cuando no hay nada que mostrar.
  Widget _vacio() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: const [
        Icon(Icons.local_offer_outlined, size: 64, color: Colors.black26),
        SizedBox(height: 16),
        Text(
          'No tienes descuentos pendientes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _brandDark,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Cuando canjees una oferta con tus puntos o uses un código de '
          'descuento, aparecerá aquí hasta que lo apliques en un pedido.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(CanjePendiente canje) {
    final String pct = canje.porcentaje % 1 == 0
        ? canje.porcentaje.toStringAsFixed(0)
        : canje.porcentaje.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EEF5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brandTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_rounded, color: _brandTeal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canje.porcentaje > 0
                      ? '$pct% de descuento'
                      : 'Descuento disponible',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _brandDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canje.tamanoPermitido.trim().isEmpty
                      ? canje.titulo
                      : '${canje.titulo} · vaso ${etiquetaTamano(canje.tamanoPermitido)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => _usar(canje),
            child: const Text(
              'Usar',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
