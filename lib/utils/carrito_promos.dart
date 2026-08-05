/// Saneado de los precios promocionales guardados en el carrito.
///
/// EL PROBLEMA QUE RESUELVE
/// ------------------------
/// El carrito se guarda en el teléfono con el precio YA descontado del canje
/// (`price` con el descuento aplicado, más `discountPercent` e `isPromoItem`).
/// Pero el canje en sí —`ofc_int_id`— no se guardaba: viaja como parámetro de
/// la pantalla.
///
/// Al salir de la app y volver a entrar, el carrito se restauraba con el
/// precio rebajado mientras que la petición al servidor ya no llevaba el
/// canje. El backend recalculaba a precio completo y cobraba de más: en
/// producción se descontaron S/ 25,00 de la billetera por un pedido que la app
/// mostraba como S/ 10,00.
///
/// LA REGLA
/// --------
/// Un precio promocional solo es válido mientras exista el canje que lo
/// justifica. Si el carrito se restaura sin canje activo, los ítems vuelven a
/// su precio normal. El cliente ve el precio real —el mismo que va a cobrar el
/// servidor— y puede volver a aplicar su canje desde Beneficios.
library;

double _comoDouble(dynamic valor) {
  if (valor is double) return valor;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor?.toString() ?? '') ?? 0.0;
}

/// ¿Este ítem lleva un precio rebajado por un canje?
bool tienePrecioPromocional(Map<String, dynamic> item) {
  if (item['isPromoItem'] == true) return true;
  if (_comoDouble(item['discountPercent']) > 0) return true;
  if (_comoDouble(item['discountAmount']) > 0) return true;

  // El precio guardado es menor que el original: viene de un canje.
  final double original = _comoDouble(item['priceOriginal']);
  return original > 0 && _comoDouble(item['price']) < original - 0.001;
}

/// Devuelve el ítem a su precio normal, quitando cualquier rastro del canje.
Map<String, dynamic> sinPrecioPromocional(Map<String, dynamic> item) {
  final salida = Map<String, dynamic>.from(item);

  final double original = _comoDouble(item['priceOriginal']);
  if (original > 0) {
    salida['price'] = original;
  }

  salida['discountPercent'] = 0.0;
  salida['discountAmount'] = 0.0;
  salida['isPromoItem'] = false;

  return salida;
}

/// Sanea un carrito restaurado del almacenamiento local.
///
/// `hayCanjeActivo` indica si la pantalla tiene un canje vigente en esta
/// sesión. Sin él, los precios promocionales se revierten.
List<Map<String, dynamic>> sanearCarritoGuardado(
  List<Map<String, dynamic>> items, {
  required bool hayCanjeActivo,
}) {
  if (hayCanjeActivo) return items;

  return items
      .map((item) => tienePrecioPromocional(item) ? sinPrecioPromocional(item) : item)
      .toList();
}
