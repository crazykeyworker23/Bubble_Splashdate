import 'package:flutter/material.dart';

/// Icono y colores con los que se dibuja una oferta.
class AspectoOferta {
  final IconData icono;
  final Color color;
  final List<Color> fondo;

  const AspectoOferta(this.icono, this.color, this.fondo);
}

/// Catálogo de iconos que el administrador puede elegir en el panel.
///
/// La clave (`bebida`, `perfume`…) es lo único que viaja desde el servidor;
/// el dibujo lo pone la app. Así se puede cambiar el aspecto de un icono sin
/// tocar ni un registro de la base de datos.
///
/// La lista está replicada en:
///   - finatechservices/apps/bubblesplash/iconos_oferta.py  (catálogo maestro)
///   - Splashbubbletea/src/lib/iconosOferta.ts              (selector del panel)
/// Una clave que esta app no conozca no rompe nada: cae al aspecto por
/// defecto, igual que si no se hubiera elegido ninguno.
const Map<String, AspectoOferta> _catalogo = {
  'bebida': AspectoOferta(
    Icons.local_drink,
    Color(0xFF128FA0),
    [Color(0xFFD5EFEC), Color(0xFFB6E3DF)],
  ),
  // Alias histórico de 'bebida'. Ya no se ofrece en el panel —era el mismo
  // vaso con otro nombre— pero se conserva para que una oferta guardada con
  // esa clave siga dibujándose y no caiga al icono automático.
  'vaso': AspectoOferta(
    Icons.local_drink,
    Color(0xFF128FA0),
    [Color(0xFFD5EFEC), Color(0xFFB6E3DF)],
  ),
  'cafe': AspectoOferta(
    Icons.coffee,
    Color(0xFF6D4C41),
    [Color(0xFFF0E3DC), Color(0xFFE0CBC0)],
  ),
  'topping': AspectoOferta(
    Icons.bubble_chart,
    Color(0xFF8B5E34),
    [Color(0xFFF6E7D2), Color(0xFFE9D2B4)],
  ),
  'tamano': AspectoOferta(
    Icons.arrow_circle_up,
    Color(0xFF2E7D32),
    [Color(0xFFDDF3DF), Color(0xFFC2E7C6)],
  ),
  'postre': AspectoOferta(
    Icons.icecream,
    Color(0xFFAD1457),
    [Color(0xFFFBDDEA), Color(0xFFF4C0D6)],
  ),
  'comida': AspectoOferta(
    Icons.restaurant,
    Color(0xFF00695C),
    [Color(0xFFD2ECE6), Color(0xFFB3DED5)],
  ),
  'cupon': AspectoOferta(
    Icons.confirmation_number,
    Color(0xFF00838F),
    [Color(0xFFD3EFF3), Color(0xFFB2E2E8)],
  ),
  'descuento': AspectoOferta(
    Icons.percent,
    Color(0xFFC2410C),
    [Color(0xFFFBE3D4), Color(0xFFF6CDB2)],
  ),
  'regalo': AspectoOferta(
    Icons.card_giftcard,
    Color(0xFFB3245C),
    [Color(0xFFFBDCE7), Color(0xFFF5BFD2)],
  ),
  'premium': AspectoOferta(
    Icons.workspace_premium,
    Color(0xFF7B3FA0),
    [Color(0xFFEDDDF6), Color(0xFFDCC2EC)],
  ),
  'estrella': AspectoOferta(
    Icons.star_rounded,
    Color(0xFFB27400),
    [Color(0xFFFBEED2), Color(0xFFF4DFAE)],
  ),
  'corazon': AspectoOferta(
    Icons.favorite,
    Color(0xFFC2185B),
    [Color(0xFFFBDCE7), Color(0xFFF5BFD2)],
  ),
  'perfume': AspectoOferta(
    Icons.sanitizer,
    Color(0xFF5E35B1),
    [Color(0xFFE6DEF7), Color(0xFFD1C3EE)],
  ),
  'belleza': AspectoOferta(
    Icons.auto_awesome,
    Color(0xFFD81B60),
    [Color(0xFFFBDDEA), Color(0xFFF4C0D6)],
  ),
  'compras': AspectoOferta(
    Icons.shopping_bag,
    Color(0xFF1565C0),
    [Color(0xFFD8E6F8), Color(0xFFBBD4F2)],
  ),
  'delivery': AspectoOferta(
    Icons.delivery_dining,
    Color(0xFF1565C0),
    [Color(0xFFD8E6F8), Color(0xFFBBD4F2)],
  ),
  'cumpleanos': AspectoOferta(
    Icons.cake,
    Color(0xFFE65100),
    [Color(0xFFFBE7D2), Color(0xFFF5D2AE)],
  ),
  'fuego': AspectoOferta(
    Icons.local_fire_department,
    Color(0xFFD84315),
    [Color(0xFFFBDED4), Color(0xFFF5C2B2)],
  ),
  'etiqueta': AspectoOferta(
    Icons.sell,
    Color(0xFF37474F),
    [Color(0xFFE1E6E8), Color(0xFFC9D1D4)],
  ),
};

/// Aspecto de la clave elegida en el panel, o `null` si no se eligió ninguna
/// (o si la clave no está en este catálogo).
///
/// Devolver `null` en vez de un icono cualquiera es intencionado: quien llama
/// necesita saber que no hubo elección para poder deducirlo del título, que es
/// mejor que un icono genérico.
AspectoOferta? aspectoElegido(String? clave) {
  final k = (clave ?? '').trim().toLowerCase();
  if (k.isEmpty) return null;
  return _catalogo[k];
}
