import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../controllers/cart_controller.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/views/home/ReceiptPage.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String _selectedDineOption = 'En el Local';

  String get _deliveryCode {
    if (_selectedDineOption.toLowerCase().contains('llevar')) {
      return 'PARA_LLEVAR';
    }
    return 'EN_LOCAL';
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartController>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Carrito')),
      body: cart.items.isEmpty
          ? const Center(child: Text('El carrito está vacío'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        leading: Image.asset(item.product.image, width: 50, height: 50),
                        title: Text(item.product.name),
                        subtitle: Text('Cantidad: ${item.quantity}  •  Total: S/. ${item.total.toStringAsFixed(2)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => cart.removeAt(index),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Total: S/. ${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('En el Local'),
                              selected: _selectedDineOption == 'En el Local',
                              onSelected: (_) {
                                setState(() {
                                  _selectedDineOption = 'En el Local';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Para Llevar'),
                              selected: _selectedDineOption == 'Para Llevar',
                              onSelected: (_) {
                                setState(() {
                                  _selectedDineOption = 'Para Llevar';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          Future<double?> getSaldoBackend() async {
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final rawToken = prefs.getString('access_token');
                              if (rawToken == null || rawToken.trim().isEmpty) return null;

                              final uri = BackendConfig.api('bubblesplash/wallet/me/');
                              http.Response response = await http.get(
                                uri,
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Accept': 'application/json',
                                  'Authorization': 'Bearer ${rawToken.trim()}',
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

                              if (response.statusCode != 200) {
                                debugPrint('No se pudo leer saldo wallet/me: ${response.statusCode} ${response.body}');
                                return null;
                              }

                              final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
                              final String balanceStr = (data['wal_de_balance'] ?? '0').toString();
                              return double.tryParse(balanceStr) ?? 0.0;
                            } catch (e) {
                              debugPrint('Excepción al leer saldo wallet/me: $e');
                              return null;
                            }
                          }

                          Future<bool> verificarSaldoSuficiente(double total) async {
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final rawToken = prefs.getString('access_token');
                              if (rawToken == null || rawToken.trim().isEmpty) {
                                if (!context.mounted) return false;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No hay access token. Inicia sesión nuevamente.')),
                                );
                                return false;
                              }

                              final uri = BackendConfig.api('bubblesplash/wallet/me/');
                              http.Response response = await http.get(
                                uri,
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Accept': 'application/json',
                                  'Authorization': 'Bearer ${rawToken.trim()}',
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
                                if (!context.mounted) return false;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Tu sesión ha expirado. Inicia sesión nuevamente.')),
                                );
                                return false;
                              }

                              if (response.statusCode != 200) {
                                debugPrint('Error wallet/me: ${response.statusCode} ${response.body}');
                                if (!context.mounted) return false;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No se pudo verificar el saldo de tu billetera.')),
                                );
                                return false;
                              }

                              final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
                              final String balanceStr = (data['wal_de_balance'] ?? '0').toString();
                              final double saldoBackend = double.tryParse(balanceStr) ?? 0.0;

                              if (saldoBackend + 1e-6 < total) {
                                if (!context.mounted) return false;
                                await showDialog<void>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Saldo insuficiente'),
                                    content: Text(
                                      'Tu saldo disponible es S/. ${saldoBackend.toStringAsFixed(2)} y el total de tu pedido es S/. ${total.toStringAsFixed(2)}.',
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Aceptar')),
                                    ],
                                  ),
                                );
                                return false;
                              }

                              return true;
                            } catch (e) {
                              debugPrint('Excepción al verificar saldo: $e');
                              if (!context.mounted) return false;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error al verificar el saldo de tu billetera.')),
                              );
                              return false;
                            }
                          }

                          Future<Map<String, dynamic>?> crearPedidoBackend(Map<String, dynamic> pedido) async {
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final rawToken = prefs.getString('access_token');
                              if (rawToken == null || rawToken.trim().isEmpty) {
                                if (!context.mounted) return null;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No hay access token. Inicia sesión nuevamente.')),
                                );
                                return null;
                              }

                              final uri = BackendConfig.api('bubblesplash/pedidos/');
                              final body = jsonEncode(pedido);
                              http.Response response = await http.post(
                                uri,
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Accept': 'application/json',
                                  'Authorization': 'Bearer ${rawToken.trim()}',
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
                                if (!context.mounted) return null;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Tu sesión ha expirado. Inicia sesión nuevamente.')),
                                );
                                return null;
                              }

                              if (response.statusCode == 200 || response.statusCode == 201) {
                                return jsonDecode(response.body) as Map<String, dynamic>;
                              }

                              debugPrint('Error al crear pedido: ${response.statusCode} ${response.body}');
                              if (!context.mounted) return null;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('No se pudo crear el pedido (${response.statusCode}).')),
                              );
                              return null;
                            } catch (e) {
                              debugPrint('Excepción al crear pedido: $e');
                              if (!context.mounted) return null;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error al conectar con el servidor.')),
                              );
                              return null;
                            }
                          }

                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Confirmar pago'),
                              content: Text('¿Deseas pagar S/ ${cart.total.toStringAsFixed(2)}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Pagar')),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          if (!context.mounted) return;

                          final double totalLocal = cart.total;

                          // Diagnóstico: saldo antes
                          final double? saldoAntes = await getSaldoBackend();

                          // 1) Verificar saldo suficiente (backend wallet/me)
                          final okSaldo = await verificarSaldoSuficiente(totalLocal);
                          if (!okSaldo) return;

                          // Construir el cuerpo del pedido
                          final items = cart.items.map((order) {
                            return {
                              'pro_int_id': order.product.id,
                              'pdi_txt_size': 'NORMAL', // Ajustar si tienes el tamaño en el modelo
                              'pdi_int_quantity': order.quantity,
                              'toppings': order.toppings.map((t) => t.id).toList(),
                              'pdi_txt_notes': '', // Puedes agregar notas si tienes
                            };
                          }).toList();

                          final pedido = {
                            'ped_txt_delivery': _deliveryCode,
                            'items': items,
                          };

                          // 2) Crear pedido en backend
                          final pedidoData = await crearPedidoBackend(pedido);
                          if (pedidoData == null) return;

                          // Diagnóstico: saldo después
                          final double? saldoDespues = await getSaldoBackend();
                          if (saldoAntes != null && saldoDespues != null) {
                            final double descontado = (saldoAntes - saldoDespues);
                            debugPrint(
                              'DIAGNÓSTICO COBRO: appTotal=S/. ${totalLocal.toStringAsFixed(2)} | serverDelta=S/. ${descontado.toStringAsFixed(2)} | saldoAntes=S/. ${saldoAntes.toStringAsFixed(2)} | saldoDespues=S/. ${saldoDespues.toStringAsFixed(2)}',
                            );
                            if (context.mounted && (descontado - totalLocal).abs() > 0.01) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'El servidor descontó S/. ${descontado.toStringAsFixed(2)} (tu carrito: S/. ${totalLocal.toStringAsFixed(2)}).',
                                  ),
                                ),
                              );
                            }
                          }

                          // Preparar items para el comprobante (precio unitario real, sin IGV)
                          final List<Map<String, dynamic>> finalPedidos = cart.items.map((order) {
                            final double unit = order.product.price + order.toppings.fold(0.0, (p, t) => p + t.price);
                            return {
                              'name': order.product.name,
                              'quantity': order.quantity,
                              'price': unit,
                              'size': 'NORMAL',
                              'ice': '',
                              'toppings': order.toppings.map((t) => t.name).toList(),
                            };
                          }).toList();

                          // Fecha/hora desde el backend si existe
                          String? backendDate;
                          String? backendTime;
                          final String ts = (pedidoData['timestamp_datecreate'] ?? '').toString();
                          if (ts.isNotEmpty) {
                            try {
                              final dt = DateTime.parse(ts);
                              backendDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                              backendTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            } catch (_) {}
                          }
                          final String orderNumber = (pedidoData['ped_txt_number'] ?? '').toString();

                          // Limpiar carrito
                          cart.clear();

                          // 3) Ir al comprobante (aplica descuento local de wallet)
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReceiptPage(
                                  finalPedidos: finalPedidos,
                                  dineOption: _selectedDineOption,
                                  subtotal: totalLocal,
                                  backendOrderNumber: orderNumber.isNotEmpty ? orderNumber : null,
                                  backendDate: backendDate,
                                  backendTime: backendTime,
                                  alreadyPaid: true,
                                  applyWalletDeduction: true,
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Pagar ahora'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
