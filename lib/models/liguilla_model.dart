// lib/models/liguilla_model.dart

class Liguilla {
  final String id;
  final String temporadaId;
  final String estado; // 'en_curso' | 'finalizada'
  final DateTime fechaInicio;

  const Liguilla({
    required this.id,
    required this.temporadaId,
    required this.estado,
    required this.fechaInicio,
  });

  factory Liguilla.fromMap(String id, Map<String, dynamic> m) => Liguilla(
    id: id,
    temporadaId: m['temporadaId'] as String? ?? '',
    estado: m['estado'] as String? ?? 'en_curso',
    fechaInicio: (m['fechaInicio'] as dynamic)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'temporadaId': temporadaId,
    'estado': estado,
    'fechaInicio': fechaInicio,
  };
}

/// Representa UN partido (ida O vuelta) dentro de un cruce.
/// Dos PartidoLiguilla con el mismo [cruceId] forman el cruce completo.
class PartidoLiguilla {
  final String id;
  final String liguillaId;
  final String ronda; // 'cuartos' | 'semis' | 'final'
  final int orden; // 1-4 en cuartos, 1-2 en semis, 1 en final
  final int posicion; // slot del ganador en el siguiente partido (1 o 2)
  final String? siguientePartidoId; // ID del partido de ida del siguiente cruce

  // ── Cruce (ida + vuelta) ──────────────────────────────────────────────────
  /// Identificador compartido entre los dos partidos del mismo cruce.
  final String? cruceId;

  /// 1 = ida (local = equipo1), 2 = vuelta (local = equipo2).
  final int numeroPartido;

  // ── Equipos ───────────────────────────────────────────────────────────────
  final String? equipo1Id;
  final String equipo1Nombre;
  final String equipo1LogoUrl;
  final String? equipo2Id;
  final String equipo2Nombre;
  final String equipo2LogoUrl;

  // ── Resultado de ESTE partido ─────────────────────────────────────────────
  final int? golesEquipo1;
  final int? golesEquipo2;
  final bool penales;
  final String? ganadorPenalesId;

  // ── Ganador del CRUCE (solo se llena cuando ambos partidos están jugados) ─
  final String? ganadorCruceId;

  /// true solo en el partido de vuelta cuando el cruce está resuelto.
  final bool cruceResuelto;

  final bool jugado;

  final DateTime? fecha;
  final String? hora;

  const PartidoLiguilla({
    required this.id,
    required this.liguillaId,
    required this.ronda,
    required this.orden,
    required this.posicion,
    this.siguientePartidoId,
    this.cruceId,
    this.numeroPartido = 1,
    this.equipo1Id,
    this.equipo1Nombre = '',
    this.equipo1LogoUrl = '',
    this.equipo2Id,
    this.equipo2Nombre = '',
    this.equipo2LogoUrl = '',
    this.golesEquipo1,
    this.golesEquipo2,
    this.penales = false,
    this.ganadorPenalesId,
    this.ganadorId,
    this.ganadorCruceId,
    this.cruceResuelto = false,
    this.jugado = false,
    this.fecha,
    this.hora,
  });

  // Alias de compatibilidad — el ganador del CRUCE actúa como "ganadorId"
  // en la lógica del bracket (propagar al siguiente partido).
  final String? ganadorId;

  bool get tieneResultado =>
      jugado && golesEquipo1 != null && golesEquipo2 != null;
  bool get listo => equipo1Id != null && equipo2Id != null;
  bool get esVuelta => numeroPartido == 2;
  bool get esIda => numeroPartido == 1;

  factory PartidoLiguilla.fromMap(String id, Map<String, dynamic> m) =>
      PartidoLiguilla(
        id: id,
        liguillaId: m['liguillaId'] as String? ?? '',
        ronda: m['ronda'] as String? ?? 'cuartos',
        orden: (m['orden'] as num?)?.toInt() ?? 1,
        posicion: (m['posicion'] as num?)?.toInt() ?? 1,
        siguientePartidoId: m['siguientePartidoId'] as String?,
        cruceId: m['cruceId'] as String?,
        numeroPartido: (m['numeroPartido'] as num?)?.toInt() ?? 1,
        equipo1Id: m['equipo1Id'] as String?,
        equipo1Nombre: m['equipo1Nombre'] as String? ?? '',
        equipo1LogoUrl: m['equipo1LogoUrl'] as String? ?? '',
        equipo2Id: m['equipo2Id'] as String?,
        equipo2Nombre: m['equipo2Nombre'] as String? ?? '',
        equipo2LogoUrl: m['equipo2LogoUrl'] as String? ?? '',
        golesEquipo1: (m['golesEquipo1'] as num?)?.toInt(),
        golesEquipo2: (m['golesEquipo2'] as num?)?.toInt(),
        penales: m['penales'] as bool? ?? false,
        ganadorPenalesId: m['ganadorPenalesId'] as String?,
        ganadorId: m['ganadorId'] as String?,
        ganadorCruceId: m['ganadorCruceId'] as String?,
        cruceResuelto: m['cruceResuelto'] as bool? ?? false,
        jugado: m['jugado'] as bool? ?? false,
        fecha: m['fecha'] != null
            ? DateTime.tryParse(m['fecha'] as String)
            : null,
        hora: m['hora'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'liguillaId': liguillaId,
    'ronda': ronda,
    'orden': orden,
    'posicion': posicion,
    'siguientePartidoId': siguientePartidoId,
    'cruceId': cruceId,
    'numeroPartido': numeroPartido,
    'equipo1Id': equipo1Id,
    'equipo1Nombre': equipo1Nombre,
    'equipo1LogoUrl': equipo1LogoUrl,
    'equipo2Id': equipo2Id,
    'equipo2Nombre': equipo2Nombre,
    'equipo2LogoUrl': equipo2LogoUrl,
    'golesEquipo1': golesEquipo1,
    'golesEquipo2': golesEquipo2,
    'penales': penales,
    'ganadorPenalesId': ganadorPenalesId,
    'ganadorId': ganadorId,
    'ganadorCruceId': ganadorCruceId,
    'cruceResuelto': cruceResuelto,
    'jugado': jugado,
    if (fecha != null) 'fecha': fecha!.toIso8601String(),
    if (hora != null) 'hora': hora,
  };

  PartidoLiguilla copyWith({
    String? equipo1Id,
    String? equipo1Nombre,
    String? equipo1LogoUrl,
    String? equipo2Id,
    String? equipo2Nombre,
    String? equipo2LogoUrl,
    int? golesEquipo1,
    int? golesEquipo2,
    bool? penales,
    String? ganadorPenalesId,
    String? ganadorId,
    String? ganadorCruceId,
    bool? cruceResuelto,
    bool? jugado,
  }) => PartidoLiguilla(
    id: id,
    liguillaId: liguillaId,
    ronda: ronda,
    orden: orden,
    posicion: posicion,
    siguientePartidoId: siguientePartidoId,
    cruceId: cruceId,
    numeroPartido: numeroPartido,
    equipo1Id: equipo1Id ?? this.equipo1Id,
    equipo1Nombre: equipo1Nombre ?? this.equipo1Nombre,
    equipo1LogoUrl: equipo1LogoUrl ?? this.equipo1LogoUrl,
    equipo2Id: equipo2Id ?? this.equipo2Id,
    equipo2Nombre: equipo2Nombre ?? this.equipo2Nombre,
    equipo2LogoUrl: equipo2LogoUrl ?? this.equipo2LogoUrl,
    golesEquipo1: golesEquipo1 ?? this.golesEquipo1,
    golesEquipo2: golesEquipo2 ?? this.golesEquipo2,
    penales: penales ?? this.penales,
    ganadorPenalesId: ganadorPenalesId ?? this.ganadorPenalesId,
    ganadorId: ganadorId ?? this.ganadorId,
    ganadorCruceId: ganadorCruceId ?? this.ganadorCruceId,
    cruceResuelto: cruceResuelto ?? this.cruceResuelto,
    jugado: jugado ?? this.jugado,
  );
}

/// Agrupa los dos partidos (ida + vuelta) de un cruce.
/// Útil para el bracket y la vista de partidos.
class Cruce {
  final PartidoLiguilla ida;
  final PartidoLiguilla? vuelta;

  const Cruce({required this.ida, this.vuelta});

  String get ronda => ida.ronda;
  int get orden => ida.orden;
  String? get cruceId => ida.cruceId;

  // Equipos
  String? get equipo1Id => ida.equipo1Id;
  String get equipo1Nombre => ida.equipo1Nombre;
  String get equipo1LogoUrl => ida.equipo1LogoUrl;
  String? get equipo2Id => ida.equipo2Id;
  String get equipo2Nombre => ida.equipo2Nombre;
  String get equipo2LogoUrl => ida.equipo2LogoUrl;

  bool get tieneEquipos => equipo1Id != null && equipo2Id != null;

  // Goles globales (suma ida + vuelta)
  // CORRECTO — en vuelta los equipos están invertidos en el doc
  int get golesGlobalesEq1 =>
      (ida.golesEquipo1 ?? 0) + (vuelta?.golesEquipo2 ?? 0);
  int get golesGlobalesEq2 =>
      (ida.golesEquipo2 ?? 0) + (vuelta?.golesEquipo1 ?? 0);

  bool get idaJugada => ida.jugado;
  bool get vueltaJugada => vuelta?.jugado ?? false;
  bool get ambosJugados => idaJugada && vueltaJugada;

  /// El cruce está resuelto cuando la vuelta tiene ganadorCruceId.
  bool get resuelto => vuelta?.cruceResuelto == true || ida.cruceResuelto;

  String? get ganadorCruceId => vuelta?.ganadorCruceId ?? ida.ganadorCruceId;

  String get ganadorNombre {
    if (ganadorCruceId == null) return '';
    return ganadorCruceId == equipo1Id ? equipo1Nombre : equipo2Nombre;
  }

  String get ganadorLogoUrl {
    if (ganadorCruceId == null) return '';
    return ganadorCruceId == equipo1Id ? equipo1LogoUrl : equipo2LogoUrl;
  }

  /// Quién va ganando globalmente (para mostrar en bracket antes de resolverse).
  String? get liderGlobal {
    if (!idaJugada) return null;
    if (golesGlobalesEq1 > golesGlobalesEq2) return equipo1Id;
    if (golesGlobalesEq2 > golesGlobalesEq1) return equipo2Id;
    return null; // empate global
  }
}
