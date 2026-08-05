import 'package:flutter/material.dart';

import 'package:bubblesplash/services/sede_service.dart';

/// Campo de selección de sede.
///
/// Se usa en el registro y en "Mi perfil". La sede define a qué local llegan
/// los pedidos del cliente y qué catálogo, ofertas y beneficios ve en la app.
class SedeSelectorField extends StatefulWidget {
  final int? selectedSedeId;
  final ValueChanged<Sede?> onChanged;
  final bool enabled;
  final String label;
  final String? helperText;

  const SedeSelectorField({
    super.key,
    required this.selectedSedeId,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Sede',
    this.helperText,
  });

  @override
  State<SedeSelectorField> createState() => _SedeSelectorFieldState();
}

class _SedeSelectorFieldState extends State<SedeSelectorField> {
  static const Color _brandDark = Color(0xFF0F3D4A);

  List<Sede> _sedes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final sedes = await SedeService.fetchSedes();

    if (!mounted) return;
    setState(() {
      _sedes = sedes;
      _loading = false;
      // Se muestra el motivo real (403, 404, sin sedes activas...) para no
      // culpar siempre a la conexión y poder diagnosticar rápido.
      _error = sedes.isEmpty
          ? (SedeService.lastError ?? 'No se pudieron cargar las sedes.')
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Cargando sedes…',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    }

    // Evita que un id inexistente rompa el Dropdown.
    final int? value =
        _sedes.any((s) => s.id == widget.selectedSedeId) ? widget.selectedSedeId : null;

    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText ??
            'Tus pedidos y beneficios se atenderán en esta sede.',
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.storefront_rounded, color: _brandDark),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandDark, width: 1.6),
        ),
        filled: true,
        fillColor: widget.enabled ? Colors.white : const Color(0xFFF5F5F5),
      ),
      hint: const Text('Selecciona tu sede'),
      items: _sedes
          .map(
            (sede) => DropdownMenuItem<int>(
              value: sede.id,
              child: Text(
                sede.city.isNotEmpty && sede.city != sede.name
                    ? '${sede.name} · ${sede.city}'
                    : sede.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: widget.enabled
          ? (id) {
              if (id == null) {
                widget.onChanged(null);
                return;
              }
              widget.onChanged(_sedes.firstWhere((s) => s.id == id));
            }
          : null,
      validator: (id) =>
          id == null ? 'Selecciona la sede a la que perteneces' : null,
    );
  }
}
