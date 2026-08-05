import 'package:flutter/material.dart';

import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';

import 'package:bubblesplash/services/movimientos_service.dart';

import 'detail_movimiento_page.dart';
import 'movimiento.dart' as simple;

class MovimientosPage extends StatefulWidget {
  /// Número de pedido que debe abrirse en cuanto termine de cargar.
  ///
  /// Lo usa la notificación de «compra realizada»: llevar al cliente a la
  /// lista y que busque él su compra entre las demás es dejarle el trabajo a
  /// medias, sobre todo si tiene decenas de movimientos.
  final String? abrirPedido;

  const MovimientosPage({super.key, this.abrirPedido});

  @override
  State<MovimientosPage> createState() => _MovimientosPageState();
}

class _MovimientosPageState extends State<MovimientosPage> {
  List<Map<String, dynamic>> movimientosRaw = [];

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
  }

  /// Carga el historial ya unificado.
  ///
  /// Toda la lógica —consultar el backend, leer el detalle guardado en el
  /// teléfono y cruzarlos sin repetir la compra— vive en `MovimientosService`,
  /// que es también el que usa `PagosPage`. Antes cada pantalla tenía su
  /// propia copia del algoritmo y ambas mostraban cada compra dos veces.
  Future<void> _cargarMovimientos() async {
    final lista = await MovimientosService.cargar();
    if (!mounted) return;
    setState(() => movimientosRaw = lista);

    if (widget.abrirPedido != null) _abrirPedidoIndicado();
  }

  /// Abre el detalle del pedido que pidió la notificación.
  ///
  /// Se hace tras cargar, y se compara con lo que haya: el número puede venir
  /// como `PED-0007` o solo `0007` según quién generó el aviso.
  void _abrirPedidoIndicado() {
    final buscado = (widget.abrirPedido ?? '').trim().toUpperCase();
    if (buscado.isEmpty) return;

    // Se compara contra los campos que sí identifican al pedido: el número que
    // se le enseña al cliente y el id interno. `codigo` y `referencia` son del
    // MOVIMIENTO, no del pedido, así que no sirven aquí.
    Map<String, dynamic>? encontrado;
    for (final m in movimientosRaw) {
      final numero = (m['orderNumber'] ?? '').toString().trim().toUpperCase();
      final id = (m['orderId'] ?? '').toString().trim();

      if ((numero.isNotEmpty && numero == buscado) ||
          (id.isNotEmpty && id == buscado)) {
        encontrado = m;
        break;
      }
    }

    // Si no aparece —un pedido muy antiguo, o el número no cuadra— se deja la
    // lista abierta en vez de no hacer nada: al menos está en el sitio.
    if (encontrado == null) return;

    final datosAdicionales = Map<String, dynamic>.from(encontrado);
    if ((encontrado['tipo'] ?? '') == 'gasto' &&
        datosAdicionales['items'] == null) {
      datosAdicionales['items'] = <dynamic>[];
    }

    final monto = (encontrado['monto'] is num)
        ? (encontrado['monto'] as num).toDouble()
        : double.tryParse(encontrado['monto'].toString()) ?? 0.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleMovimientoPage(
            movimiento: simple.Movimiento(
              // Mismo título que en la lista, para que la pantalla que se abre
              // sea idéntica a la que saldría tocando la fila.
              titulo: (encontrado!['tipo'] ?? '') == 'recarga'
                  ? 'RECARGA'
                  : 'COMPRA',
              monto: monto,
              tipo: (encontrado['tipo'] ?? '').toString(),
              fecha: (encontrado['fecha'] ?? '').toString(),
            ),
            datosAdicionales: datosAdicionales,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: movimientosRaw.isEmpty
          ? const Center(child: Text('No hay movimientos'))
          : ListView.builder(
              itemCount: movimientosRaw.length,
              itemBuilder: (context, i) {
                final m = movimientosRaw[i];
                final tipo = (m['tipo'] ?? '').toString();
                final metodoRaw = (m['metodo'] ?? '').toString();
                final referencia = (m['referencia'] ?? '').toString();
                final fecha = (m['fecha'] ?? '').toString();
                final codigo = (m['codigo'] ?? '').toString();
                final monto = (m['monto'] is num)
                    ? (m['monto'] as num).toDouble()
                    : double.tryParse(m['monto'].toString()) ?? 0.0;


                // Unificar: solo mostrar COMPRA y RECARGA
                String tituloBase;
                if (tipo == 'recarga') {
                  tituloBase = 'RECARGA';
                } else {
                  tituloBase = 'COMPRA';
                }

                // Normalizar el texto del método que se muestra al usuario.
                // Si el backend devuelve algo como "Pago de pedido" pero en la
                // app lo manejamos como una compra normal, mostramos
                // "Compra de productos" para evitar confusión.
                String metodoUi = metodoRaw;
                if (tituloBase == 'COMPRA' &&
                    metodoUi.toLowerCase().contains('pedido')) {
                  metodoUi = 'Compra de productos';
                }

                // Forzar items vacío para todos los gastos si no existe, para mostrar comprobante detallado
                final datosAdicionales = Map<String, dynamic>.from(m)
                  ..['metodo'] = metodoUi;
                if (tipo == 'gasto' && datosAdicionales['items'] == null) {
                  datosAdicionales['items'] = <dynamic>[];
                }
                // Solo mostrar COMPRA y RECARGA en la lista
                if (tituloBase == 'COMPRA' || tituloBase == 'RECARGA') {
                  return ListTile(
                    leading: Icon(
                      tituloBase == 'RECARGA' ? Icons.add_circle : Icons.payment,
                      color: tituloBase == 'RECARGA' ? Colors.green : Colors.blue,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$tituloBase: S/. ${monto.toStringAsFixed(2)}'),
                        // Mostrar solo si hay un descuento real de la wallet
                        if (tituloBase == 'COMPRA')
                          (() {
                            final wallet = m['wallet'] is num ? (m['wallet'] as num).toDouble() : null;
                            if (wallet != null && wallet > 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF0D6EFD)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Descontado de wallet: -S/. ${wallet.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF0D6EFD)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          })(),
                      ],
                    ),
                    subtitle: Text(
                      '$metodoUi | $fecha\nRef: $referencia',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          codigo,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (tituloBase == 'RECARGA')
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download_rounded, color: Colors.green),
                                  tooltip: 'Ver comprobante',
                                  onPressed: () async {
                                    try {
                                      final dir = await getApplicationDocumentsDirectory();
                                      final rawId = (m['referencia'] ?? '').toString();
                                      final idConMov = rawId.startsWith('MOV') ? rawId : 'MOV$rawId';

                                      // Intentar primero con el formato nuevo (MOV<id>), luego con el id crudo y por último el genérico
                                      final candidates = <File>[
                                        File("${dir.path}/comprobante_recarga_$idConMov.pdf"),
                                        File("${dir.path}/comprobante_recarga_$rawId.pdf"),
                                        File("${dir.path}/comprobante_recarga.pdf"),
                                      ];

                                      File? found;
                                      for (final f in candidates) {
                                        if (await f.exists()) {
                                          found = f;
                                          break;
                                        }
                                      }

                                      if (found != null) {
                                        await OpenFile.open(found.path);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('No se encontró el comprobante PDF.')),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al abrir comprobante: $e')),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.blue),
                                  tooltip: 'Compartir comprobante',
                                  onPressed: () async {
                                    try {
                                      final dir = await getApplicationDocumentsDirectory();
                                      final rawId = (m['referencia'] ?? '').toString();
                                      final idConMov = rawId.startsWith('MOV') ? rawId : 'MOV$rawId';

                                      final candidates = <File>[
                                        File("${dir.path}/comprobante_recarga_$idConMov.pdf"),
                                        File("${dir.path}/comprobante_recarga_$rawId.pdf"),
                                        File("${dir.path}/comprobante_recarga.pdf"),
                                      ];

                                      File? found;
                                      for (final f in candidates) {
                                        if (await f.exists()) {
                                          found = f;
                                          break;
                                        }
                                      }

                                      if (found != null) {
                                        await Share.shareXFiles([XFile(found.path)], text: 'Comprobante de recarga');
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('No se encontró el comprobante PDF para compartir.')),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al compartir comprobante: $e')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      final simpleMovimiento = simple.Movimiento(
                        titulo: tituloBase,
                        monto: monto,
                        tipo: tipo,
                        fecha: fecha,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleMovimientoPage(
                            movimiento: simpleMovimiento,
                            datosAdicionales: datosAdicionales,
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
    );
  }
}
