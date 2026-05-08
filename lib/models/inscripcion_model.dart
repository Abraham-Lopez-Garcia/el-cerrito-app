/// Representa la participación de un jugador en un equipo durante una temporada.
/// Los goles van en la colección goleadores, no aquí.
class Inscripcion {
  final String id;
  final String jugadorBaseId;
  final String equipoBaseId;
  final String equipoId; // snapshot de temporada
  final String temporadaId;
  final String numero; // número de camiseta en esta temporada
  final DateTime? createdAt;

  const Inscripcion({
    required this.id,
    required this.jugadorBaseId,
    required this.equipoBaseId,
    required this.equipoId,
    required this.temporadaId,
    required this.numero,
    this.createdAt,
  });

  factory Inscripcion.fromFirestore(String id, Map<String, dynamic> data) {
    return Inscripcion(
      id: id,
      jugadorBaseId: data['jugadorBaseId'] as String? ?? '',
      equipoBaseId: data['equipoBaseId'] as String? ?? '',
      equipoId: data['equipoId'] as String? ?? '',
      temporadaId: data['temporadaId'] as String? ?? '',
      numero: data['numero']?.toString() ?? '0',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'jugadorBaseId': jugadorBaseId,
    'equipoBaseId': equipoBaseId,
    'equipoId': equipoId,
    'temporadaId': temporadaId,
    'numero': numero,
    'createdAt':
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };
}
