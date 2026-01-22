class BackendConfig {
  /// Base URL del backend.
  ///
  /// Se puede sobreescribir con:
  /// `flutter run --dart-define=API_BASE_URL=https://.../api/`
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://services.fintbot.pe/api/',
  );

  /// Construye una [Uri] absoluta a partir de un path relativo.
  ///
  /// Ej: `BackendConfig.api('bubblesplash/progreso/')`
  static Uri api(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl$normalized');
  }
}
