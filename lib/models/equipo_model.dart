import 'equipo_base_model.dart';

class Equipo {
  final String id;
  final String ligaId;
  final String temporadaId;
  final String equipoBaseId; // ← referencia a equipos_base

  // Desnormalizado desde equipos_base para evitar joins en UI
  final String nombre;
  final String color;
  final String logoUrl;
  final int totalJugadores;

  // Stats — específicos de esta temporada
  final int pj, pg, pe, pp, gf, gc, pts;

  int get dg => gf - gc;

  const Equipo({
    required this.id,
    required this.ligaId,
    required this.temporadaId,
    required this.equipoBaseId,
    required this.nombre,
    required this.color,
    required this.logoUrl,
    this.totalJugadores = 0,
    this.pj = 0,
    this.pg = 0,
    this.pe = 0,
    this.pp = 0,
    this.gf = 0,
    this.gc = 0,
    this.pts = 0,
  });

  factory Equipo.fromFirestore(String id, Map<String, dynamic> data) {
    return Equipo(
      id: id,
      ligaId: data['ligaId'] as String? ?? '',
      temporadaId: data['temporadaId'] as String? ?? '',
      equipoBaseId: data['equipoBaseId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      color: data['color'] as String? ?? '#000000',
      logoUrl: data['logoUrl'] as String? ?? '',
      totalJugadores: (data['totalJugadores'] as num?)?.toInt() ?? 0,
      pj: (data['PJ'] as num?)?.toInt() ?? 0,
      pg: (data['PG'] as num?)?.toInt() ?? 0,
      pe: (data['PE'] as num?)?.toInt() ?? 0,
      pp: (data['PP'] as num?)?.toInt() ?? 0,
      gf: (data['GF'] as num?)?.toInt() ?? 0,
      gc: (data['GC'] as num?)?.toInt() ?? 0,
      pts: (data['Pts'] as num?)?.toInt() ?? 0,
    );
  }

  // Crear snapshot de temporada desde un EquipoBase
  factory Equipo.fromBase({
    required String id,
    required EquipoBase base,
    required String temporadaId,
  }) => Equipo(
    id: id,
    ligaId: base.ligaId,
    temporadaId: temporadaId,
    equipoBaseId: base.id,
    nombre: base.nombre,
    color: base.color,
    logoUrl: base.logoUrl,
  );

  Map<String, dynamic> toFirestore() => {
    'ligaId': ligaId,
    'temporadaId': temporadaId,
    'equipoBaseId': equipoBaseId,
    'nombre': nombre,
    'color': color,
    'logoUrl': logoUrl,
    'totalJugadores': totalJugadores,
    'PJ': pj,
    'PG': pg,
    'PE': pe,
    'PP': pp,
    'GF': gf,
    'GC': gc,
    'Pts': pts,
  };

  Map<String, dynamic> statsToFirestore() => {
    'PJ': pj,
    'PG': pg,
    'PE': pe,
    'PP': pp,
    'GF': gf,
    'GC': gc,
    'Pts': pts,
  };

  Equipo copyWith({
    String? nombre,
    String? color,
    String? logoUrl,
    int? totalJugadores,
    int? pj,
    int? pg,
    int? pe,
    int? pp,
    int? gf,
    int? gc,
    int? pts,
  }) => Equipo(
    id: id,
    ligaId: ligaId,
    temporadaId: temporadaId,
    equipoBaseId: equipoBaseId,
    nombre: nombre ?? this.nombre,
    color: color ?? this.color,
    logoUrl: logoUrl ?? this.logoUrl,
    totalJugadores: totalJugadores ?? this.totalJugadores,
    pj: pj ?? this.pj,
    pg: pg ?? this.pg,
    pe: pe ?? this.pe,
    pp: pp ?? this.pp,
    gf: gf ?? this.gf,
    gc: gc ?? this.gc,
    pts: pts ?? this.pts,
  );
}
