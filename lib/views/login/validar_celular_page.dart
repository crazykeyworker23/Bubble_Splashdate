import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nueva_contrasena_page.dart';

class ValidarCelularPage extends StatefulWidget {
  const ValidarCelularPage({super.key});

  @override
  State<ValidarCelularPage> createState() => _ValidarCelularPageState();
}

class _ValidarCelularPageState extends State<ValidarCelularPage> {
  final TextEditingController _celularController = TextEditingController();
  bool _codigoEnviado = false;
  bool _mostrandoOverlay = false;
  List<String> _codigo = List.filled(6, '');

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            centerTitle: true,
            shadowColor: Colors.black12,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Regístrate',
              style: GoogleFonts.paytoneOne(
                color: const Color(0xFF045378),
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Validación de Celular',
                      style: GoogleFonts.paytoneOne(
                        fontSize: 22,
                        color: const Color(0xFF1B6F81),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ingrese su número de celular personal para verificar su identidad.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Campo de celular
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Número de Celular',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _celularController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '987654321',
                        filled: true,
                        fillColor: const Color(0xFFF4F6F8),
                        prefixIcon: const Icon(Icons.phone_iphone_outlined,
                            color: Colors.black45),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Colors.black26, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF2D8EFF), width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Botón Enviar código
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_celularController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Por favor, ingrese su número.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _codigoEnviado = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Código enviado al número ${_celularController.text}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 27, 111, 129),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          'Enviar código',
                          style: GoogleFonts.paytoneOne(
                            fontSize: 15,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),

                    if (_codigoEnviado) ...[
                      const SizedBox(height: 25),
                      Divider(
                        thickness: 1,
                        color: Colors.black12.withOpacity(0.1),
                        height: 40,
                      ),
                      Text(
                        'Código enviado al número ${_celularController.text}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.green.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ingrese el código de verificación enviado por SMS.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿No te llegó el código?',
                              style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Se reenvió el código.'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            child: const Text(
                              'Reenviar',
                              style: TextStyle(
                                color: Color(0xFF1B6F81),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Código de Verificación',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Campos del código
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 48,
                            height: 60,
                            child: TextField(
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _codigo[index] = value;
                                });
                                if (value.isNotEmpty && index < 5) {
                                  FocusScope.of(context).nextFocus();
                                }
                              },
                              decoration: InputDecoration(
                                counterText: "",
                                filled: true,
                                fillColor: const Color(0xFFF4F6F8),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.black26, width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2D8EFF), width: 2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 35),

                      // Botón Validar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_codigo.any((d) => d.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ingrese el código completo.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() => _mostrandoOverlay = true);
                            await Future.delayed(const Duration(seconds: 2));
                            setState(() => _mostrandoOverlay = false);

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NuevaContrasenaPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B050),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                          ),
                          child: Text(
                            'Validar',
                            style: GoogleFonts.paytoneOne(
                              fontSize: 15,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // 🔹 Overlay de "VALIDANDO..." elegante
        if (_mostrandoOverlay)
          Container(
            color: Colors.black.withOpacity(0.55),
            alignment: Alignment.center,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        color: Color(0xFF00B050),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      'VALIDANDO...',
                      style: GoogleFonts.paytoneOne(
                        color: const Color(0xFF045378),
                        fontSize: 22,
                        letterSpacing: 1.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Por favor, espere un momento',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
