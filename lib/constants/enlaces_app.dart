/// Enlaces de descarga de la app.
///
/// Viven en un solo sitio porque se usan en varias pantallas que comparten la
/// app —invitación desde Inicio y código de referido— y ya habían empezado a
/// divergir: una incluía solo Google Play, de modo que a quien recibía la
/// invitación en un iPhone no le servía de nada.
class EnlacesApp {
  static const String playStore =
      'https://play.google.com/store/apps/details?id=com.finatech.bubblesplash';

  static const String appStore =
      'https://apps.apple.com/pe/app/splash-bubble/id6791381439';

  /// Bloque de descarga para pegar al final de un mensaje que se comparte.
  ///
  /// Se mandan SIEMPRE los dos enlaces, etiquetados: quien comparte no sabe
  /// qué teléfono tiene la otra persona, y el mensaje suele reenviarse a
  /// varias a la vez.
  static const String descargas =
      'Android: $playStore\n'
      'iPhone: $appStore';
}
