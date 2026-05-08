class EquipoBase {
  final String id;
  final String ligaId;
  final String nombre;
  final String color;
  final String logoUrl;
  final DateTime? createdAt;

  const EquipoBase({
    required this.id,
    required this.ligaId,
    required this.nombre,
    required this.color,
    required this.logoUrl,
    this.createdAt,
  });

  factory EquipoBase.fromFirestore(String id, Map<String, dynamic> data) {
    return EquipoBase(
      id: id,
      ligaId: data['ligaId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      color: data['color'] as String? ?? '#000000',
      logoUrl: data['logoUrl'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'ligaId': ligaId,
    'nombre': nombre,
    'color': color,
    'logoUrl': logoUrl,
    'createdAt':
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  EquipoBase copyWith({String? nombre, String? color, String? logoUrl}) =>
      EquipoBase(
        id: id,
        ligaId: ligaId,
        nombre: nombre ?? this.nombre,
        color: color ?? this.color,
        logoUrl: logoUrl ?? this.logoUrl,
        createdAt: createdAt,
      );
}
