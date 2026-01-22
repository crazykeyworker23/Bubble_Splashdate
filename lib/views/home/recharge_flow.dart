import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import '../../utils/responsive.dart';

class RechargeFlowPage extends StatefulWidget {
  const RechargeFlowPage({super.key});

  @override
  State<RechargeFlowPage> createState() => _RechargeFlowPageState();
}

class _RechargeFlowPageState extends State<RechargeFlowPage> {
  // Estados del flujo
  int _step = 0;
  double? _selectedAmount;
  String? _customAmount;
  String? _method;
  String? _reference;
  String? _bank;
  String? _wallet;
  String? _otherWallet;
  DateTime? _date;

  final List<double> _predefinedAmounts = [10, 20, 50, 100];
  final _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() => _step++);
  }

  void _resetFlow() {
    setState(() {
      _step = 0;
      _selectedAmount = null;
      _customAmount = null;
      _method = null;
      _reference = null;
      _bank = null;
      _wallet = null;
      _otherWallet = null;
      _date = null;
      _customAmountController.clear();
    });
  }

  Widget _buildAmountStep() {
    final titleSize = Responsive.fontSize(context, 18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona un monto a recargar:',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: _predefinedAmounts.map((amount) => ChoiceChip(
            label: Text('S/. ${amount.toStringAsFixed(2)}'),
            selected: _selectedAmount == amount,
            onSelected: (selected) {
              setState(() {
                _selectedAmount = amount;
                _customAmount = null;
                _customAmountController.clear();
              });
            },
          )).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Otro monto: '),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _customAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'S/.'),
                onChanged: (val) {
                  setState(() {
                    _customAmount = val;
                    _selectedAmount = null;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: (_selectedAmount != null || (_customAmount != null && _customAmount!.isNotEmpty)) ? _nextStep : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }

  Widget _buildMethodStep() {
    final titleSize = Responsive.fontSize(context, 18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona el método de recarga:',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        RadioListTile<String>(
          value: 'Billetera digital',
          groupValue: _method,
          onChanged: (val) => setState(() => _method = val),
          title: const Text('Billetera digital'),
        ),
        RadioListTile<String>(
          value: 'Transferencia bancaria',
          groupValue: _method,
          onChanged: (val) => setState(() => _method = val),
          title: const Text('Transferencia bancaria'),
        ),
        RadioListTile<String>(
          value: 'Otra billetera',
          groupValue: _method,
          onChanged: (val) => setState(() => _method = val),
          title: const Text('Otra billetera'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _method != null ? _nextStep : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }

  Widget _buildOptionsStep() {
    // Opciones específicas según método
    if (_method == 'Transferencia bancaria') {
      final titleSize = Responsive.fontSize(context, 16);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos bancarios:', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Banco: BCP'),
          const Text('Cuenta: 123-4567890-0-12'),
          const Text('CCI: 00212345678901234567'),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Referencia de operación'),
            onChanged: (val) => _reference = val,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _date = DateTime.now();
              _nextStep();
            },
            child: const Text('Recargar'),
          ),
        ],
      );
    } else if (_method == 'Billetera digital') {
      final titleSize = Responsive.fontSize(context, 16);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecciona billetera destino:', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _wallet,
            hint: const Text('Selecciona billetera'),
            items: const [
              DropdownMenuItem(value: 'Yape', child: Text('Yape')),
              DropdownMenuItem(value: 'Plin', child: Text('Plin')),
            ],
            onChanged: (val) => setState(() => _wallet = val),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Referencia de operación'),
            onChanged: (val) => _reference = val,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _wallet != null ? () {
              _date = DateTime.now();
              _nextStep();
            } : null,
            child: const Text('Recargar'),
          ),
        ],
      );
    } else if (_method == 'Otra billetera') {
      final titleSize = Responsive.fontSize(context, 16);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Especifica la billetera destino:', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold)),
          TextField(
            decoration: const InputDecoration(labelText: 'Nombre de billetera'),
            onChanged: (val) => _otherWallet = val,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Referencia de operación'),
            onChanged: (val) => _reference = val,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_otherWallet != null && _otherWallet!.isNotEmpty) ? () {
              _date = DateTime.now();
              _nextStep();
            } : null,
            child: const Text('Recargar'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _registrarMovimientoRecarga() async {
    final monto = _selectedAmount ?? (double.tryParse(_customAmount ?? '') ?? 0);
    final metodo = _method ?? '';
    final referencia = _reference ?? '-';
    final fecha = _date != null ? '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year} ${_date!.hour}:${_date!.minute.toString().padLeft(2, '0')}' : '-';
    final codigo = 'REC${DateTime.now().millisecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final String? keyMovs = user != null ? 'movimientos_${user.uid}' : null;
    final List<String> data = keyMovs != null
      ? (prefs.getStringList(keyMovs) ?? [])
      : <String>[];
    final movimiento = {
      'tipo': 'recarga',
      'monto': monto,
      'metodo': metodo,
      'referencia': referencia,
      'fecha': fecha,
      'codigo': codigo,
    };
    data.insert(0, jsonEncode(movimiento));
    if (keyMovs != null) {
      await prefs.setStringList(keyMovs, data);
    }

    // Actualizar saldo por usuario: sumar monto recargado
    if (user != null) {
      final String keySaldo = 'saldo_${user.uid}';
      final saldoActual = prefs.getDouble(keySaldo) ?? 0.0;
      await prefs.setDouble(keySaldo, saldoActual + monto);
    }
  }

  Widget _buildSuccessStep() {
    final monto = _selectedAmount ?? (double.tryParse(_customAmount ?? '') ?? 0);
    final metodo = _method ?? '';
    final referencia = _reference ?? '-';
    final fecha = _date != null ? '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year} ${_date!.hour}:${_date!.minute.toString().padLeft(2, '0')}' : '-';
    final codigo = 'REC${DateTime.now().millisecondsSinceEpoch}';

    // Registrar movimiento solo la primera vez que se muestra este paso
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_step == 3) _registrarMovimientoRecarga();
    });

    final titleSize = Responsive.fontSize(context, 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Recarga exitosa!',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monto: S/. ${monto.toStringAsFixed(2)}'),
                Text('Método: $metodo'),
                Text('Referencia: $referencia'),
                Text('Fecha/Hora: $fecha'),
                Text('Código: $codigo'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Descargar PDF'),
              onPressed: () {
                // TODO: Implementar descarga de PDF
              },
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
              onPressed: () {
                // TODO: Implementar compartir imagen
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: _resetFlow,
            child: const Text('Nueva recarga'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recargar saldo')),
      body: SafeArea(
        child: Padding(
          padding: padding,
          child: Stepper(
            type: isWide ? StepperType.horizontal : StepperType.vertical,
            currentStep: _step,
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: [
              Step(title: const Text('Monto'), content: _buildAmountStep(), isActive: _step == 0),
              Step(title: const Text('Método'), content: _buildMethodStep(), isActive: _step == 1),
              Step(title: const Text('Opciones'), content: _buildOptionsStep(), isActive: _step == 2),
              Step(title: const Text('Éxito'), content: _buildSuccessStep(), isActive: _step == 3),
            ],
          ),
        ),
      ),
    );
  }
}
