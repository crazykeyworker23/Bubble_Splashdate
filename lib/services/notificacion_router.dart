import 'package:flutter/material.dart';

import 'package:bubblesplash/utils/globals.dart';
import 'package:bubblesplash/views/home/beneficios_page.dart';
import 'package:bubblesplash/views/home/movimientos_page.dart';

/// Qué hacer cuando el usuario toca una notificación.
///
/// Hasta ahora no hacía nada: los tres puntos donde se recoge el toque
/// —app abierta, app en segundo plano y app cerrada— solo escribían en la
/// consola. El usuario tocaba el aviso de su pedido, se abría la app en la
/// pantalla de inicio y tenía que buscar él mismo de qué le estaban hablando.
///
/// El servidor ya manda `tipo` y `ruta` en cada notificación, así que aquí
/// solo hay que interpretarlos. Si la notificación no trae ninguna pista
/// —o el destino ya no existe— se enseña el detalle en un diálogo en vez de
/// no hacer nada: quedarse quieto parece que la app está rota.
class NotificacionRouter {
  /// Abre lo que corresponda a esta notificación.
  ///
  /// `titulo` y `cuerpo` son los del aviso, para poder mostrarlos cuando no
  /// haya a dónde ir.
  static Future<void> abrir(
    Map<String, dynamic> data, {
    String titulo = '',
    String cuerpo = '',
  }) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final destino = _destino(data);

    if (destino != null) {
      await Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => destino));
      return;
    }

    await _mostrarDetalle(ctx, data, titulo, cuerpo);
  }

  /// Pantalla a la que lleva la notificación, o `null` si no lleva a ninguna.
  ///
  /// Se mira primero `ruta`, que es lo que el servidor decide a propósito, y
  /// solo después `tipo`. Así se puede cambiar el destino de una notificación
  /// desde el backend sin publicar una versión nueva de la app.
  static Widget? _destino(Map<String, dynamic> data) {
    final ruta = (data['ruta'] ?? '').toString().trim().toLowerCase();
    final tipo = (data['tipo'] ?? '').toString().trim().toUpperCase();

    // Una COMPRA sí lleva a Movimientos, pero abriendo SU detalle, no la lista.
    // Dejar al cliente frente a decenas de movimientos para que busque el suyo
    // es dejarle el trabajo a medias.
    if (tipo == 'PEDIDO') {
      final numero = (data['pedido'] ?? data['pedido_id'] ?? '').toString();
      return MovimientosPage(
        abrirPedido: numero.trim().isEmpty ? null : numero,
      );
    }

    // Los avisos de ESTADO no llevan a ninguna pantalla: se abre su detalle.
    //
    // A quien le avisan de que su bebida está lista no le sirve una lista de
    // importes: quiere saber qué pedido es y en qué estado está, y eso se lee
    // mejor en el propio aviso.
    if (tipo == 'PEDIDO_ESTADO' || tipo == 'PEDIDO_NUEVO') {
      return null;
    }

    switch (ruta) {
      case 'pagos':
      case 'movimientos':
        return const MovimientosPage();
      case 'beneficios':
      case 'ofertas':
        return const BeneficiosPage();
    }

    // Sin `ruta`: se deduce del tipo, para las notificaciones antiguas que se
    // enviaron antes de que el servidor incluyera ese campo.
    switch (tipo) {
      case 'RECARGA':
      case 'RECARGA_SEDE':
        return const MovimientosPage();
      case 'DESCUENTO':
      case 'OFERTA':
        return const BeneficiosPage();
    }

    return null;
  }

  /// Detalle de la notificación cuando no hay pantalla a la que llevar.
  static Future<void> _mostrarDetalle(
    BuildContext ctx,
    Map<String, dynamic> data,
    String titulo,
    String cuerpo,
  ) async {
    const Color brandTeal = Color(0xFF1B6F81);

    // Datos que aportan algo al usuario. Los internos (`ruta`, `tipo`, ids)
    // se dejan fuera: no le dicen nada y ensucian la lectura.
    const ocultos = {
      'ruta',
      'tipo',
      'es_prueba',
      'sede_id',
      'cliente_id',
      'pedido_id',
      'click_action',
      // Ya se muestran como título y cuerpo del diálogo; repetirlos abajo
      // sería leer dos veces lo mismo.
      'titulo',
      'cuerpo',
      '_titulo',
      '_cuerpo',
      'imagen',
    };

    final extras = <MapEntry<String, String>>[
      for (final e in data.entries)
        if (!ocultos.contains(e.key.toLowerCase()) &&
            e.value != null &&
            e.value.toString().trim().isNotEmpty)
          MapEntry(_etiqueta(e.key), e.value.toString()),
    ];

    // En un mensaje de solo datos la app no recibe el bloque `notification`,
    // así que el texto puede venir únicamente dentro de los datos.
    final tituloFinal = titulo.trim().isNotEmpty
        ? titulo
        : (data['titulo'] ?? data['_titulo'] ?? '').toString();
    final cuerpoFinal = cuerpo.trim().isNotEmpty
        ? cuerpo
        : (data['cuerpo'] ?? data['_cuerpo'] ?? '').toString();

    final imagen = (data['imagen'] ?? '').toString().trim();

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tituloFinal.trim().isEmpty ? 'Notificación' : tituloFinal,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F3E47),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del aviso, si el panel adjuntó una. Va envuelta para
              // que un enlace roto no deje el diálogo a medias.
              if (imagen.startsWith('http')) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imagen,
                    fit: BoxFit.cover,
                    // Mientras baja la imagen se reserva su hueco con un
                    // indicador. Sin esto el diálogo aparecía sin nada y
                    // luego daba un salto al llegar la foto: parecía que
                    // había fallado justo antes de cargarse.
                    loadingBuilder: (contexto, hijo, progreso) {
                      if (progreso == null) return hijo;

                      final esperado = progreso.expectedTotalBytes;
                      return Container(
                        height: 150,
                        alignment: Alignment.center,
                        color: const Color(0xFFF1F5F7),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            // Con el tamaño total conocido, la rueda avanza
                            // de verdad en vez de girar sin decir nada.
                            value: esperado != null && esperado > 0
                                ? progreso.cumulativeBytesLoaded / esperado
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (cuerpoFinal.trim().isNotEmpty)
                Text(
                  cuerpoFinal,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (extras.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...extras.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.key}: ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: brandTeal,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.w800, color: brandTeal),
            ),
          ),
        ],
      ),
    );
  }

  static String _etiqueta(String clave) {
    switch (clave.toLowerCase()) {
      case 'pedido':
        return 'Pedido';
      case 'monto':
        return 'Monto';
      case 'saldo':
        return 'Saldo';
      case 'total':
        return 'Total';
      case 'puntos':
        return 'Puntos';
      case 'estado':
        return 'Estado del pedido';
      case 'cliente':
        return 'Cliente';
      case 'momento':
        return 'Enviada';
      default:
        final limpio = clave.replaceAll('_', ' ');
        if (limpio.isEmpty) return clave;
        return limpio[0].toUpperCase() + limpio.substring(1);
    }
  }
}
