import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
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
  final String _razonSocial = 'SPLASH BUBBLE';
  final String _direccionEmpresa = 'Calle. Sargento Lores #762, Iquitos, Loreto';
  final String _telefonoContacto = '+51 910 958 665';

  String _formatToppingsForUi(dynamic raw) {
    if (raw is List) {
      if (raw.isEmpty) return '';
      if (raw.first is String) {
        return raw
            .map((e) => e.toString())
            .where((name) => name.trim().isNotEmpty)
            .join(', ');
      }
      if (raw.first is Map) {
        return raw
            .map((e) => (e is Map ? (e['name'] ?? '').toString() : ''))
            .where((name) => name.trim().isNotEmpty)
            .join(', ');
      }
      return raw.map((e) => e.toString()).join(', ');
    }
    return '';
  }

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

  Future<void> _showPdfDescargadoSplash({
    required String titulo,
    required String mensaje,
    VoidCallback? onVer,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F3D4A), Color(0xFF128FA0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.picture_as_pdf,
                          color: Colors.white, size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'PDF listo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 44),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mensaje,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.65),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Row(
                    children: [
                      if (onVer != null)
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onVer();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF128FA0),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Ver PDF',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (onVer != null) const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF128FA0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cerrar',
                              style: TextStyle(
                                color: Color(0xFF128FA0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                final String toppingsText =
                    _formatToppingsForUi(toppingsRaw).trim();

                final List<String> details = [
                  if (size.isNotEmpty) size,
                  if (ice.isNotEmpty) ice,
                  if (toppingsText.isNotEmpty) toppingsText,
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
              if (tituloPdf.contains('Pedido')) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.yellow,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.amber),
                  ),
                  child: pw.Text(
                    'Atendemos pedidos de lunes a sábado de 9:00 a.m. a 7:00 p.m. Si realizas tu pedido fuera de este horario, se procesará en el siguiente día de atención.',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.brown),
                  ),
                ),
              ],
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
      await _showPdfDescargadoSplash(
        titulo: 'PDF descargado correctamente',
        mensaje: 'Tu comprobante se ha descargado con éxito.',
        onVer: () => _openPdf(tempFile.path),
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

  Future<void> _descargarPdfRecarga({
    required double monto,
    required String metodo,
    required String id,
    required String fechaSolo,
    required String horaSolo,
    required String cliente,
  }) async {
    try {
      final pdf = pw.Document();

      pw.Widget comprobanteWidget;
      Uint8List? pngBytes;

      final boundary =
          _comprobanteKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          pngBytes = byteData.buffer.asUint8List();
        }
      }

      if (pngBytes != null) {
        final imageProvider = pw.MemoryImage(pngBytes);
        comprobanteWidget = pw.Center(
          child: pw.Image(imageProvider, fit: pw.BoxFit.contain, width: 350),
        );
      } else {
        comprobanteWidget = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'Comprobante de Recarga',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Monto Recargado: S/ ${monto.toStringAsFixed(2)}'),
            pw.Text('Método de Pago: $metodo'),
            pw.Text('ID Transacción: ${id.isNotEmpty ? id : '-'}'),
            pw.Text('Fecha: $fechaSolo'),
            pw.Text('Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}'),
            pw.SizedBox(height: 10),
            pw.Text('Cliente: $cliente'),
          ],
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: comprobanteWidget,
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final String safeId = (id.isNotEmpty
              ? id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '')
              : 'recarga')
          .trim();
      final file = File('${dir.path}/comprobante_recarga_${safeId}.pdf');
      await file.writeAsBytes(await pdf.save(), flush: true);

      if (!mounted) return;
      await _showPdfDescargadoSplash(
        titulo: 'PDF de recarga descargado correctamente',
        mensaje: 'Tu comprobante de recarga se ha descargado con éxito.',
        onVer: () => _openPdf(file.path),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al descargar PDF de recarga.')),
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
    // Consideramos "Pedido" cuando viene de la app de pedidos o cuando
    // el método registrado es "Compra de productos" (caso historial).
    final esPedido =
      (orderId.isNotEmpty && rawItems.isNotEmpty) ||
      metodo.toLowerCase().contains('compra de productos');

    final monto = movimiento.monto;

    final String tituloPantalla = esRecarga
      ? 'Comprobante de Recarga'
      : (esPedido
        ? 'Comprobante de Pedido'
        : (esCompra ? 'Comprobante de Compra' : 'Comprobante de Consumo'));

    final String tituloPdf = esPedido
      ? 'Comprobante de Pedido'
      : (esCompra ? 'Comprobante de Compra' : 'Comprobante de Consumo');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tituloPantalla,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1B6F81),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
            const SizedBox(height: 14),

            // =========================
            // ✅ RECARGA (tu UI aquí si ya la tienes)
            // =========================
            if (esRecarga)
              Column(
                children: [
                  RepaintBoundary(
                    key: _comprobanteKey,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.black12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF0F3D4A), Color(0xFF128FA0)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.receipt_long, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Comprobante de recarga',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'BubbleSplash Wallet',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE3F2FD),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: const Icon(Icons.storefront,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _razonSocial,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _direccionEmpresa,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Contacto: $_telefonoContacto',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.black12),
                            const SizedBox(height: 12),
                            const Icon(Icons.check_circle,
                                size: 48, color: Colors.green),
                            const SizedBox(height: 8),
                            const Text(
                              '¡Recarga exitosa!',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Tu recarga se ha procesado correctamente.',
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Colors.black12),
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Monto recargado',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'S/ ${monto.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Colors.black12),
                            const SizedBox(height: 10),
                            const Text(
                              'Detalles del comprobante',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _rowDetalle(
                              icon: Icons.tag,
                              color: const Color(0xFFE80A5D),
                              text:
                                  'ID transacción: ${codigo.isNotEmpty ? codigo : '-'}',
                            ),
                            _rowDetalle(
                              icon: Icons.credit_card,
                              color: const Color(0xFFE80A5D),
                              text: 'Método de pago: ${metodo.isNotEmpty ? metodo : '-'}',
                            ),
                            _rowDetalle(
                              icon: Icons.calendar_today,
                              color: const Color(0xFFE80A5D),
                              text: 'Fecha: $fechaSolo',
                            ),
                            _rowDetalle(
                              icon: Icons.access_time,
                              color: const Color(0xFFE80A5D),
                              text:
                                  'Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}',
                            ),
                            _rowDetalle(
                              icon: Icons.person,
                              color: const Color(0xFFE80A5D),
                              text: 'Cliente: $cliente',
                            ),
                            const SizedBox(height: 12),
                            const _PerforatedEdge(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.download, color: Colors.white),
                              label: const Text(
                                'Descargar PDF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF128FA0),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _descargarPdfRecarga(
                                monto: monto,
                                metodo: metodo,
                                id: codigo.isNotEmpty ? codigo : referencia,
                                fechaSolo: fechaSolo,
                                horaSolo: horaSolo,
                                cliente: cliente,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.share, color: Colors.white),
                              label: const Text(
                                'Compartir',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE80A5D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                        'SPLASH BUBBLE',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        esPedido
                                            ? 'Comprobante de Pedido'
                                            : (esCompra
                                                ? 'Comprobante de Compra'
                                                : 'Comprobante de Consumo'),
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
                                  (map['toppings'] is List)
                                      ? map['toppings']
                                      : <dynamic>[];

                              final String toppingsText =
                                  _formatToppingsForUi(toppingsRaw).trim();

                              final List<String> details = [
                                if (size.isNotEmpty) size,
                                if (ice.isNotEmpty) ice,
                                if (toppingsText.isNotEmpty) toppingsText,
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

                            if (esPedido)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3CD),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFEEBA)),
                                ),
                                child: const Text(
                                  'Atendemos pedidos de lunes a sábado de 9:00 a.m. a 7:00 p.m. Si realizas tu pedido fuera de este horario, se procesará en el siguiente día de atención.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF856404),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                            // Borde decorativo tipo boleta (triángulos)
                            const _PerforatedEdge(),
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
                              icon: const Icon(Icons.download, color: Colors.white),
                              label: const Text(
                                'Descargar PDF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF128FA0),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                              icon: const Icon(Icons.share, color: Colors.white),
                              label: const Text(
                                'Compartir',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE80A5D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                    backgroundColor: const Color(0xFF128FA0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
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

// ===============================
// 🎟️ Borde tipo boleta (triángulos)
// ===============================
class _PerforatedEdge extends StatelessWidget {
  const _PerforatedEdge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 14,
      child: CustomPaint(
        painter: _PerforatedEdgePainter(
          color: Colors.grey.shade300,
        ),
      ),
    );
  }
}

class _PerforatedEdgePainter extends CustomPainter {
  final Color color;

  _PerforatedEdgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double triangleWidth = 18;
    final double triangleHeight = size.height;

    for (double x = 0; x < size.width; x += triangleWidth) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + triangleWidth / 2, triangleHeight)
        ..lineTo(x + triangleWidth, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerforatedEdgePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}