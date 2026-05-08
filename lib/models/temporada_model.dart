class Temporada {
  final String id;
  final String ligaId;
  final String nombre;
  final int numero;
  final bool isActive;
  final DateTime? createdAt;
  final int totalGoles;
  final int totalPartidos; // ← nuevo
  final int totalJornadas; // ← nuevo
  final String faseActual; // 'liga' | 'liguilla'

  const Temporada({
    required this.id,
    required this.ligaId,
    required this.nombre,
    required this.numero,
    this.isActive = false,
    this.createdAt,
    this.totalGoles = 0,
    this.totalPartidos = 0, // ← nuevo
    this.totalJornadas = 0, // ← nuevo
    this.faseActual = 'liga',
  });

  factory Temporada.fromFirestore(String id, Map<String, dynamic> data) {
    return Temporada(
      id: id,
      ligaId: data['ligaId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Temporada $id',
      numero: (data['numero'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
      totalGoles: (data['totalGoles'] as num?)?.toInt() ?? 0, // ← nuevo
      totalJornadas: (data['totalJornadas'] as num?)?.toInt() ?? 0, // ← nuevo
      totalPartidos: (data['totalPartidos'] as num?)?.toInt() ?? 0,
      faseActual: data['faseActual'] as String? ?? 'liga',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ligaId': ligaId,
      'nombre': nombre,
      'numero': numero,
      'isActive': isActive,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}

class Liga {
  final String id;
  final String nombre;
  final String? temporadaActualId;
  final String adminUid; // UID de Firebase Auth del administrador

  const Liga({
    required this.id,
    required this.nombre,
    this.temporadaActualId,
    required this.adminUid,
  });

  factory Liga.fromFirestore(String id, Map<String, dynamic> data) {
    return Liga(
      id: id,
      nombre: data['nombre'] as String? ?? 'Liga',
      temporadaActualId: data['temporadaActualId'] as String?,
      adminUid: data['adminUid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      if (temporadaActualId != null) 'temporadaActualId': temporadaActualId,
      'adminUid': adminUid,
    };
  }
}
