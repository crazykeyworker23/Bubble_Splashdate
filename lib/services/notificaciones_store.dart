import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/services/app_http.dart' as http;

/// Una notificación recibida, tal como se guarda en el teléfono.
class NotificacionGuardada {
  final String id;
  final String titulo;
  final String cuerpo;
  final Map<String, dynamic> datos;
  final DateTime fecha;
  final bool leida;

  const NotificacionGuardada({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.datos,
    required this.fecha,
    required this.leida,
  });

  String get tipo => (datos['tipo'] ?? '').toString().toUpperCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'cuerpo': cuerpo,
    'datos': datos,
    'fecha': fecha.toIso8601String(),
    'leida': leida,
  };

  factory NotificacionGuardada.fromJson(Map<String, dynamic> j) {
    return NotificacionGuardada(
      id: (j['id'] ?? '').toString(),
      titulo: (j['titulo'] ?? '').toString(),
      cuerpo: (j['cuerpo'] ?? '').toString(),
      datos: Map<String, dynamic>.from(j['datos'] ?? const {}),
      fecha:
          DateTime.tryParse((j['fecha'] ?? '').toString()) ?? DateTime.now(),
      leida: j['leida'] == true,
    );
  }

  NotificacionGuardada copiaLeida() => NotificacionGuardada(
    id: id,
    titulo: titulo,
    cuerpo: cuerpo,
    datos: datos,
    fecha: fecha,
    leida: true,
  );
}

/// Historial de notificaciones.
///
/// LA FUENTE ES EL SERVIDOR. La copia del teléfono existe solo para poder
/// enseñar algo sin conexión y para contar los no leídos sin esperar a la red.
///
/// Se hizo así porque antes había dos historiales que no se hablaban —el del
/// navegador del panel y el del teléfono—, de modo que el equipo veía una
/// lista distinta en cada ordenador y borrar en el panel no llegaba al
/// cliente. Ahora ambos leen de la misma tabla.
class NotificacionesStore {
  /// Prefijo de la copia local. La clave real lleva el id del usuario detrás.
  ///
  /// UNA COPIA POR PERSONA, y no una sola compartida.
  ///
  /// Antes había una única lista y, para que un usuario no viera la de otro,
  /// se borraba al cerrar sesión. El efecto secundario era que su propio dueño
  /// también la perdía y tenía que esperar a la sincronización para recuperar
  /// lo suyo. Separándola por usuario, cada uno conserva la suya y nadie ve la
  /// ajena: al volver a entrar, sus notificaciones ya están ahí.
  static const String _prefijo = 'notificaciones_de_';

  /// Clave de la copia del usuario en sesión, o null si aún no se sabe quién
  /// es. En ese caso no se enseña nada: es preferible una lista vacía un
  /// instante que la lista de otra persona.
  static Future<String?> _claveDelUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id') ?? 0;
    return id > 0 ? '$_prefijo$id' : null;
  }

  /// Cuántas se conservan en el teléfono. Más allá, la copia local solo ocupa:
  /// lo antiguo se pide al servidor cuando hace falta.
  static const int _maximo = 60;

  /// Cuántas se muestran de entrada.
  ///
  /// El resto se carga al pulsar «ver anteriores». Una lista que se abre con
  /// doscientas notificaciones tarda y no se lee; las últimas quince son las
  /// que de verdad se miran.
  static const int primeraTanda = 15;

  /// Cuántas hay en total en el servidor. Sirve para saber si quedan más por
  /// cargar. Se actualiza en cada sincronización.
  static int totalEnServidor = 0;

  /// Trae las siguientes notificaciones SIN tocar la copia local.
  ///
  /// Se pide por `yaCargadas` —«tengo N, dame lo que sigue»— y no por número
  /// de página. Paginar por página obliga a que la lista lleve exactamente el
  /// mismo tamaño por página, y no lo lleva: mientras está abierta se le
  /// suman las notificaciones que llegan por push. Con esa desalineación el
  /// servidor devolvía elementos ya mostrados, se descartaban por repetidos y
  /// la tanda salía vacía: el botón parecía no hacer nada.
  static Future<List<NotificacionGuardada>> siguientes(
    int yaCargadas, {
    int cuantas = primeraTanda,
  }) async {
    try {
      final response = await http.get(
        BackendConfig.api(
          'bubblesplash/notificaciones/'
          '?offset=$yaCargadas&page_size=$cuantas',
        ),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];

      totalEnServidor = int.tryParse((decoded['count'] ?? 0).toString()) ?? 0;

      final lista = decoded['results'];
      if (lista is! List) return [];

      return [
        for (final fila in lista.whereType<Map<String, dynamic>>())
          NotificacionGuardada(
            id: (fila['id'] ?? '').toString(),
            titulo: (fila['titulo'] ?? '').toString(),
            cuerpo: (fila['cuerpo'] ?? '').toString(),
            datos: {
              ...Map<String, dynamic>.from(fila['datos'] ?? const {}),
              if ((fila['imagen'] ?? '').toString().isNotEmpty)
                'imagen': fila['imagen'],
            },
            fecha:
                DateTime.tryParse((fila['fecha'] ?? '').toString()) ??
                DateTime.now(),
            leida: fila['leida'] == true,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<List<NotificacionGuardada>> listar() async {
    try {
      final clave = await _claveDelUsuario();
      if (clave == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo == null || crudo.isEmpty) return [];

      final lista = jsonDecode(crudo);
      if (lista is! List) return [];

      final items = lista
          .whereType<Map<String, dynamic>>()
          .map(NotificacionGuardada.fromJson)
          .toList();

      items.sort((a, b) => b.fecha.compareTo(a.fecha));
      return items;
    } catch (_) {
      // Un historial corrupto no debe impedir abrir la pantalla.
      return [];
    }
  }

  /// Trae el historial del servidor y refresca la copia local.
  ///
  /// Devuelve `false` si no se pudo (sin red, sin sesión): quien llama sigue
  /// con lo que haya guardado en vez de quedarse con la pantalla vacía.
  static Future<bool> sincronizar({int cuantas = primeraTanda}) async {
    try {
      final response = await http.get(
        BackendConfig.api(
          'bubblesplash/notificaciones/?page=1&page_size=$cuantas',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;

      final lista = decoded['results'];
      if (lista is! List) return false;

      // Se conserva cuáles marcó como leídas sin conexión: esa marca puede no
      // haber llegado aún al servidor, y perderla las devolvería a «sin leer».
      final leidasLocales = {
        for (final n in await listar())
          if (n.leida) n.id,
      };

      final items = <NotificacionGuardada>[];
      for (final fila in lista.whereType<Map<String, dynamic>>()) {
        final id = (fila['id'] ?? '').toString();
        items.add(
          NotificacionGuardada(
            id: id,
            titulo: (fila['titulo'] ?? '').toString(),
            cuerpo: (fila['cuerpo'] ?? '').toString(),
            datos: {
              ...Map<String, dynamic>.from(fila['datos'] ?? const {}),
              if ((fila['imagen'] ?? '').toString().isNotEmpty)
                'imagen': fila['imagen'],
            },
            fecha:
                DateTime.tryParse((fila['fecha'] ?? '').toString()) ??
                DateTime.now(),
            leida: fila['leida'] == true || leidasLocales.contains(id),
          ),
        );
      }

      final clave = await _claveDelUsuario();
      if (clave == null) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        clave,
        jsonEncode(items.map((n) => n.toJson()).toList()),
      );
      totalEnServidor = int.tryParse((decoded['count'] ?? 0).toString()) ?? 0;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<int> sinLeer() async {
    final items = await listar();
    return items.where((n) => !n.leida).length;
  }

  /// Guarda una notificación recién recibida.
  ///
  /// `id` suele ser el `messageId` de Firebase. Se usa para no duplicar: el
  /// mismo mensaje puede pasar por el listener de primer plano y por el
  /// handler de segundo plano, y aparecería dos veces en la lista.
  static Future<void> guardar({
    required String id,
    required String titulo,
    required String cuerpo,
    Map<String, dynamic> datos = const {},
  }) async {
    if (titulo.trim().isEmpty && cuerpo.trim().isEmpty) return;

    try {
      final clave = await _claveDelUsuario();
      if (clave == null) return;

      final prefs = await SharedPreferences.getInstance();
      final items = await listar();

      final identificador = id.trim().isNotEmpty
          ? id.trim()
          : '${DateTime.now().millisecondsSinceEpoch}';

      if (items.any((n) => n.id == identificador)) return;

      items.insert(
        0,
        NotificacionGuardada(
          id: identificador,
          titulo: titulo,
          cuerpo: cuerpo,
          datos: datos,
          fecha: DateTime.now(),
          leida: false,
        ),
      );

      final recortadas = items.take(_maximo).toList();
      await prefs.setString(
        clave,
        jsonEncode(recortadas.map((n) => n.toJson()).toList()),
      );
    } catch (_) {
      // Guardar el historial nunca debe romper la entrega de la notificación.
    }
  }

  static Future<void> marcarLeida(String id) async {
    // Se avisa al servidor sin esperar: la marca local ya deja la interfaz
    // correcta, y si el envío falla se recupera en la siguiente sincronización.
    _avisarServidor({'id': int.tryParse(id) ?? id});
    try {
      final clave = await _claveDelUsuario();
      if (clave == null) return;

      final prefs = await SharedPreferences.getInstance();
      final items = await listar();
      final nuevas = items
          .map((n) => n.id == id ? n.copiaLeida() : n)
          .toList();
      await prefs.setString(
        clave,
        jsonEncode(nuevas.map((n) => n.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> marcarTodasLeidas() async {
    _avisarServidor({'todas': true});
    try {
      final clave = await _claveDelUsuario();
      if (clave == null) return;

      final prefs = await SharedPreferences.getInstance();
      final items = await listar();
      await prefs.setString(
        clave,
        jsonEncode(items.map((n) => n.copiaLeida().toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Comunica al servidor que algo se leyó.
  ///
  /// No se espera la respuesta ni se avisa de un fallo: la marca local ya deja
  /// la pantalla correcta, y si el envío no llega se corrige solo en la
  /// siguiente sincronización.
  static void _avisarServidor(Map<String, dynamic> cuerpo) {
    () async {
      try {
        await http.post(
          BackendConfig.api('bubblesplash/notificaciones/leida/'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(cuerpo),
        );
      } catch (_) {}
    }();
  }

  /// Ya no borra nada.
  ///
  /// Se llamaba al cerrar e iniciar sesión para que nadie viera lo ajeno. Con
  /// una copia por usuario eso ya no hace falta: al cerrar sesión se olvida
  /// QUIÉN está dentro (`user_id`), y sin ese dato no se lee ninguna lista.
  /// Al volver a entrar, el mismo usuario recupera la suya intacta.
  ///
  /// Se conserva el método porque lo llaman el login y el logout, y para no
  /// dejar la puerta abierta a que alguien lo reintroduzca como borrado.
  static Future<void> limpiar() async {}

  static Future<void> borrarTodas() async {
    try {
      final clave = await _claveDelUsuario();
      if (clave == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(clave);
    } catch (_) {}
  }
}
