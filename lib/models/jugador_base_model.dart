class JugadorBase {
  final String id;
  final String ligaId;
  final String nombre;
  final String fotoUrl;
  final DateTime? createdAt;

  const JugadorBase({
    required this.id,
    required this.ligaId,
    required this.nombre,
    required this.fotoUrl,
    this.createdAt,
  });

  factory JugadorBase.fromFirestore(String id, Map<String, dynamic> data) {
    return JugadorBase(
      id: id,
      ligaId: data['ligaId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      fotoUrl: data['fotoUrl'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'ligaId': ligaId,
    'nombre': nombre,
    'fotoUrl': fotoUrl,
    'createdAt':
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  JugadorBase copyWith({String? nombre, String? fotoUrl}) => JugadorBase(
    id: id,
    ligaId: ligaId,
    nombre: nombre ?? this.nombre,
    fotoUrl: fotoUrl ?? this.fotoUrl,
    createdAt: createdAt,
  );
}
