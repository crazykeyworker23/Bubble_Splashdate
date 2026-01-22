import 'package:flutter/material.dart';

class EliminarCuentaPage extends StatelessWidget {
  const EliminarCuentaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( 
        title: const Text("Eliminar Cuenta"),
        backgroundColor: Color.fromARGB(255, 27, 111, 129),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            _mostrarConfirmacion(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text("Eliminar Cuenta Definitivamente"),
        ),
      ),
    );
  }

  void _mostrarConfirmacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: const Text("¿Estás seguro de que deseas eliminar tu cuenta?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
