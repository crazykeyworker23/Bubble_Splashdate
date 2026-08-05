import 'dart:math';
import 'dart:io';
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
import 'package:bubblesplash/services/sede_service.dart';
import 'package:bubblesplash/services/movimientos_service.dart';
import 'package:bubblesplash/utils/tamanos.dart';

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

  /// Sede que emite el comprobante, tal como la devolvió el backend con el
  /// pedido (`pedido['sede']`). Es la que se imprime: cada local tiene su
  /// razón social, dirección, teléfono y RUC. Si no llega, se resuelve con la
  /// sede del usuario.
  final Map<String, dynamic>? sedeJson;

  // Se genera automáticamente un ID de pedido aleatorio
  late final String orderId = (Random().nextInt(900000) + 100000)
      .toString(); // 6 dígitos aleatorios

  // Fecha y hora actual (hora local, formateada HH:mm)
  final String date = (() {
    final now = DateTime.now().toLocal();
    return "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
  })();

  final String time = (() {
    final now = DateTime.now().toLocal();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  })();

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
    this.sedeJson,
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
  // Eliminado _codigoCompra
  bool _mediaStoreReady = false;
  bool _walletApplied = false;

  // ------------------------------------------------------------------
  // DATOS DE LA SEDE QUE EMITE EL COMPROBANTE
  //
  // Antes estaban escritos aquí como constantes, así que una boleta de Jaén
  // o Tarapoto salía con la dirección y el teléfono de Iquitos. Ahora vienen
  // de la sede del pedido; los valores de abajo son sólo el último recurso
  // para que el comprobante nunca salga con huecos.
  // ------------------------------------------------------------------
  Sede? _sede;

  static const String _razonSocialPorDefecto = 'SPLASH BUBBLE';
  static const String _direccionPorDefecto =
      'Calle. Sargento Lores #762, Iquitos, Loreto';
  static const String _telefonoPorDefecto = '+51 910 958 665';

  String get _razonSocial {
    final valor = _sede?.razonSocial.trim() ?? '';
    return valor.isNotEmpty ? valor : _razonSocialPorDefecto;
  }

  String get _nombreSede => _sede?.name.trim() ?? '';

  String get _direccionEmpresa {
    final valor = _sede?.direccionCompleta.trim() ?? '';
    return valor.isNotEmpty ? valor : _direccionPorDefecto;
  }

  String get _telefonoContacto {
    final valor = _sede?.phone.trim() ?? '';
    return valor.isNotEmpty ? valor : _telefonoPorDefecto;
  }

  String get _rucEmpresa => _sede?.ruc.trim() ?? '';

  Future<void> _cargarSede() async {
    final sede = await SedeService.sedeParaComprobante(widget.sedeJson);
    if (!mounted || sede == null) return;
    setState(() => _sede = sede);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

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

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (user != null) {
      _nombreCliente =
          (user.displayName != null && user.displayName!.trim().isNotEmpty)
          ? user.displayName
          : (user.email ?? 'Cliente');
    } else {
      SharedPreferences.getInstance().then((prefs) {
        final name = prefs.getString('use_txt_fullname') ?? prefs.getString('google_name') ?? prefs.getString('google_email');
        if (name != null && name.isNotEmpty) {
          if (mounted) {
            setState(() {
              _nombreCliente = name;
            });
          }
        }
      });
      _nombreCliente = 'Cliente';
    }

    // Eliminado código de compra

    _cargarSede();
    _initNotifications();

    // Si ya viene pagado desde el carrito, aplicar efectos locales una sola vez.
    // Se espera a tener la sede resuelta para guardarla junto al detalle: así
    // la boleta se reimprime después con el local correcto aunque el cliente
    // haya cambiado de sede.
    if (widget.alreadyPaid && widget.applyWalletDeduction) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _cargarSede();
        await _registrarCompraLocal();
      });
    }
  }

  Future<void> _registrarCompraLocal() async {
    if (_walletApplied) return;
    _walletApplied = true;

    final prefs = await SharedPreferences.getInstance();
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final String? email = prefs.getString('google_email') ?? prefs.getString('savedEmail');
    final String? userUniqueId = user?.uid ?? (email != null && email.isNotEmpty ? email : null);

    // El movimiento de billetera lo crea el BACKEND cuando se paga el pedido;
    // aquí sólo se guarda el DETALLE (productos, tipo de entrega, sede) que el
    // listado de movimientos no devuelve y que hace falta para reimprimir la
    // boleta.
    //
    // Se guarda bajo el número de pedido del servidor: es lo que permite pegar
    // este detalle sobre su movimiento. Antes se guardaba como un movimiento
    // más, con un número de pedido inventado en el teléfono, y por eso cada
    // compra salía DOS veces en el historial.
    //
    // Sin número de pedido no hay forma de emparejarlo, así que no se guarda:
    // es preferible una boleta sin el desglose de productos que una compra
    // repetida.
    final String numeroPedido = (widget.backendOrderNumber ?? '').trim();
    if (numeroPedido.isNotEmpty) {
      await MovimientosService.guardarDetalleCompra(
        numeroPedido: numeroPedido,
        detalle: {
          'tipo': 'gasto',
          'monto': total,
          'metodo': 'Compra de productos',
          'referencia': 'Pedido $numeroPedido (${widget.finalPedidos.length} productos)',
          'fecha': '${widget.date} ${widget.time}',
          'orderId': numeroPedido,
          'dineOption': widget.dineOption,
          'items': widget.finalPedidos,
          'cliente': _nombreCliente ?? 'Cliente',
          if (_sede != null) 'sede': _sede!.toJson(),
        },
      );
    }

    // Acumular puntos por compra: 1 punto por cada sol del total
    final String? keyPuntos = userUniqueId != null ? 'puntos_$userUniqueId' : null;
    final int puntosActuales = keyPuntos != null
        ? (prefs.getInt(keyPuntos) ?? 0)
        : 0;
    final int puntosGanados = total.floor();
    if (puntosGanados > 0 && keyPuntos != null) {
      await prefs.setInt(keyPuntos, puntosActuales + puntosGanados);
    }

    // Limpiar el carrito persistido una vez realizado el pago
    await prefs.remove('cart_pedidos');
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) return;
        await _openPdf(payload);
      },
    );

    // Si la app estaba cerrada y se abrió desde la notificación, abrir el PDF.
    final details = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    final didLaunchFromNotification =
        details?.didNotificationLaunchApp ?? false;
    final payload = details?.notificationResponse?.payload;
    if (didLaunchFromNotification &&
        payload != null &&
        payload.trim().isNotEmpty) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir el PDF: $e')));
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
              if (_nombreSede.isNotEmpty)
                pw.Text(
                  'Sede: $_nombreSede',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              if (_rucEmpresa.isNotEmpty)
                pw.Text(
                  'RUC: $_rucEmpresa',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
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
              pw.Text('Fecha: ${widget.date}'),
              pw.Text('Hora: ${widget.time}'),
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
                final String size = etiquetaTamano(item['size']?.toString());
                final String ice = item['ice'] ?? '';
                final List<dynamic> rawToppings = (item['toppings'] is List)
                    ? item['toppings']
                    : [];
                final String toppingsText = _formatToppingsForUi(
                  rawToppings,
                ).trim();
                final List<String> details = [
                  if (size.isNotEmpty) size,
                  if (ice.isNotEmpty) ice,
                  if (toppingsText.isNotEmpty) toppingsText,
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
              pw.SizedBox(height: 20),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
                                Text(
                                  _nombreSede.isNotEmpty
                                      ? 'Comprobante de Pedido · Sede $_nombreSede'
                                      : 'Comprobante de Pedido',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (_rucEmpresa.isNotEmpty)
                                  Text(
                                    'RUC: $_rucEmpresa',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 🔹 Datos de la sede que emite
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
                            'Fecha: ${widget.date}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Hora: ${widget.time}',
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

                        final String size = etiquetaTamano(item['size']?.toString());
                        final String ice = item['ice'] ?? '';
                        final List<dynamic> rawToppings =
                            (item['toppings'] is List) ? item['toppings'] : [];
                        final String toppingsText = _formatToppingsForUi(
                          rawToppings,
                        ).trim();

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

                      const SizedBox(height: 12),
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
                              backgroundColor: const Color(0xFF128FA0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _simularPago,
                          ),
                        ),

                      const SizedBox(height: 16),
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
                          onPressed: _descargarPdf,
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
                    backgroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFF128FA0)),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Color(0xFF128FA0),
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
              color: isTotal ? const Color(0xFF128FA0) : Colors.black,
            ),
          ),
          Text(
            'S/. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF128FA0) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
