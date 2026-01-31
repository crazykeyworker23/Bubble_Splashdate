import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:ui' as ui;

import 'movimiento.dart';

class DetalleMovimientoPage extends StatefulWidget {
  final Movimiento movimiento;
  final Map<String, dynamic>? datosAdicionales;

  const DetalleMovimientoPage({
    super.key,
    required this.movimiento,
    this.datosAdicionales,
  });

  @override
  State<DetalleMovimientoPage> createState() => _DetalleMovimientoPageState();
}

class _DetalleMovimientoPageState extends State<DetalleMovimientoPage> {
  final GlobalKey _comprobanteKey = GlobalKey();
  String? _pdfPath;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Datos de la empresa
  final String _razonSocial = 'BUBBLE TEA BUBBLESPLASH';
  final String _direccionEmpresa = 'Calle. Sargento Lores, Iquitos, Loreto';
  final String _telefonoContacto = '+51 999 999 999';

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: initAndroid);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) return;
        await _openPdf(payload);
      },
    );
  }

  Future<void> _openPdf(String pathOrUri) async {
    try {
      final target = pathOrUri.trim();
      if (target.isEmpty) return;

      final result = await OpenFile.open(target, type: 'application/pdf');

      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el PDF en este dispositivo.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF: $e')),
      );
    }
  }

  Future<File> _generarPdf({
    required List<dynamic> rawItems,
    required String cliente,
    required String orderId,
    required String fechaSolo,
    required String horaSolo,
    required String dineOption,
    required double monto,
    required String codigo,
    required String tituloPdf,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _razonSocial,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                tituloPdf,
                style: pw.TextStyle(fontSize: 14, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Dirección: $_direccionEmpresa',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.Text(
                'Contacto: $_telefonoContacto',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6.0),
                child: pw.Text(
                  'Cliente: $cliente',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Pedido #: ${orderId.isNotEmpty ? orderId : '-'}'),
              pw.Text('Fecha: $fechaSolo'),
              pw.Text('Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}'),
              if (dineOption.isNotEmpty)
                pw.Text('Tipo de consumo: $dineOption'),
              pw.Divider(),
              pw.Text('Productos:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),

              ...rawItems.map((item) {
                final map = item as Map<String, dynamic>;
                final String name = (map['name'] ?? 'Producto').toString();

                final int quantity = (map['quantity'] is num)
                    ? (map['quantity'] as num).toInt()
                    : 1;

                final double price = (map['price'] is num)
                    ? (map['price'] as num).toDouble()
                    : 0.0;

                final String size = (map['size'] ?? '').toString();
                final String ice = (map['ice'] ?? '').toString();

                final List<dynamic> toppingsRaw =
                    (map['toppings'] is List) ? map['toppings'] : <dynamic>[];
                final List<String> toppings =
                    toppingsRaw.map((e) => e.toString()).toList();

                final List<String> details = [
                  if (size.isNotEmpty) size,
                  if (ice.isNotEmpty) ice,
                  ...toppings,
                ];

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('$quantity x $name'),
                          pw.Text('S/. ${(price * quantity).toStringAsFixed(2)}'),
                        ],
                      ),
                      if (details.isNotEmpty)
                        pw.Text(
                          details.join(', '),
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                        ),
                    ],
                  ),
                );
              }).toList(),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('S/. ${monto.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Código: ${codigo.isNotEmpty ? codigo : '-'}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'comprobante_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<void> _descargarPdf({
    required List<dynamic> rawItems,
    required String cliente,
    required String orderId,
    required String fechaSolo,
    required String horaSolo,
    required String dineOption,
    required double monto,
    required String codigo,
    required String tituloPdf,
  }) async {
    try {
      final tempFile = await _generarPdf(
        rawItems: rawItems,
        cliente: cliente,
        orderId: orderId,
        fechaSolo: fechaSolo,
        horaSolo: horaSolo,
        dineOption: dineOption,
        monto: monto,
        codigo: codigo,
        tituloPdf: tituloPdf,
      );

      final exists = await tempFile.exists();
      if (!exists) throw Exception('No se pudo generar el PDF.');

      setState(() => _pdfPath = tempFile.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF descargado correctamente.'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _openPdf(tempFile.path),
          ),
        ),
      );

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'pdf_download_channel',
        'Descargas de comprobantes',
        channelDescription: 'Notificaciones de descarga de comprobantes PDF',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1000000),
        'Comprobante descargado',
        'Toca aquí para ver tu PDF.',
        notificationDetails,
        payload: tempFile.path,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al descargar PDF.')),
      );
    }
  }

  Future<void> _compartirComprobanteImagen() async {
    try {
      final renderObject = _comprobanteKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo capturar la imagen del comprobante.'),
          ),
        );
        return;
      }

      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('No se pudo convertir a PNG.');

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/comprobante.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)],
          text: '¡Aquí está tu comprobante Bubble Tea!');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir imagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final movimiento = widget.movimiento;
    final raw = widget.datosAdicionales ?? <String, dynamic>{};

    final codigo = (raw['codigo'] ?? '').toString();
    final metodo = (raw['metodo'] ?? '').toString();
    final referencia = (raw['referencia'] ?? '').toString();
    final fechaCruda = (raw['fecha'] ?? movimiento.fecha).toString();
    final orderId = (raw['orderId'] ?? '').toString();
    final dineOption = (raw['dineOption'] ?? '').toString();
    final cliente = (raw['cliente'] ?? 'Cliente').toString();

    final List<dynamic> rawItems =
        raw['items'] is List ? (raw['items'] as List) : const [];

    String fechaSolo = fechaCruda;
    String horaSolo = '';
    if (fechaCruda.contains(' ')) {
      final partes = fechaCruda.split(' ');
      if (partes.isNotEmpty) fechaSolo = partes[0];
      if (partes.length > 1) horaSolo = partes[1];
    }

    final esRecarga = movimiento.tipo == 'recarga';
    final esGasto = movimiento.tipo == 'gasto';
    final esCompra = movimiento.tipo == 'compra';

    final monto = movimiento.monto;

    final String tituloPantalla = esRecarga
        ? 'Comprobante de Recarga'
        : (esCompra ? 'Comprobante de Compra' : 'Comprobante de Consumo');

    final String tituloPdf = esCompra ? 'Comprobante de Compra' : 'Comprobante de Consumo';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tituloPantalla,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1B6F81),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // =========================
            // ✅ RECARGA (tu UI aquí si ya la tienes)
            // =========================
            if (esRecarga)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Recarga exitosa",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "S/ ${monto.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text("Código: ${codigo.isNotEmpty ? codigo : '-'}"),
                      if (metodo.isNotEmpty) Text("Método: $metodo"),
                      Text("Fecha: $fechaSolo"),
                      Text("Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}"),
                      Text("Cliente: $cliente"),
                    ],
                  ),
                ),
              ),

            // =========================
            // ✅ COMPRA o GASTO (CON ITEMS => BOLETA)
            // =========================
            if ((esGasto || esCompra) && rawItems.isNotEmpty)
              Column(
                children: [
                  RepaintBoundary(
                    key: _comprobanteKey,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Encabezado
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B6F81),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.local_cafe_outlined,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'BUBBLE TEA BUBBLESPLASH',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        esCompra ? 'Comprobante de Compra' : 'Comprobante de Consumo',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 18, color: Color(0xFF757575)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _direccionEmpresa,
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined,
                                    size: 18, color: Color(0xFF757575)),
                                const SizedBox(width: 6),
                                Text(
                                  _telefonoContacto,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 20),

                            Row(
                              children: [
                                const Icon(Icons.person_outline, color: Color(0xFF1B6F81)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cliente: $cliente',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pedido #: ${orderId.isNotEmpty ? orderId : '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Fecha: $fechaSolo',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),

                            const SizedBox(height: 15),

                            if (dineOption.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF0D6EFD)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    dineOption,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D6EFD),
                                    ),
                                  ),
                                ),
                              ),

                            if (dineOption.isNotEmpty) const SizedBox(height: 20),

                            ...rawItems.map((item) {
                              final map = item as Map<String, dynamic>;
                              final String name = (map['name'] ?? 'Producto').toString();

                              final int quantity = (map['quantity'] is num)
                                  ? (map['quantity'] as num).toInt()
                                  : 1;

                              final double price = (map['price'] is num)
                                  ? (map['price'] as num).toDouble()
                                  : 0.0;

                              final String size = (map['size'] ?? '').toString();
                              final String ice = (map['ice'] ?? '').toString();

                              final List<dynamic> toppingsRaw =
                                  (map['toppings'] is List) ? map['toppings'] : <dynamic>[];

                              final List<String> toppings =
                                  toppingsRaw.map((e) => e.toString()).toList();

                              final List<String> details = [
                                if (size.isNotEmpty) size,
                                if (ice.isNotEmpty) ice,
                                ...toppings,
                              ];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$quantity x $name',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'S/. ${(price * quantity).toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    if (details.isNotEmpty)
                                      Text(
                                        details.join(', '),
                                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),

                            const Divider(height: 25),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D6EFD),
                                  ),
                                ),
                                Text(
                                  'S/. ${monto.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D6EFD),
                                  ),
                                ),
                              ],
                            ),

                            // ✅ Wallet SOLO para GASTO (NUNCA para COMPRA)
                            if (esGasto)
                              (() {
                                final wallet = raw['wallet'] is num
                                    ? (raw['wallet'] as num).toDouble()
                                    : null;
                                if (wallet != null && wallet > 0) {
                                  return Column(
                                    children: [
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.account_balance_wallet,
                                              color: Color(0xFF0D6EFD)),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Monto descontado de la wallet:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF0D6EFD),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '- S/. ${wallet.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF0D6EFD),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              })(),

                            const SizedBox(height: 16),

                            Align(
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Text(
                                    'Código',
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    codigo.isNotEmpty ? codigo : '-',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                      color: Color(0xFF42A5F5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.download),
                              label: const Text('Descargar PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF42A5F5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _descargarPdf(
                                rawItems: rawItems,
                                cliente: cliente,
                                orderId: orderId,
                                fechaSolo: fechaSolo,
                                horaSolo: horaSolo,
                                dineOption: dineOption,
                                monto: monto,
                                codigo: codigo,
                                tituloPdf: tituloPdf,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text('Compartir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF66BB6A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _compartirComprobanteImagen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // =========================
            // ✅ GASTO (SIN ITEMS)
            // =========================
            if (esGasto && rawItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: (metodo == 'Pago QR')
                    ? _comprobantePagoQr(
                        monto: monto,
                        codigo: codigo,
                        fechaSolo: fechaSolo,
                        horaSolo: horaSolo,
                        cliente: cliente,
                      )
                    : _comprobanteGastoSimple(
                        monto: monto,
                        metodo: metodo,
                        referencia: referencia,
                        concepto: movimiento.titulo,
                      ),
              ),

            const SizedBox(height: 10),

            // ✅ Botón Cerrar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _rowDetalle({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _comprobantePagoQr({
    required double monto,
    required String codigo,
    required String fechaSolo,
    required String horaSolo,
    required String cliente,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.qr_code_2, color: Colors.black87),
                SizedBox(width: 8),
                Text(
                  "Comprobante de pago QR",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 8),
          const Text(
            "¡Pago QR exitoso!",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tu pago mediante código QR se ha procesado correctamente.",
            style: TextStyle(color: Colors.black54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),

          Text("Monto pagado",
              style: TextStyle(color: Colors.grey[800], fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            "S/ ${monto.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),

          _rowDetalle(
            icon: Icons.tag,
            color: const Color(0xFFE80A5D),
            text: "Código de operación: ${codigo.isNotEmpty ? codigo : '-'}",
          ),
          _rowDetalle(
            icon: Icons.calendar_today,
            color: const Color(0xFFE80A5D),
            text: "Fecha: $fechaSolo",
          ),
          _rowDetalle(
            icon: Icons.access_time,
            color: const Color(0xFFE80A5D),
            text: "Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}",
          ),
          _rowDetalle(
            icon: Icons.person,
            color: const Color(0xFFE80A5D),
            text: "Cliente: $cliente",
          ),
        ],
      ),
    );
  }

  Widget _comprobanteGastoSimple({
    required double monto,
    required String metodo,
    required String referencia,
    required String concepto,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monto Consumido:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          Text(
            'S/ ${monto.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, color: Colors.blue),
          ),
          const SizedBox(height: 10),
          if (metodo.isNotEmpty) Text('Método: $metodo'),
          if (referencia.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Referencia: $referencia'),
          ],
          if (metodo.isEmpty && referencia.isEmpty) Text('Concepto: $concepto'),
          const SizedBox(height: 10),
          const Text('¡Gracias por tu consumo!', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}