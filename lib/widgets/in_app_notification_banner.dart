import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bubblesplash/utils/globals.dart';

class InAppNotificationBanner {
  static OverlayEntry? _currentOverlay;
  static _InAppNotificationWidgetState? _currentState;

  /// Muestra una notificación flotante premium in-app en la parte superior.
  static void show({
    required String title,
    required String body,
    VoidCallback? onTap,
    Color? backgroundColor,
    Gradient? customGradient,
  }) {
    print('🔔 [InAppNotificationBanner.show] Solicitud de banner con Título: "$title", Cuerpo: "$body"');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentNavState = navigatorKey.currentState;
      final overlayState = currentNavState?.overlay;
      
      print('🔍 [InAppNotificationBanner.show] navigatorKey.currentState: $currentNavState');
      print('🔍 [InAppNotificationBanner.show] overlayState: $overlayState');

      if (overlayState == null) {
        print('❌ [InAppNotificationBanner.show] ERROR: overlayState es NULO. No se puede mostrar el banner.');
        return;
      }

      // Si ya hay una activa, le pedimos a su State que se anime hacia afuera.
      // Si no tiene State (aún no se montó), la removemos de inmediato.
      if (_currentOverlay != null) {
        if (_currentState != null && _currentState!.mounted) {
          _currentState!._dismiss();
        } else {
          dismiss();
        }
      }

      late OverlayEntry entry;
      bool isRemoved = false;

      entry = OverlayEntry(
        builder: (context) => _InAppNotificationWidget(
          title: title,
          body: body,
          onTap: onTap,
          backgroundColor: backgroundColor,
          customGradient: customGradient,
          onStateCreated: (state) {
            _currentState = state;
          },
          onRemove: () {
            if (isRemoved) return;
            isRemoved = true;
            if (_currentOverlay == entry) {
              _currentOverlay = null;
              _currentState = null;
            }
            try {
              entry.remove();
            } catch (e) {
              debugPrint('Error removing overlay: $e');
            }
          },
        ),
      );

      _currentOverlay = entry;
      overlayState.insert(entry);
    });
  }

  /// Descarta la notificación actual si está visible.
  static void dismiss() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentOverlay != null) {
        try {
          _currentOverlay!.remove();
        } catch (e) {
          debugPrint('Error dismissing overlay: $e');
        }
        _currentOverlay = null;
        _currentState = null;
      }
    });
  }
}

class _InAppNotificationWidget extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? customGradient;
  final ValueChanged<_InAppNotificationWidgetState> onStateCreated;
  final VoidCallback onRemove;

  const _InAppNotificationWidget({
    required this.title,
    required this.body,
    this.onTap,
    this.backgroundColor,
    this.customGradient,
    required this.onStateCreated,
    required this.onRemove,
  });

  @override
  State<_InAppNotificationWidget> createState() => _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<_InAppNotificationWidget> {
  bool _isVisible = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    print('🎨 [_InAppNotificationWidgetState.initState] Montando el widget de banner de notificación.');
    widget.onStateCreated(this);

    // Activamos la visibilidad en el siguiente frame para iniciar la animación de entrada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });

    // Auto-dismiss tras 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_isDismissed) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    if (_isDismissed) return;
    if (!mounted) return;

    setState(() {
      _isDismissed = true;
      _isVisible = false;
    });

    // Esperar 400ms a que termine la animación de salida antes de remover el overlay
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      widget.onRemove();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Definimos el color de glow o sombra basados en la presencia de color personalizado
    final shadowColor = widget.backgroundColor ?? const Color(0xFF1B6F81);
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double targetTopMargin = statusBarHeight > 0 ? statusBarHeight + 10 : 24;

    // Si no es visible, el banner se coloca arriba fuera de la pantalla (-130)
    final double currentTopMargin = _isVisible ? targetTopMargin : -130;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      top: currentTopMargin,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: _isVisible ? 1.0 : 0.0,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              // Si el usuario desliza hacia arriba, cerramos la notificación
              if (details.primaryDelta! < -4) {
                _dismiss();
              }
            },
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
              }
              _dismiss();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor?.withOpacity(0.9),
                      gradient: widget.backgroundColor == null
                          ? (widget.customGradient ?? LinearGradient(
                              colors: [
                                const Color(0xFF0F3D4A).withOpacity(0.88),
                                const Color(0xFF1B6F81).withOpacity(0.88),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ))
                          : null,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.24),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo de la marca en contenedor circular translúcido
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Image.asset(
                                'assets/logob.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback si la imagen no carga por alguna razón
                                  return const Icon(
                                    Icons.local_drink_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Contenido de texto
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.body,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón de descarte elegante
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white60,
                            size: 22,
                          ),
                          onPressed: _dismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
