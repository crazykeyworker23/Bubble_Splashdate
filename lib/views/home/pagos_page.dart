import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ionicons/ionicons.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/widgets/cart_fab_button.dart';

import 'scanner_page.dart';
import 'movimientos_page.dart';
import 'movimiento.dart';
import 'detail_movimiento_page.dart';

class PagosPage extends StatefulWidget {
  const PagosPage({super.key});

  @override
  State<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends State<PagosPage> {
  // ====== UI TOKENS ======
  static const Color mainColor = Color(0xFF1B6F81);
  static const Color accentBlue = Color(0xFF0D6EFD);
  static const Color premiumBg = Color(0xFFF6F7FB);

  // Clave para capturar el comprobante como imagen
  final GlobalKey _comprobanteKey = GlobalKey();

  bool _mostrarSaldo = true;
  double saldoActual = 0.0;
  bool _loadingSaldo = true;

  // Datos de la empresa / cliente para el comprobante
  final String _razonSocial = "BubbleSplash SAC";
  final String _direccionEmpresa = "Calle. Sargento Lores, Iquitos, Loreto";
  final String _telefonoContacto = "+51 999 999 999";
  String? _nombreCliente;

  @override
  void initState() {
    super.initState();
    _cargarSaldo();
    _cargarNombreCliente();
  }

  // =========================
  // ✅ MODAL PREMIUM (reemplaza SnackBar)
  // =========================
  Future<void> _showPremiumModal({
    required String title,
    required String message,
    IconData icon = Icons.info_rounded,
    Color accent = mainColor,
    String buttonText = 'Entendido',
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, size: 34, color: accent),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _cargarSaldo(),
      _cargarNombreCliente(),
    ]);
  }

  Future<void> _cargarSaldo() async {
    setState(() => _loadingSaldo = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        setState(() {
          saldoActual = 0.0;
          _loadingSaldo = false;
        });
        debugPrint('No hay access_token para consultar el saldo en la API');
        return;
      }

      final token = rawToken.trim();
      final uri =
          Uri.parse('https://services.fintbot.pe/api/bubblesplash/wallet/me/');

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Si el token expiró (401), intentamos refrescar y reintentar una vez
      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (response.statusCode == 401) {
        debugPrint('Sesión expirada al consultar saldo wallet/me');
        setState(() {
          saldoActual = 0.0;
          _loadingSaldo = false;
        });
        await _showPremiumModal(
          title: 'Sesión expirada',
          message: 'Tu sesión expiró. Inicia sesión nuevamente para ver tu saldo.',
          icon: Icons.schedule_rounded,
          accent: const Color(0xFFE80A5D),
        );
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String balanceStr = (data['wal_de_balance'] ?? '0').toString();
        final double balance = double.tryParse(balanceStr) ?? 0.0;

        setState(() {
          saldoActual = balance;
          _loadingSaldo = false;
        });
      } else {
        debugPrint(
          'Error al cargar saldo desde API wallet/me: ${response.statusCode} ${response.body}',
        );
        setState(() {
          saldoActual = 0.0;
          _loadingSaldo = false;
        });
        await _showPremiumModal(
          title: 'No se pudo cargar',
          message: 'No se pudo cargar tu saldo. Intenta nuevamente.',
          icon: Icons.wifi_off_rounded,
          accent: const Color(0xFFE80A5D),
        );
      }
    } catch (e) {
      debugPrint('Excepción al cargar saldo desde API wallet/me: $e');
      setState(() {
        saldoActual = 0.0;
        _loadingSaldo = false;
      });
      await _showPremiumModal(
        title: 'Error',
        message: 'Ocurrió un error al cargar tu saldo.',
        icon: Icons.error_rounded,
        accent: const Color(0xFFE53935),
      );
    }
  }

  Future<void> _cargarNombreCliente() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _nombreCliente = user?.displayName ?? user?.email ?? 'Cliente';
      });
    } catch (_) {
      setState(() {
        _nombreCliente = 'Cliente';
      });
    }
  }

  // ===============================
  // ✅ VISTA PREMIUM (Sliver + Cards)
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: premiumBg,
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: mainColor,
              expandedHeight: 260,
              title: const Text(
                'Mi Wallet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white),
                
              ),
              actions: [
                IconButton(
                  tooltip: _mostrarSaldo ? 'Ocultar saldo' : 'Mostrar saldo',
                  icon: Icon(
                    _mostrarSaldo ? Ionicons.eye_outline : Ionicons.eye_off_outline,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _mostrarSaldo = !_mostrarSaldo),
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0F3D4A),
                        Color(0xFF128FA0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Paga y acumula puntos.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ====== GLASS BALANCE CARD ======
                          _GlassCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Saldo disponible",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 220),
                                        child: _loadingSaldo
                                            ? const _ShimmerLine(key: ValueKey('loading'))
                                            : (_mostrarSaldo
                                                ? Text(
                                                    "S/ ${saldoActual.toStringAsFixed(2)}",
                                                    key: const ValueKey('saldo'),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  )
                                                : const Text(
                                                    "••••••••",
                                                    key: ValueKey('oculto'),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  )),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _PillButton(
                                  text: 'Recargar',
                                  icon: Icons.add_rounded,
                                  onTap: _mostrarPopupRecargaPremium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // ====== ACCIONES ======
                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            title: 'Escanear',
                            subtitle: 'QR / pagos',
                            icon: Ionicons.camera_outline,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ScannerPage()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionCard(
                            title: 'Movimientos',
                            subtitle: 'Historial',
                            icon: Ionicons.receipt_outline,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MovimientosPage()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ====== MOVIMIENTOS PREVIEW ======
                    _SectionHeader(
                      title: 'Movimientos',
                      trailingText: 'Ver todo',
                      onTrailingTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MovimientosPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _PremiumCard(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _cargarMovimientosPreview(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Column(
                              children: const [
                                _SkeletonMovimiento(),
                                _SkeletonMovimiento(),
                                _SkeletonMovimiento(),
                              ],
                            );
                          }

                          final data = snapshot.data ?? [];
                          final filtrados = data.where((m) {
                            final tipo = (m['tipo'] ?? '').toString();
                            return tipo == 'recarga' || tipo == 'movimiento';
                          }).toList();

                          if (filtrados.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Aún no tienes movimientos registrados.',
                                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                              ),
                            );
                          }

                          final ultimos = filtrados.take(3).toList();
                          return Column(
                            children: [
                              for (int i = 0; i < ultimos.length; i++) ...[
                                MovimientoItemPremium(movimientoRaw: ultimos[i]),
                                if (i != ultimos.length - 1)
                                  Divider(height: 16, color: Colors.black.withOpacity(0.06)),
                              ]
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: CartFabButton(
        count: 0, // TODO: conecta tu contador real
        onPressed: () => Navigator.pushNamed(context, '/cart'),
        draggable: false,
        heroTag: 'pagos_cart_fab',
      ),
    );
  }

  // =========================
  // ✅ RECARGA PREMIUM (BottomSheet)
  // =========================
  void _mostrarPopupRecargaPremium() {
    double? montoSeleccionado;
    String tipoTransferencia = "Billetera Digital";
    String metodoOtraBilletera = "Yape";
    final TextEditingController montoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildTransferExtra() {
              if (tipoTransferencia == "Billetera Digital") {
                return _InfoBox(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Billetera Digital',
                  message:
                      'Recarga con tu billetera digital vinculada. Sigue los pasos para completar el pago.',
                  accent: accentBlue,
                );
              }
              if (tipoTransferencia == "Transferencia Bancaria") {
                return _InfoBox(
                  icon: Icons.account_balance_rounded,
                  title: 'Transferencia Bancaria',
                  message:
                      'Banco: BCP\nCuenta: 123-45678901-0-12\nTitular: Bubble Tea SAC',
                  accent: Colors.black87,
                );
              }
              // Otra billetera
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elige tu billetera',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Yape"),
                          selected: metodoOtraBilletera == "Yape",
                          selectedColor: accentBlue,
                          backgroundColor: Colors.black.withOpacity(0.06),
                          labelStyle: TextStyle(
                            color: metodoOtraBilletera == "Yape" ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) => setModalState(() => metodoOtraBilletera = "Yape"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Plin"),
                          selected: metodoOtraBilletera == "Plin",
                          selectedColor: accentBlue,
                          backgroundColor: Colors.black.withOpacity(0.06),
                          labelStyle: TextStyle(
                            color: metodoOtraBilletera == "Plin" ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) => setModalState(() => metodoOtraBilletera = "Plin"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escanea el QR o usa el número asociado para completar la recarga.',
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 46,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Recargar saldo',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                icon: const Icon(Icons.close_rounded),
                              )
                            ],
                          ),

                          const SizedBox(height: 8),

                          _PremiumCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Saldo actual',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.55),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'S/ ${saldoActual.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          const Text('Montos rápidos', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [50, 100, 200, 500].map((monto) {
                              final isSelected = montoSeleccionado == monto;
                              return ChoiceChip(
                                label: Text("S/ $monto"),
                                selected: isSelected,
                                selectedColor: accentBlue,
                                backgroundColor: Colors.black.withOpacity(0.06),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w800,
                                ),
                                onSelected: (_) {
                                  setModalState(() {
                                    if (isSelected) {
                                      montoSeleccionado = null;
                                    } else {
                                      montoSeleccionado = monto.toDouble();
                                      montoController.clear();
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 14),

                          const Text('Monto personalizado', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: montoController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ingresa un monto',
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              setModalState(() => montoSeleccionado = double.tryParse(value));
                            },
                          ),

                          const SizedBox(height: 14),

                          const Text('Tipo de transferencia', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),

                          _SegmentedChips(
                            value: tipoTransferencia,
                            options: const [
                              "Billetera Digital",
                              "Transferencia Bancaria",
                              "Otra billetera",
                            ],
                            onChanged: (v) => setModalState(() => tipoTransferencia = v),
                          ),

                          const SizedBox(height: 12),
                          buildTransferExtra(),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (montoSeleccionado != null && montoSeleccionado! > 0) {
                                  Navigator.pop(sheetCtx);
                                  await Future.delayed(const Duration(milliseconds: 250));
                                  if (!mounted) return;
                                  await _realizarRecargaBackend(
                                    montoSeleccionado!,
                                    tipoTransferencia,
                                    metodoOtraBilletera,
                                  );
                                } else {
                                  await _showPremiumModal(
                                    title: 'Monto inválido',
                                    message: 'Selecciona o ingresa un monto mayor a 0.',
                                    icon: Icons.warning_amber_rounded,
                                    accent: const Color(0xFFFFA726),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Recargar',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===============================
  // MOVIMIENTOS (Preview desde API)
  // ===============================
  Future<List<Map<String, dynamic>>> _cargarMovimientosPreview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        debugPrint('No hay access_token para consultar movimientos (preview)');
        return [];
      }

      final token = rawToken.trim();
      final uri = Uri.parse('https://services.fintbot.pe/api/bubblesplash/wallet/movimientos/');

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (response.statusCode == 401) {
        debugPrint('Sesión expirada al consultar movimientos (preview)');
        return [];
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

        return data.whereType<Map<String, dynamic>>().map((item) {
          final String rawType = (item['wmv_txt_type'] ?? '').toString();
          final String tipo = rawType.toUpperCase() == 'RECARGA' ? 'recarga' : 'movimiento';

          final String amountStr = (item['wmv_de_amount'] ?? '0').toString();
          final double monto = double.tryParse(amountStr) ?? 0.0;

          final String descripcion = (item['wmv_txt_description'] ?? '').toString();
          final String fechaIso = (item['timestamp_datecreate'] ?? '').toString();

          String fecha = fechaIso;
          if (fechaIso.contains('T')) {
            try {
              fecha = fechaIso.replaceFirst('T', ' ').substring(0, 16);
            } catch (_) {
              fecha = fechaIso;
            }
          }

          final String id = (item['wmv_int_id'] ?? '').toString();

          return <String, dynamic>{
            'tipo': tipo,
            'monto': monto,
            'metodo': descripcion,
            'referencia': id,
            'fecha': fecha,
            'codigo': 'MOV$id',
            'cliente': _nombreCliente ?? 'Cliente',
          };
        }).toList();
      } else {
        debugPrint('Error al cargar movimientos (preview): ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Excepción al cargar movimientos (preview): $e');
      return [];
    }
  }

  // ===============================
  // RECARGA BACKEND (misma lógica, UI premium)
  // ===============================
  Future<void> _realizarRecargaBackend(
    double montoSeleccionado,
    String tipoTransferencia,
    String metodoOtraBilletera,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        await _showPremiumModal(
          title: 'Sesión requerida',
          message: 'No hay access_token. Inicia sesión nuevamente para recargar.',
          icon: Icons.lock_rounded,
          accent: const Color(0xFFE80A5D),
        );
        return;
      }

      final token = rawToken.trim();

      String transferCode;
      if (tipoTransferencia == 'Billetera Digital') {
        transferCode = 'BILLETERA_DIGITAL';
      } else if (tipoTransferencia == 'Transferencia Bancaria') {
        transferCode = 'TRANSFERENCIA_BANCARIA';
      } else {
        transferCode = (metodoOtraBilletera == 'Yape')
            ? 'YAPE'
            : (metodoOtraBilletera == 'Plin')
                ? 'PLIN'
                : 'OTRA_BILLETERA';
      }

      final uri = Uri.parse('https://services.fintbot.pe/api/bubblesplash/wallet/recarga/');

      final body = jsonEncode({
        'wmv_de_amount': montoSeleccionado.toStringAsFixed(2),
        'wmv_txt_transfer': transferCode,
      });

      http.Response response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
            body: body,
          );
        }
      }

      if (response.statusCode == 401) {
        await _showPremiumModal(
          title: 'Sesión expirada',
          message: 'Tu sesión ha expirado. Inicia sesión nuevamente para recargar.',
          icon: Icons.schedule_rounded,
          accent: const Color(0xFFE80A5D),
        );
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final wallet = data['wallet'] as Map<String, dynamic>?;
        final movement = data['movement'] as Map<String, dynamic>?;

        double nuevoSaldo = saldoActual;
        if (wallet != null) {
          final balanceStr = (wallet['wal_de_balance'] ?? '0').toString();
          nuevoSaldo = double.tryParse(balanceStr) ?? nuevoSaldo;
        }

        String metodoPagoUi =
            (tipoTransferencia == 'Otra billetera') ? 'Otra billetera ($metodoOtraBilletera)' : tipoTransferencia;

        String fecha = '';
        String hora = '';
        String idTransaccion = '';
        double montoRecibido = montoSeleccionado;

        if (movement != null) {
          final amountStr = (movement['wmv_de_amount'] ?? '0').toString();
          montoRecibido = double.tryParse(amountStr) ?? montoRecibido;

          final String id = (movement['wmv_int_id'] ?? '').toString();
          idTransaccion = 'MOV$id';

          final String fechaIso = (movement['timestamp_datecreate'] ?? '').toString();
          if (fechaIso.isNotEmpty) {
            try {
              final dt = DateTime.parse(fechaIso);
              fecha = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
              hora = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {
              fecha = fechaIso;
              hora = '';
            }
          }
        }

        if (mounted) {
          setState(() => saldoActual = nuevoSaldo);
        }

        if (mounted) {
          await _mostrarPopupRecargaExitosa(
            context,
            montoRecibido,
            metodoPagoUi,
            fecha,
            hora,
            idTransaccion.isEmpty ? 'REC${DateTime.now().millisecondsSinceEpoch}' : idTransaccion,
          );
        }
      } else {
        await _showPremiumModal(
          title: 'No se pudo recargar',
          message: 'Error al realizar recarga (${response.statusCode}).',
          icon: Icons.receipt_long_rounded,
          accent: const Color(0xFFE53935),
        );
      }
    } catch (e) {
      await _showPremiumModal(
        title: 'Error',
        message: 'Error al realizar recarga: $e',
        icon: Icons.error_rounded,
        accent: const Color(0xFFE53935),
      );
    }
  }

  // ===============================
  // POPUP RECARGA EXITOSA (tu UI, solo mejoré bordes/espacios)
  // ===============================
  Future<void> _mostrarPopupRecargaExitosa(
    BuildContext context,
    double montoRecargado,
    String tipoTransferencia,
    String fecha,
    String hora,
    String idTransaccion,
  ) async {
    const int puntosGanados = 5;

    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String keyPuntos = 'puntos_${user.uid}';
      final int puntosActuales = prefs.getInt(keyPuntos) ?? 0;
      await prefs.setInt(keyPuntos, puntosActuales + puntosGanados);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // BOLETA QUE SE CAPTURA COMO IMAGEN
                RepaintBoundary(
                  key: _comprobanteKey,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.receipt_long, color: Colors.black87),
                              SizedBox(width: 8),
                              Text(
                                "Comprobante de recarga",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                                child: const Icon(Icons.storefront, color: Colors.black87),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Contacto: $_telefonoContacto",
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        const Icon(Icons.check_circle, size: 48, color: Colors.green),
                        const SizedBox(height: 8),
                        const Text(
                          "¡Recarga exitosa!",
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "Tu recarga se ha procesado correctamente.",
                            style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Colors.black12),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text("Monto recargado", style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "S/ ${montoRecargado.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 10),
                        const Text("Detalles del comprobante", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 6),
                        _buildDetailRow(Icons.tag, "ID transacción", idTransaccion),
                        _buildDetailRow(Icons.credit_card, "Método de pago", tipoTransferencia),
                        _buildDetailRow(Icons.calendar_today, "Fecha", fecha),
                        _buildDetailRow(Icons.access_time, "Hora", hora),
                        _buildDetailRow(Icons.person, "Cliente", _nombreCliente ?? 'Cliente'),
                        const SizedBox(height: 10),

                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  "Puntos ganados\n¡Sigue acumulando!",
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black45),
                                ),
                                child: Text(
                                  "+ $puntosGanados",
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // BOTONES (NO ENTRAN EN LA CAPTURA)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _generarPDFComprobante(
                              context,
                              montoRecargado,
                              tipoTransferencia,
                              idTransaccion,
                              fecha,
                              hora,
                              puntosGanados,
                            );
                          },
                          icon: const Icon(Icons.download, color: Colors.black),
                          label: const Text("Descargar", style: TextStyle(color: Colors.black)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Colors.black12),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarPopupCompartir(context),
                          icon: const Icon(Icons.share, color: Colors.black),
                          label: const Text("Compartir", style: TextStyle(color: Colors.black)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Colors.black12),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Colors.black12),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Regresar",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- FUNCIÓN AUXILIAR PARA FILAS DE DETALLE ---
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE80A5D), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // --- GENERAR PDF DE COMPROBANTE ---
  Future<void> _generarPDFComprobante(
    BuildContext context,
    double monto,
    String metodo,
    String id,
    String fecha,
    String hora,
    int puntos,
  ) async {
    final pdf = pw.Document();
    try {
      final boundary = _comprobanteKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      pw.Widget comprobanteWidget;
      Uint8List? pngBytes;

      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) pngBytes = byteData.buffer.asUint8List();
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
                "Comprobante de Recarga Exitosa",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Monto Recargado: S/ ${monto.toStringAsFixed(2)}"),
            pw.Text("Método de Pago: $metodo"),
            pw.Text("ID Transacción: $id"),
            pw.Text("Fecha: $fecha"),
            pw.Text("Hora: $hora"),
            pw.SizedBox(height: 10),
            pw.Text("Puntos Ganados: +$puntos"),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                "¡Gracias por tu recarga!",
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 14),
              ),
            ),
          ],
        );
      }

      pdf.addPage(
        pw.Page(
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: comprobanteWidget,
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/comprobante_recarga.pdf");
      await file.writeAsBytes(await pdf.save());

      await _showPremiumModal(
        title: 'PDF guardado',
        message: 'Se guardó el comprobante en la app. Intentaré abrirlo ahora.',
        icon: Icons.picture_as_pdf_rounded,
        accent: const Color(0xFF2E7D32),
        buttonText: 'Ok',
      );

      try {
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          await _showPremiumModal(
            title: 'No se pudo abrir',
            message:
                'Se guardó correctamente, pero no se pudo abrir automáticamente.\n\nBusca: comprobante_recarga.pdf',
            icon: Icons.info_rounded,
            accent: const Color(0xFFFFA726),
          );
        }
      } catch (e) {
        await _showPremiumModal(
          title: 'No se pudo abrir',
          message:
              'Se guardó correctamente, pero falló al abrir.\n\nBusca: comprobante_recarga.pdf\n\nError: $e',
          icon: Icons.error_rounded,
          accent: const Color(0xFFE53935),
        );
      }
    } catch (e) {
      await _showPremiumModal(
        title: 'Error al generar PDF',
        message: '$e',
        icon: Icons.error_rounded,
        accent: const Color(0xFFE53935),
      );
    }
  }

  // --- POPUP DE COMPARTIR COMPROBANTE ---
  void _mostrarPopupCompartir(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Compartir comprobante de pago",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text(
                  "Compartir",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                onPressed: () async {
                  await _capturarYCompartirComprobante();
                  if (mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _capturarYCompartirComprobante() async {
    try {
      final boundary = _comprobanteKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await _showPremiumModal(
          title: 'No se pudo capturar',
          message: 'No se pudo capturar el comprobante.',
          icon: Icons.warning_amber_rounded,
          accent: const Color(0xFFFFA726),
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/comprobante_recarga_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Comprobante de recarga');
    } catch (e) {
      await _showPremiumModal(
        title: 'Error al compartir',
        message: '$e',
        icon: Icons.error_rounded,
        accent: const Color(0xFFE53935),
      );
    }
  }
}

// ===============================
// ✅ MOVIMIENTO ITEM PREMIUM
// ===============================
class MovimientoItemPremium extends StatelessWidget {
  final Map<String, dynamic> movimientoRaw;

  const MovimientoItemPremium({super.key, required this.movimientoRaw});

  double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final tipo = (movimientoRaw['tipo'] ?? '').toString(); // recarga | movimiento
    final fecha = (movimientoRaw['fecha'] ?? '').toString();
    final monto = _asDouble(movimientoRaw['monto']);
    final isRecarga = tipo == 'recarga';

    final title = isRecarga ? 'RECARGA' : 'COMPRA';
    final icon = isRecarga ? Ionicons.arrow_down_circle_outline : Ionicons.arrow_up_circle_outline;
    final iconBg = isRecarga ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final iconColor = isRecarga ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final sign = isRecarga ? '+' : '-';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (isRecarga) {
          final movimiento = Movimiento(
            titulo: title,
            monto: monto,
            tipo: tipo,
            fecha: fecha,
          );
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                opacity: animation,
                child: DetalleMovimientoPage(
                  movimiento: movimiento,
                  datosAdicionales: movimientoRaw,
                ),
              ),
            ),
          );
        } else {
          // Mantengo tu boleta de compra simple (si quieres la hacemos igual de pro + PDF/Share)
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) {
              final String metodo = (movimientoRaw['metodo'] ?? 'Compra').toString();
              final String id = (movimientoRaw['codigo'] ?? '').toString();
              final String cliente = (movimientoRaw['cliente'] ?? 'Cliente').toString();

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.receipt_long_rounded),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Comprobante de compra',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black.withOpacity(0.06)),
                          ),
                          child: Column(
                            children: [
                              Text('S/ ${monto.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(isRecarga ? 'Recarga' : 'Compra',
                                  style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _miniRow('ID', id),
                        _miniRow('Método', metodo),
                        _miniRow('Fecha', fecha),
                        _miniRow('Cliente', cliente),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: Colors.black.withOpacity(0.08)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Regresar',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    fecha,
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign S/ ${monto.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.w900, color: iconColor, fontSize: 14),
            ),
            const SizedBox(width: 6),
            Icon(Ionicons.chevron_forward_outline, color: Colors.black.withOpacity(0.35), size: 18),
          ],
        ),
      ),
    );
  }

  static Widget _miniRow(String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(a, style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(b, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

// ===============================
// ✅ COMPONENTES PREMIUM UI
// ===============================
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: child,
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _PremiumCard({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _PagosPageState.mainColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Ionicons.chevron_forward_outline, color: Colors.black.withOpacity(0.35), size: 18),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailingText;
  final VoidCallback onTrailingTap;

  const _SectionHeader({
    required this.title,
    required this.trailingText,
    required this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const Spacer(),
        TextButton(
          onPressed: onTrailingTap,
          child: Text(
            trailingText,
            style: TextStyle(color: _PagosPageState.mainColor, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _PillButton({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: Colors.black.withOpacity(0.65), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedChips extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SegmentedChips({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final selected = value == opt;
        return ChoiceChip(
          label: Text(opt),
          selected: selected,
          selectedColor: _PagosPageState.accentBlue,
          backgroundColor: Colors.black.withOpacity(0.06),
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
          onSelected: (_) => onChanged(opt),
        );
      }).toList(),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.20),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _SkeletonMovimiento extends StatelessWidget {
  const _SkeletonMovimiento();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Container(height: 12, decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 8),
                Container(height: 10, width: 140, alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 12,
            width: 90,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}