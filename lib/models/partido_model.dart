import 'goleador_model.dart';

class Partido {
  final String id;
  final String equipo1Id;
  final String equipo1Nombre; // desnormalizado
  final String? equipo1LogoUrl; // desnormalizado
  final String equipo2Id;
  final String equipo2Nombre; // desnormalizado
  final String? equipo2LogoUrl; // desnormalizado
  final int? golesEquipo1; // null = partido no jugado todavía
  final int? golesEquipo2;
  final bool penales;
  final String? ganadorPenalesId;
  final List<Goleador>
  goleadores; // todos los goleadores del partido (ambos equipos)
  final DateTime? fecha;
  final String? hora; // formato "HH:mm"
  final bool jugado;

  const Partido({
    required this.id,
    required this.equipo1Id,
    required this.equipo1Nombre,
    this.equipo1LogoUrl,
    required this.equipo2Id,
    required this.equipo2Nombre,
    this.equipo2LogoUrl,
    this.golesEquipo1,
    this.golesEquipo2,
    this.penales = false,
    this.ganadorPenalesId,
    this.goleadores = const [],
    this.fecha,
    this.hora,
    this.jugado = false,
  });

  bool get tieneResultado => golesEquipo1 != null && golesEquipo2 != null;

  List<Goleador> get goleadoresEquipo1 =>
      goleadores.where((g) => g.equipoId == equipo1Id).toList();

  List<Goleador> get goleadoresEquipo2 =>
      goleadores.where((g) => g.equipoId == equipo2Id).toList();

  factory Partido.fromFirestore(String id, Map<String, dynamic> data) {
    final goleadoresList =
        (data['goleadores'] as List<dynamic>?)
            ?.map((g) => Goleador.fromMap(Map<String, dynamic>.from(g as Map)))
            .toList() ??
        [];

    return Partido(
      id: id,
      equipo1Id: data['equipo1Id'] as String? ?? '',
      equipo1Nombre: data['equipo1Nombre'] as String? ?? '',
      equipo1LogoUrl: data['equipo1LogoUrl'] as String?,
      equipo2Id: data['equipo2Id'] as String? ?? '',
      equipo2Nombre: data['equipo2Nombre'] as String? ?? '',
      equipo2LogoUrl: data['equipo2LogoUrl'] as String?,
      golesEquipo1: (data['golesEquipo1'] as num?)?.toInt(),
      golesEquipo2: (data['golesEquipo2'] as num?)?.toInt(),
      penales: data['penales'] as bool? ?? false,
      ganadorPenalesId: data['ganadorPenalesId'] as String?,
      goleadores: goleadoresList,
      fecha: data['fecha'] != null
          ? DateTime.tryParse(data['fecha'].toString())
          : null,
      hora: data['hora'] as String?,
      jugado: data['jugado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'equipo1Id': equipo1Id,
      'equipo1Nombre': equipo1Nombre,
      if (equipo1LogoUrl != null) 'equipo1LogoUrl': equipo1LogoUrl,
      'equipo2Id': equipo2Id,
      'equipo2Nombre': equipo2Nombre,
      if (equipo2LogoUrl != null) 'equipo2LogoUrl': equipo2LogoUrl,
      if (golesEquipo1 != null) 'golesEquipo1': golesEquipo1,
      if (golesEquipo2 != null) 'golesEquipo2': golesEquipo2,
      'penales': penales,
      if (ganadorPenalesId != null) 'ganadorPenalesId': ganadorPenalesId,
      'goleadores': goleadores.map((g) => g.toMap()).toList(),
      if (fecha != null) 'fecha': fecha!.toIso8601String(),
      if (hora != null) 'hora': hora,
      'jugado': jugado,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  Partido copyWith({
    String? id,
    int? golesEquipo1,
    int? golesEquipo2,
    bool? penales,
    String? ganadorPenalesId,
    List<Goleador>? goleadores,
    DateTime? fecha,
    String? hora,
    bool? jugado,
  }) {
    return Partido(
      id: id ?? this.id,
      equipo1Id: equipo1Id,
      equipo1Nombre: equipo1Nombre,
      equipo1LogoUrl: equipo1LogoUrl,
      equipo2Id: equipo2Id,
      equipo2Nombre: equipo2Nombre,
      equipo2LogoUrl: equipo2LogoUrl,
      golesEquipo1: golesEquipo1 ?? this.golesEquipo1,
      golesEquipo2: golesEquipo2 ?? this.golesEquipo2,
      penales: penales ?? this.penales,
      ganadorPenalesId: ganadorPenalesId ?? this.ganadorPenalesId,
      goleadores: goleadores ?? this.goleadores,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      jugado: jugado ?? this.jugado,
    );
  }
}
