import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class ReceiptPage extends StatefulWidget {
  final List<Map<String, dynamic>> finalPedidos;
  final String dineOption;
  final double subtotal;

  // Si el pago se ejecutó en otra pantalla (p.ej. Carrito) y este comprobante
  // solo confirma, podemos aplicar el descuento/movimiento local al entrar.
  final bool applyWalletDeduction;

  // Datos opcionales provenientes del backend de pedidos
  final String? backendOrderNumber;
  final String? backendDate;
  final String? backendTime;
  final bool alreadyPaid;

  // Se genera automáticamente un ID de pedido aleatorio
  late final String orderId = (Random().nextInt(900000) + 100000)
      .toString(); // 6 dígitos aleatorios

  // Fecha y hora actual
  final String date =
      "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";
  final String time =
      "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";

  ReceiptPage({
    super.key,
    required this.finalPedidos,
    required this.dineOption,
    required this.subtotal,
    this.applyWalletDeduction = false,
    this.backendOrderNumber,
    this.backendDate,
    this.backendTime,
    this.alreadyPaid = false,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final GlobalKey _comprobanteKey = GlobalKey();
  bool _pagado = false;
  String? _pdfPath;
  String? _nombreCliente;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late final String _codigoCompra;
  bool _mediaStoreReady = false;
  bool _walletApplied = false;

  // Datos de la empresa
  final String _razonSocial = 'BUBBLE TEA BUBBLESPLASH';
  final String _direccionEmpresa = 'Calle. Sargento Lores, Iquitos, Loreto';
  final String _telefonoContacto = '+51 999 999 999';

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  /// Total real a cobrar: suma de (precio unitario * cantidad)
  /// Usamos los ítems para evitar inconsistencias si `widget.subtotal` viene mal.
  double get total {
    return widget.finalPedidos.fold<double>(0.0, (sum, item) {
      final unit = _asDouble(item['price']);
      final qty = _asInt(item['quantity'] ?? 1);
      final safeQty = qty <= 0 ? 1 : qty;
      return sum + (unit * safeQty);
    });
  }

  // Para compatibilidad visual, si `subtotal` viene, se usa solo si coincide.
  // En caso contrario, mostramos el total calculado por ítems.
  double get subtotal {
    final s = widget.subtotal;
    if ((s - total).abs() <= 0.01) return s;
    return total;
  }

  @override
  void initState() {
    super.initState();

    // Si el pedido ya fue pagado en el backend, reflejarlo en la UI
    _pagado = widget.alreadyPaid;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nombreCliente =
          (user.displayName != null && user.displayName!.trim().isNotEmpty)
          ? user.displayName
          : (user.email ?? 'Cliente');
    } else {
      _nombreCliente = 'Cliente';
    }

    // Código de compra distinto al número de pedido
    _codigoCompra = 'CP-${Random().nextInt(900000) + 100000}';

    _initNotifications();

    // Si ya viene pagado desde el carrito, aplicar efectos locales una sola vez.
    if (widget.alreadyPaid && widget.applyWalletDeduction) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _registrarCompraLocal();
      });
    }
  }

  Future<void> _registrarCompraLocal() async {
    if (_walletApplied) return;
    _walletApplied = true;

    // Registrar movimiento de compra en el historial del usuario
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final String? keyMovs = user != null ? 'movimientos_${user.uid}' : null;
    final List<String> data = keyMovs != null
        ? (prefs.getStringList(keyMovs) ?? [])
        : <String>[];

    final movimiento = {
      'tipo': 'gasto',
      'monto': total,
      'metodo': 'Compra de productos',
      'referencia':
          'Pedido ${widget.orderId} (${widget.finalPedidos.length} productos)',
      'fecha': '${widget.date} ${widget.time}',
      'codigo': _codigoCompra,
      // Datos adicionales para poder reconstruir la boleta en Movimientos
      'orderId': widget.orderId,
      'dineOption': widget.dineOption,
      'items': widget.finalPedidos,
      'cliente': _nombreCliente ?? 'Cliente',
    };

    data.insert(0, jsonEncode(movimiento));
    if (keyMovs != null) {
      await prefs.setStringList(keyMovs, data);
    }

    // Descontar del saldo disponible (si el saldo es menor, se permite ir a cero)
    final String? keySaldo = user != null ? 'saldo_${user.uid}' : null;
    final double saldoActual =
        keySaldo != null ? (prefs.getDouble(keySaldo) ?? 0.0) : 0.0;
    final nuevoSaldo = (saldoActual - total).clamp(0.0, double.infinity);
    if (keySaldo != null) {
      await prefs.setDouble(keySaldo, nuevoSaldo);
    }

    // Acumular puntos por compra: 1 punto por cada sol del total
    final String? keyPuntos = user != null ? 'puntos_${user.uid}' : null;
    final int puntosActuales =
        keyPuntos != null ? (prefs.getInt(keyPuntos) ?? 0) : 0;
    final int puntosGanados = total.floor();
    if (puntosGanados > 0 && keyPuntos != null) {
      await prefs.setInt(keyPuntos, puntosActuales + puntosGanados);
    }

    // Limpiar el carrito persistido una vez realizado el pago
    await prefs.remove('cart_pedidos');
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) return;
        await _openPdf(payload);
      },
    );

    // Si la app estaba cerrada y se abrió desde la notificación, abrir el PDF.
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    final didLaunchFromNotification = details?.didNotificationLaunchApp ?? false;
    final payload = details?.notificationResponse?.payload;
    if (didLaunchFromNotification && payload != null && payload.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPdf(payload);
      });
    }
  }

  Future<void> _openPdf(String pathOrUri) async {
    try {
      final target = pathOrUri.trim();
      if (target.isEmpty) return;

      // MediaStore suele devolver content://...; OpenFile no siempre lo abre bien.
      if (Platform.isAndroid && target.startsWith('content://')) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: target,
          type: 'application/pdf',
          flags: <int>[
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
          ],
        );

        final canOpen = (await intent.canResolveActivity()) == true;
        if (!mounted) return;
        if (!canOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró una app para abrir PDFs.'),
            ),
          );
          return;
        }

        await intent.launch();
        return;
      }

      final result = await OpenFile.open(target, type: 'application/pdf');
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (result.message != null && result.message!.trim().isNotEmpty)
                  ? result.message!
                  : 'No se pudo abrir el PDF en este dispositivo.',
            ),
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

  Future<Directory> _resolvePdfOutputDirectory() async {
    if (Platform.isAndroid) {
      final downloadsDirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      final downloadsDir = (downloadsDirs != null && downloadsDirs.isNotEmpty)
          ? downloadsDirs.first
          : null;
      if (downloadsDir != null) {
        return downloadsDir;
      }

      final legacyDownloads = Directory('/storage/emulated/0/Download');
      if (await legacyDownloads.exists()) {
        return legacyDownloads;
      }

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return externalDir;
      }
    }

    return getApplicationDocumentsDirectory();
  }

  Future<void> _simularPago() async {
    setState(() => _pagado = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('¡Pago realizado con éxito!')));

    await _registrarCompraLocal();

    final int puntosGanados = total.floor();
    if (!mounted) return;
    if (puntosGanados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Has ganado $puntosGanados puntos por tu compra.'),
        ),
      );
    }
  }

  Future<File> _generarPdf() async {
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
                'Comprobante de Pedido',
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
              if (_nombreCliente != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6.0),
                  child: pw.Text(
                    'Cliente: $_nombreCliente',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Pedido #: ${widget.backendOrderNumber ?? widget.orderId}',
              ),
              pw.Text('Fecha: ${widget.backendDate ?? widget.date}'),
              pw.Text('Hora: ${widget.backendTime ?? widget.time}'),
              pw.Text('Tipo de consumo: ${widget.dineOption}'),
              pw.Divider(),
              pw.Text(
                'Productos:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              ...widget.finalPedidos.map((item) {
                final String name = item['name'] ?? 'Producto';
                final int quantity = (item['quantity'] ?? 1) as int;
                final double price = (item['price'] is num)
                    ? (item['price'] as num).toDouble()
                    : 0.0;
                final String size = item['size'] ?? '';
                final String ice = item['ice'] ?? '';
                final List<dynamic> rawToppings = (item['toppings'] is List)
                    ? item['toppings']
                    : [];
                final List<String> toppings = rawToppings
                    .map((e) => e.toString())
                    .toList();
                final List<String> details = [
                  if (size.isNotEmpty) size,
                  if (ice.isNotEmpty) ice,
                  ...toppings,
                ];
                return pw.Column(
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
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                  ],
                );
              }),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'S/. ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Código de compra: $_codigoCompra',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Generar SIEMPRE en una ruta temporal (requisito para MediaStore.saveFile)
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'boleta_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<String> _guardarPdfEnDescargas(File tempPdfFile) async {
    // Android: guardar en Descargas via MediaStore (visible para el sistema)
    if (Platform.isAndroid) {
      try {
        if (!_mediaStoreReady) {
          await MediaStore.ensureInitialized();
          MediaStore.appFolder = 'BubblesSplash';
          _mediaStoreReady = true;
        }

        final mediaStore = MediaStore();
        final saveInfo = await mediaStore.saveFile(
          tempFilePath: tempPdfFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
          // Guardar en el root de Descargas (más fácil de encontrar)
          relativePath: FilePath.root,
        );

        final uri = saveInfo?.uri;
        if (uri != null) {
          final uriString = uri.toString();
          final resolvedPath = await mediaStore.getFilePathFromUri(
            uriString: uriString,
          );
          return (resolvedPath != null && resolvedPath.trim().isNotEmpty)
              ? resolvedPath
              : uriString;
        }

        // Si por algún motivo MediaStore no devolvió info, usar temp como último recurso.
        return tempPdfFile.path;
      } on MissingPluginException {
        // Suele pasar cuando se agregó el plugin y se hizo hot-reload/hot-restart,
        // o cuando la app instalada todavía no incluye el plugin.
        // Fallback: guardar en un directorio accesible por la app (sin romper UX).
        final output = await _resolvePdfOutputDirectory();
        if (!await output.exists()) {
          await output.create(recursive: true);
        }
        final fileName = Uri.parse(tempPdfFile.path).pathSegments.last;
        final dest = File('${output.path}/$fileName');
        await tempPdfFile.copy(dest.path);
        return dest.path;
      }
    }

    // Otras plataformas: copiar a un directorio razonable.
    final output = await _resolvePdfOutputDirectory();
    if (!await output.exists()) {
      await output.create(recursive: true);
    }
    final fileName = Uri.parse(tempPdfFile.path).pathSegments.last;
    final dest = File('${output.path}/$fileName');
    await tempPdfFile.copy(dest.path);
    return dest.path;
  }

  Future<void> _descargarPdf() async {
    try {
      final tempFile = await _generarPdf();
      final exists = await tempFile.exists();
      if (!exists) throw Exception('No se pudo generar el PDF.');

      final openablePathOrUri = await _guardarPdfEnDescargas(tempFile);

      if (!mounted) return;
      setState(() => _pdfPath = openablePathOrUri);

      // Snackbar dentro de la app (sin mostrar ruta) + acción para abrir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF descargado correctamente.'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _openPdf(openablePathOrUri),
          ),
        ),
      );

      // Notificación en la barra de notificaciones (Android)
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'pdf_download_channel',
            'Descargas de comprobantes',
            channelDescription:
                'Notificaciones cuando se descarga un comprobante en PDF',
            importance: Importance.high,
            priority: Priority.high,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1000000),
        'Comprobante descargado',
        'Toca aquí para ver tu PDF.',
        notificationDetails,
        payload: openablePathOrUri,
      );
    } catch (e) {
      if (!mounted) return;
      final message = (e is MissingPluginException)
          ? 'Tu app necesita reiniciarse para activar Descargas. Detén la app y ejecútala de nuevo.'
          : 'Error al descargar PDF.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _compartirComprobanteImagen() async {
    try {
      final renderObject = _comprobanteKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo capturar la imagen del comprobante.'),
          ),
        );
        return;
      }

      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/comprobante_${widget.orderId}.png',
      ).create();
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '¡Aquí está tu comprobante Bubble Tea!');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al compartir imagen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Comprobante de Pedido',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
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
                      // 🔹 Encabezado empresa + logo
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
                                Text(
                                  _razonSocial,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Comprobante de Pedido',
                                  style: TextStyle(
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

                      // 🔹 Datos de la empresa
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Color(0xFF757575),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _direccionEmpresa,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 18,
                            color: Color(0xFF757575),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _telefonoContacto,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 20),

                      // 🔹 Datos del cliente
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: Color(0xFF1B6F81),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cliente: ${_nombreCliente ?? 'Cliente'}',
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

                      // 🔹 Información general
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido #: ${widget.backendOrderNumber ?? widget.orderId}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fecha: ${widget.backendDate ?? widget.date}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Hora: ${widget.backendTime ?? widget.time}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // 🔹 Tipo de consumo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF0D6EFD)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            widget.dineOption,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D6EFD),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🔹 Lista de productos
                      ...widget.finalPedidos.map((item) {
                        final String name = item['name'] ?? 'Producto';
                        final int quantity = (item['quantity'] ?? 1) as int;
                        final double price = (item['price'] is num)
                            ? (item['price'] as num).toDouble()
                            : 0.0;

                        final String size = item['size'] ?? '';
                        final String ice = item['ice'] ?? '';
                        final List<dynamic> rawToppings =
                            (item['toppings'] is List) ? item['toppings'] : [];
                        final List<String> toppings = rawToppings
                            .map((e) => e.toString())
                            .toList();

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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$quantity x $name',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'S/. ${(price * quantity).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (details.isNotEmpty)
                                Text(
                                  details.join(', '),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),

                      const Divider(height: 25),

                      // 🔹 Totales
                      _buildPriceRow('TOTAL', total, isTotal: true),

                      const SizedBox(height: 40),

                      // Botón de pago (solo dentro del comprobante)
                      if (!_pagado)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.payment,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Pagar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0D6EFD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _simularPago,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 🔹 Código de compra
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Text(
                              'Código de compra',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _codigoCompra,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
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

            // 🔹 Botones de acciones posteriores al pago (fuera del comprobante)
            if (_pagado) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 6,
                ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _descargarPdf,
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
              const SizedBox(height: 8),
            ],

            // 🔹 Botón cerrar (fuera del comprobante para que no salga en la captura)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6961),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Fila de precios (reutilizable)
  Widget _buildPriceRow(String label, double amount, {required bool isTotal}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF0D6EFD) : Colors.black,
            ),
          ),
          Text(
            'S/. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF0D6EFD) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
