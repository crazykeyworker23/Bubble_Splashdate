import 'package:flutter/material.dart';

import 'package:bubblesplash/services/notificacion_router.dart';
import 'package:bubblesplash/services/notificaciones_store.dart';

/// Listado de las notificaciones recibidas en este teléfono.
///
/// Cada una lleva al mismo sitio que llevaría tocarla en la bandeja del
/// sistema: el destino lo decide `NotificacionRouter`, no esta pantalla, para
/// que ambos caminos no puedan divergir.
class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  static const Color _brandDeep = Color(0xFF0F3D4A);
  static const Color _brandMid = Color(0xFF128FA0);

  List<NotificacionGuardada> _items = [];
  bool _cargando = true;

  bool _cargandoAnteriores = false;

  /// ¿Quedan notificaciones más antiguas por traer?
  bool get _hayAnteriores =>
      NotificacionesStore.totalEnServidor > _items.length;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool desdeServidor = true}) async {
    // Se pinta primero lo guardado y luego se refresca: así la lista aparece
    // al instante y no en blanco mientras responde la red.
    final locales = await NotificacionesStore.listar();
    if (mounted) {
      setState(() {
        _items = locales;
        _cargando = false;
      });
    }

    if (!desdeServidor) return;

    final ok = await NotificacionesStore.sincronizar();
    if (!ok || !mounted) return;

    final items = await NotificacionesStore.listar();
    if (!mounted) return;
    setState(() => _items = items);
  }

  /// Trae la siguiente tanda de notificaciones antiguas.
  Future<void> _verAnteriores() async {
    setState(() => _cargandoAnteriores = true);

    // Se le dice al servidor cuántas se tienen ya, no qué página toca: así no
    // hay forma de desalinearse con lo que hay en pantalla.
    final nuevas = await NotificacionesStore.siguientes(_items.length);
    if (!mounted) return;

    setState(() {
      final vistos = _items.map((n) => n.id).toSet();
      _items = [..._items, ...nuevas.where((n) => !vistos.contains(n.id))];
      _cargandoAnteriores = false;
    });
  }

  Future<void> _abrir(NotificacionGuardada n) async {
    await NotificacionesStore.marcarLeida(n.id);
    if (!mounted) return;
    // Se refresca antes de navegar para que al volver el punto de «sin leer»
    // ya no esté: volver y verlo intacto parece que el toque no funcionó.
    await _cargar(desdeServidor: false);
    await NotificacionRouter.abrir(
      n.datos,
      titulo: n.titulo,
      cuerpo: n.cuerpo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final haySinLeer = _items.any((n) => !n.leida);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandDeep, _brandMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (haySinLeer)
            TextButton(
              onPressed: () async {
                await NotificacionesStore.marcarTodasLeidas();
                await _cargar();
              },
              child: const Text(
                'Marcar leídas',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _vacio()
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                // Una fila extra al final para el botón de «ver anteriores».
                itemCount: _items.length + (_hayAnteriores ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i >= _items.length) return _botonAnteriores();
                  return _tarjeta(_items[i]);
                },
              ),
            ),
    );
  }

  Widget _botonAnteriores() {
    final quedan = NotificacionesStore.totalEnServidor - _items.length;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: OutlinedButton.icon(
        onPressed: _cargandoAnteriores ? null : _verAnteriores,
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandMid,
          side: const BorderSide(color: _brandMid),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _cargandoAnteriores
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : const Icon(Icons.history, size: 18),
        label: Text(
          _cargandoAnteriores
              ? 'Cargando…'
              : 'Ver notificaciones anteriores ($quedan)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _vacio() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.notifications_none_rounded,
          size: 64,
          color: Colors.black.withValues(alpha: 0.18),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Aún no tienes notificaciones',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F3D4A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Aquí aparecerán tus pedidos, recargas y las novedades que te '
              'enviemos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.8,
                height: 1.4,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(NotificacionGuardada n) {
    final aspecto = _aspecto(n.tipo);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrir(n),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: n.leida ? Colors.white : const Color(0xFFEFF8FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.leida ? const Color(0xFFE5EEF5) : const Color(0xFFB6E3DF),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: aspecto.$2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(aspecto.$1, color: aspecto.$2, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.titulo.isEmpty ? 'Notificación' : n.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: n.leida
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                              color: const Color(0xFF102A33),
                            ),
                          ),
                        ),
                        if (!n.leida) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: _brandMid,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (n.cuerpo.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        n.cuerpo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.8,
                          height: 1.35,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _haceCuanto(n.fecha),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA5AB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Icono y color según el tipo que manda el servidor.
  (IconData, Color) _aspecto(String tipo) {
    switch (tipo) {
      case 'RECARGA':
      case 'RECARGA_SEDE':
        return (Icons.account_balance_wallet, const Color(0xFF16A34A));
      case 'PEDIDO':
      case 'PEDIDO_NUEVO':
        return (Icons.local_mall, _brandMid);
      case 'PEDIDO_ESTADO':
        return (Icons.local_shipping, const Color(0xFF1565C0));
      case 'DESCUENTO':
      case 'OFERTA':
        return (Icons.local_offer, const Color(0xFFC2410C));
      case 'PRUEBA':
        return (Icons.science, const Color(0xFF7B3FA0));
      case 'AVISO':
        return (Icons.campaign, const Color(0xFFB3245C));
      default:
        return (Icons.notifications, _brandDeep);
    }
  }

  String _haceCuanto(DateTime fecha) {
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'Justo ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    if (d.inDays == 1) return 'Ayer';
    if (d.inDays < 7) return 'Hace ${d.inDays} días';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
