import 'jugador_base_model.dart';

class Jugador {
  final String id;
  final String jugadorBaseId;
  final String equipoId;
  final String equipoBaseId;
  final String temporadaId;
  final String nombre;
  final String fotoUrl;
  final String numero;
  final int goles;
  final String equipoNombre; // ← AGREGA

  const Jugador({
    required this.id,
    required this.jugadorBaseId,
    required this.equipoId,
    required this.equipoBaseId,
    required this.temporadaId,
    required this.nombre,
    this.fotoUrl = '',
    required this.numero,
    this.goles = 0,
    this.equipoNombre = '', // ← AGREGA
  });

  factory Jugador.fromFirestore(String id, Map<String, dynamic> data) {
    return Jugador(
      id: id,
      jugadorBaseId: data['jugadorBaseId'] as String? ?? '',
      equipoId: data['equipoId'] as String? ?? '',
      equipoBaseId: data['equipoBaseId'] as String? ?? '',
      temporadaId: data['temporadaId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      fotoUrl: data['fotoUrl'] as String? ?? '',
      numero: data['numero']?.toString() ?? '0',
      goles: (data['goles'] as num?)?.toInt() ?? 0,
      equipoNombre: data['equipoNombre'] as String? ?? '', // ← AGREGA
    );
  }

  factory Jugador.fromBase({
    required String id,
    required JugadorBase base,
    required String equipoId,
    required String equipoBaseId,
    required String temporadaId,
    required String numero,
  }) => Jugador(
    id: id,
    jugadorBaseId: base.id,
    equipoId: equipoId,
    equipoBaseId: equipoBaseId,
    temporadaId: temporadaId,
    nombre: base.nombre,
    fotoUrl: base.fotoUrl,
    numero: numero,
  );

  Map<String, dynamic> toFirestore() => {
    'jugadorBaseId': jugadorBaseId,
    'equipoId': equipoId,
    'equipoBaseId': equipoBaseId,
    'temporadaId': temporadaId,
    'nombre': nombre,
    'fotoUrl': fotoUrl,
    'numero': numero,
    'goles': goles,
    'equipoNombre': equipoNombre, // ← AGREGA
  };

  Jugador copyWith({
    String? nombre,
    String? fotoUrl,
    String? numero,
    int? goles,
    String? equipoId,
    String? equipoBaseId,
    String? equipoNombre, // ← AGREGA
  }) => Jugador(
    id: id,
    jugadorBaseId: jugadorBaseId,
    equipoId: equipoId ?? this.equipoId,
    equipoBaseId: equipoBaseId ?? this.equipoBaseId,
    temporadaId: temporadaId,
    nombre: nombre ?? this.nombre,
    fotoUrl: fotoUrl ?? this.fotoUrl,
    numero: numero ?? this.numero,
    goles: goles ?? this.goles,
    equipoNombre: equipoNombre ?? this.equipoNombre, // ← AGREGA
  );
}
