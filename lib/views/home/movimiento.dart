class Movimiento {
  final String titulo;
  final double monto;
  final String tipo; // 'recarga' o 'gasto'
  final String fecha;

  Movimiento({required this.titulo, required this.monto, required this.tipo, required this.fecha});

  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'monto': monto,
    'tipo': tipo,
    'fecha': fecha,
  };

  factory Movimiento.fromJson(Map<String, dynamic> json) => Movimiento(
    titulo: json['titulo'],
    monto: (json['monto'] as num).toDouble(),
    tipo: json['tipo'],
    fecha: json['fecha'],
  );
}
