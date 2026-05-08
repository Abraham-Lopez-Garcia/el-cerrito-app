/// Representa un goleador dentro de un partido.
/// El nombre se desnormaliza para evitar lecturas extra a la subcolección jugadores.
class Goleador {
  final String jugadorId;
  final String nombre; // desnormalizado — se copia del jugador al guardar
  final String equipoId;
  final String equipoNombre; // ← NUEVO
  final String? fotoUrl; // ← NUEVO
  final int goles;

  const Goleador({
    required this.jugadorId,
    required this.nombre,
    required this.equipoId,
    this.equipoNombre = '', // ← NUEVO
    this.fotoUrl, // ← NUEVO
    required this.goles,
  });

  factory Goleador.fromMap(Map<String, dynamic> data) {
    return Goleador(
      jugadorId: data['jugadorId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      equipoId: data['equipoId'] as String? ?? '',
      equipoNombre: data['equipoNombre'] as String? ?? '', // ← NUEVO
      fotoUrl: data['fotoUrl'] as String?, // ← NUEVO
      goles: (data['goles'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jugadorId': jugadorId,
      'nombre': nombre,
      'equipoId': equipoId,
      'equipoNombre': equipoNombre, // ← NUEVO
      if (fotoUrl != null) 'fotoUrl': fotoUrl,
      'goles': goles,
    };
  }
}
