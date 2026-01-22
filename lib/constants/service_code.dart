/// Código de servicio que el backend exige en el header `X-Service-Code`.
///
/// Se puede sobreescribir en build/runtime con:
/// `--dart-define=SERVICE_CODE=bubble` o `--dart-define=SERVICE_CODE=dateanddo`
const String kServiceCode = String.fromEnvironment(
  'SERVICE_CODE',
  defaultValue: 'bubble',
);
