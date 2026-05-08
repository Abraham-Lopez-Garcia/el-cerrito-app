import 'partido_model.dart';

class Jornada {
  final String id;
  final String ligaId;
  final String temporadaId;
  final int numero;
  final DateTime? createdAt;
  // Los partidos se cargan como subcolección — no viven aquí directamente.
  // Se populan solo cuando se carga el detalle de la jornada.
  final List<Partido> partidos;

  const Jornada({
    required this.id,
    required this.ligaId,
    required this.temporadaId,
    required this.numero,
    this.createdAt,
    this.partidos = const [],
  });

  factory Jornada.fromFirestore(String id, Map<String, dynamic> data) {
    return Jornada(
      id: id,
      ligaId: data['ligaId'] as String? ?? '',
      temporadaId: data['temporadaId'] as String? ?? '',
      numero: (data['numero'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ligaId': ligaId,
      'temporadaId': temporadaId,
      'numero': numero,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  Jornada copyWith({
    String? id,
    String? ligaId,
    String? temporadaId,
    int? numero,
    DateTime? createdAt,
    List<Partido>? partidos,
  }) {
    return Jornada(
      id: id ?? this.id,
      ligaId: ligaId ?? this.ligaId,
      temporadaId: temporadaId ?? this.temporadaId,
      numero: numero ?? this.numero,
      createdAt: createdAt ?? this.createdAt,
      partidos: partidos ?? this.partidos,
    );
  }
}
