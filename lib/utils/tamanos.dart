/// Nombres de los tamaños de vaso.
///
/// Splash Bubble vende TRES tamaños: Pequeño, Mediano y Grande.
///
/// En el backend se guardan como CÓDIGO canónico —`PEQUENO`, `MEDIANO`,
/// `GRANDE`— para que el cobro del recargo no dependa de cómo se escribiera
/// el nombre en el panel. Los códigos van sin Ñ porque viajan en JSON y en
/// comparaciones; la eñe vive en la etiqueta, que es lo que se lee. Antes era texto libre
/// y convivían 'GRANDE', 'Grande' y 'grande' como tamaños distintos, con la
/// consecuencia de que el recargo no se cobraba.
///
/// Aquí se traduce ese código a lo que debe leer el cliente. Es el espejo de
/// `tamanos.py` en el backend: si se añade un tamaño allí, hay que añadirlo
/// aquí.
const Map<String, String> _etiquetas = {
  'PEQUENO': 'Pequeño',
  'MEDIANO': 'Mediano',
  'GRANDE': 'Grande',
};

/// Equivalencias de lo que pueda venir escrito de otra forma.
///
/// Hace falta porque un teléfono puede tener el carrito guardado con el
/// nombre antiguo ('Mediano') desde antes de la normalización.
const Map<String, String> _alias = {
  'PEQUENO': 'PEQUENO',
  'PEQUEÑO': 'PEQUENO',
  'CHICO': 'PEQUENO',
  'SMALL': 'PEQUENO',
  'S': 'PEQUENO',
  'MEDIANO': 'MEDIANO',
  'MEDIANA': 'MEDIANO',
  'MEDIUM': 'MEDIANO',
  'M': 'MEDIANO',
  'NORMAL': 'MEDIANO', // código antiguo del sistema
  'MEDIANTE': 'MEDIANO', // errata real del catálogo
  'GRANDE': 'GRANDE',
  'LARGE': 'GRANDE',
  'L': 'GRANDE',
  'G': 'GRANDE',
};

/// Código canónico de un tamaño escrito de cualquier forma.
String codigoTamano(String? valor) {
  final clave = (valor ?? 'MEDIANO').trim().toUpperCase().replaceAll(' ', '_');
  return _alias[clave] ?? clave;
}

/// Nombre que se le muestra al cliente. `MEDIANO` -> `Mediano`.
///
/// Un tamaño que no sea de los tres se presenta lo mejor
/// posible en vez de enseñar el código en crudo.
String etiquetaTamano(String? valor) {
  final codigo = codigoTamano(valor);
  final etiqueta = _etiquetas[codigo];
  if (etiqueta != null) return etiqueta;

  final limpio = codigo.replaceAll('_', ' ').toLowerCase().trim();
  if (limpio.isEmpty) return '';
  return limpio[0].toUpperCase() + limpio.substring(1);
}
