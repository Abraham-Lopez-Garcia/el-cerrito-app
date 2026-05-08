import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/equipo_model.dart';
import '../models/equipo_base_model.dart';
import '../models/jugador_model.dart';
import '../models/jugador_base_model.dart';
import '../models/inscripcion_model.dart';
import '../models/jornada_model.dart';
import '../models/partido_model.dart';
import '../models/temporada_model.dart';
import '../models/goleador_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/liguilla_model.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;
  _CacheEntry(this.data, Duration ttl) : expiresAt = DateTime.now().add(ttl);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final _db = FirebaseFirestore.instance;

  static const String ligaId = 'liga_1';
  static const Duration _ttlCorto = Duration(minutes: 5);
  static const Duration _ttlLargo = Duration(minutes: 10);

  final ValueNotifier<String?> currentSeasonId = ValueNotifier<String?>(null);
  final ValueNotifier<List<Temporada>> seasons = ValueNotifier([]);
  final faseVista = ValueNotifier<String>('liga'); // 'liga' | 'liguilla'
  final liguillaActiva = ValueNotifier<String>('A');
  Liguilla? _currentLiguilla;
  Liguilla? get currentLiguilla => _currentLiguilla;

  final Map<String, _CacheEntry<dynamic>> _cache = {};

  // ─── Caché helpers ─────────────────────────────────────────────────────────

  T? _getCache<T>(String key) {
    final entry = _cache[key];
    if (entry != null && entry.isValid) return entry.data as T;
    _cache.remove(key);
    return null;
  }

  void _setCache<T>(String key, T data, Duration ttl) =>
      _cache[key] = _CacheEntry<T>(data, ttl);

  void _invalidateSeasonCache(String seasonId) {
    _cache.removeWhere((key, _) => key.contains(seasonId));
    debugPrint('🗑️ Caché invalidado para temporada: $seasonId');
  }

  void _invalidateForCurrentSeason(List<String> prefixes) {
    final seasonId = currentSeasonId.value;
    if (seasonId == null) return;
    for (final prefix in prefixes) {
      _cache.removeWhere((key, _) => key.startsWith('${prefix}_$seasonId'));
    }
  }

  // ─── Referencias ───────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _temporadasRef =>
      _db.collection('temporadas');
  CollectionReference<Map<String, dynamic>> get _equiposRef =>
      _db.collection('equipos');
  CollectionReference<Map<String, dynamic>> get _equiposBaseRef =>
      _db.collection('equipos_base');
  CollectionReference<Map<String, dynamic>> get _jugadoresBaseRef =>
      _db.collection('jugadores_base');
  CollectionReference<Map<String, dynamic>> get _inscripcionesRef =>
      _db.collection('inscripciones');
  CollectionReference<Map<String, dynamic>> get _jornadasRef =>
      _db.collection('jornadas');
  CollectionReference<Map<String, dynamic>> get _goleadoresRef =>
      _db.collection('goleadores');

  String get _currentSeasonId {
    if (currentSeasonId.value == null) {
      throw Exception('No hay temporada seleccionada');
    }
    return currentSeasonId.value!;
  }

  Temporada? get currentSeason {
    final id = currentSeasonId.value;
    if (id == null) return null;
    try {
      return seasons.value.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Temporadas ────────────────────────────────────────────────────────────

  Future<void> loadSeasons() async {
    try {
      final snapshot = await _temporadasRef
          .where('ligaId', isEqualTo: ligaId)
          .get();

      final loadedSeasons =
          snapshot.docs
              .map((doc) => Temporada.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => b.numero.compareTo(a.numero));

      seasons.value = loadedSeasons;
      seasons.notifyListeners();

      if (currentSeasonId.value == null && loadedSeasons.isNotEmpty) {
        final active = loadedSeasons.firstWhere(
          (s) => s.isActive,
          orElse: () => loadedSeasons.first,
        );
        currentSeasonId.value = active.id;
        currentSeasonId.notifyListeners();
        debugPrint('📍 Temporada inicial: ${active.nombre}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando temporadas: $e');
      seasons.value = [];
      seasons.notifyListeners();
    }
  }

  void setSeason(String seasonId) {
    if (currentSeasonId.value != seasonId) {
      _invalidateSeasonCache(seasonId);
      currentSeasonId.value = seasonId;
      faseVista.value = 'liga'; // resetear fase al cambiar temporada
      _currentLiguilla = null;
    }
  }

  Future<String> crearTemporada() async {
    if (currentSeasonId.value != null) {
      await _temporadasRef.doc(currentSeasonId.value).update({
        'isActive': false,
      });
    }
    final snapshot = await _temporadasRef
        .where('ligaId', isEqualTo: ligaId)
        .orderBy('numero', descending: true)
        .limit(1)
        .get();

    final nextNumero = snapshot.docs.isEmpty
        ? 1
        : (snapshot.docs.first.data()['numero'] as int) + 1;

    final ref = _temporadasRef.doc();
    await ref.set({
      'ligaId': ligaId,
      'nombre': 'Temporada $nextNumero',
      'numero': nextNumero,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await loadSeasons();
    setSeason(ref.id);
    return ref.id;
  }

  // ─── Equipos base (globales) ───────────────────────────────────────────────

  /// Todos los equipos_base de la liga — para el selector "inscribir existente"
  Future<List<EquipoBase>> getEquiposBase() async {
    const cacheKey = 'equipos_base';
    final cached = _getCache<List<EquipoBase>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _equiposBaseRef
        .where('ligaId', isEqualTo: ligaId)
        .orderBy('nombre')
        .get();

    final equipos = snapshot.docs
        .map((doc) => EquipoBase.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, equipos, _ttlLargo);
    return equipos;
  }

  /// Crea un equipo nuevo en equipos_base y lo inscribe a la temporada actual.
  /// Devuelve el id del snapshot de temporada (equipos/{id}).
  Future<String> crearEquipoNuevo({
    required String nombre,
    required String color,
    required String logoUrl,
  }) async {
    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();

    // 1 — Crear en equipos_base
    final baseRef = _equiposBaseRef.doc();
    batch.set(baseRef, {
      'ligaId': ligaId,
      'nombre': nombre,
      'color': color,
      'logoUrl': logoUrl,
      'createdAt': now,
    });

    // 2 — Crear snapshot de stats en equipos (temporada actual)
    final snapRef = _equiposRef.doc();
    batch.set(snapRef, {
      'ligaId': ligaId,
      'temporadaId': _currentSeasonId,
      'equipoBaseId': baseRef.id,
      'nombre': nombre,
      'color': color,
      'logoUrl': logoUrl,
      'totalJugadores': 0,
      'PJ': 0,
      'PG': 0,
      'PE': 0,
      'PP': 0,
      'GF': 0,
      'GC': 0,
      'Pts': 0,
      'createdAt': now,
    });

    await batch.commit();

    _cache.remove('equipos_base');
    _invalidateForCurrentSeason(['equipos', 'home', 'equipos_resumen']);
    return snapRef.id;
  }

  /// Inscribe un equipo_base existente a la temporada actual.
  /// Devuelve el id del snapshot creado, o el existente si ya estaba inscrito.
  Future<String> inscribirEquipoExistente(EquipoBase base) async {
    // Verificar que no esté ya inscrito en esta temporada
    final existe = await _equiposRef
        .where('temporadaId', isEqualTo: _currentSeasonId)
        .where('equipoBaseId', isEqualTo: base.id)
        .limit(1)
        .get();

    if (existe.docs.isNotEmpty) {
      debugPrint('⚠️ Equipo ya inscrito en esta temporada');
      return existe.docs.first.id;
    }

    final snapRef = _equiposRef.doc();
    await snapRef.set({
      'ligaId': ligaId,
      'temporadaId': _currentSeasonId,
      'equipoBaseId': base.id,
      'nombre': base.nombre,
      'color': base.color,
      'logoUrl': base.logoUrl,
      'totalJugadores': 0,
      'PJ': 0,
      'PG': 0,
      'PE': 0,
      'PP': 0,
      'GF': 0,
      'GC': 0,
      'Pts': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    _invalidateForCurrentSeason(['equipos', 'home', 'equipos_resumen']);
    return snapRef.id;
  }

  Future<void> editarEquipoBase({
    required String equipoBaseId,
    required String equipoSnapId,
    required String nombre,
    required String color,
    required String logoUrl,
    String? logoAnteriorUrl,
  }) async {
    final data = {'nombre': nombre, 'color': color, 'logoUrl': logoUrl};

    final results = await Future.wait([
      _equiposRef.where('equipoBaseId', isEqualTo: equipoBaseId).get(),
      _db
          .collection('partidos_liguilla')
          .where('equipo1Id', isEqualTo: equipoSnapId)
          .get(),
      _db
          .collection('partidos_liguilla')
          .where('equipo2Id', isEqualTo: equipoSnapId)
          .get(),
      _goleadoresRef.where('equipoId', isEqualTo: equipoSnapId).get(),
    ]);

    final equiposSnaps = results[0] as QuerySnapshot;
    final liguillaEq1Snaps = results[1] as QuerySnapshot;
    final liguillaEq2Snaps = results[2] as QuerySnapshot;
    final goleadoresSnaps = results[3] as QuerySnapshot;

    final allWrites = <void Function(WriteBatch)>[];

    allWrites.add((b) => b.update(_equiposBaseRef.doc(equipoBaseId), data));

    for (final doc in equiposSnaps.docs) {
      allWrites.add((b) => b.update(doc.reference, data));
    }

    for (final doc in liguillaEq1Snaps.docs) {
      allWrites.add(
        (b) => b.update(doc.reference, {
          'equipo1Nombre': nombre,
          'equipo1LogoUrl': logoUrl,
        }),
      );
    }

    for (final doc in liguillaEq2Snaps.docs) {
      allWrites.add(
        (b) => b.update(doc.reference, {
          'equipo2Nombre': nombre,
          'equipo2LogoUrl': logoUrl,
        }),
      );
    }

    for (final doc in goleadoresSnaps.docs) {
      allWrites.add((b) => b.update(doc.reference, {'equipoNombre': nombre}));
    }

    await _commitInChunks(allWrites);

    // Propagar a partidos de jornadas (subcollección)
    await _propagarNombreEnPartidosJornada(
      equipoSnapId: equipoSnapId,
      nombre: nombre,
      logoUrl: logoUrl,
    );

    // ✅ CORRECCIÓN 1: Borrar logo DESPUÉS de que todo terminó exitosamente
    if (logoAnteriorUrl != null &&
        logoAnteriorUrl.isNotEmpty &&
        logoAnteriorUrl != logoUrl) {
      try {
        await FirebaseStorage.instance.refFromURL(logoAnteriorUrl).delete();
      } catch (e) {
        debugPrint('⚠️ No se pudo borrar logo anterior: $e');
      }
    }

    // ✅ CORRECCIÓN 2: Invalidar TODO el caché de jornadas y partidos
    _cache.remove('equipos_base');
    _invalidateForCurrentSeason(['equipos', 'home', 'equipos_resumen']);

    // Invalida jornadas de TODAS las temporadas donde este equipo aparece
    for (final doc in equiposSnaps.docs) {
      final tId =
          (doc.data() as Map<String, dynamic>?)?['temporadaId'] as String?;
      if (tId != null) {
        _cache.removeWhere(
          (key, _) =>
              key.startsWith('jornadas_$tId') ||
              key.startsWith('jornadas_con_partidos_$tId') ||
              key.startsWith('home_$tId') ||
              key.startsWith(
                'partidos_',
              ), // invalida todos los partidos cacheados
        );
      }
    }
  }

  /// Divide una lista de writes en batches de máx 500 y los ejecuta secuencialmente.
  Future<void> _commitInChunks(List<void Function(WriteBatch)> writes) async {
    const chunkSize = 500;
    for (int i = 0; i < writes.length; i += chunkSize) {
      final chunk = writes.sublist(i, (i + chunkSize).clamp(0, writes.length));
      final batch = _db.batch();
      for (final write in chunk) {
        write(batch);
      }
      await batch.commit();
    }
  }

  /// Los partidos de jornadas son subcollecciones — hay que usar collectionGroup.
  /// Requiere índice en Firestore: collectionGroup("partidos") con equipo1Id y equipo2Id.
  Future<void> _propagarNombreEnPartidosJornada({
    required String equipoSnapId,
    required String nombre,
    required String logoUrl,
  }) async {
    final results = await Future.wait([
      _db
          .collectionGroup('partidos')
          .where('equipo1Id', isEqualTo: equipoSnapId)
          .get(),
      _db
          .collectionGroup('partidos')
          .where('equipo2Id', isEqualTo: equipoSnapId)
          .get(),
    ]);

    final writes = <void Function(WriteBatch)>[];

    for (final doc in results[0].docs) {
      writes.add(
        (b) => b.update(doc.reference, {
          'equipo1Nombre': nombre,
          'equipo1LogoUrl': logoUrl,
        }),
      );
    }
    for (final doc in results[1].docs) {
      writes.add(
        (b) => b.update(doc.reference, {
          'equipo2Nombre': nombre,
          'equipo2LogoUrl': logoUrl,
        }),
      );
    }

    await _commitInChunks(writes);
  }

  Future<void> eliminarEquipoDeTemporada(String equipoSnapId) async {
    // Solo elimina el snapshot de esta temporada y sus inscripciones.
    // NO toca equipos_base ni la foto en Storage.
    final inscripciones = await _inscripcionesRef
        .where('equipoId', isEqualTo: equipoSnapId)
        .get();

    final batch = _db.batch();
    for (final doc in inscripciones.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_equiposRef.doc(equipoSnapId));
    await batch.commit();

    _invalidateForCurrentSeason(['equipos', 'home', 'equipos_resumen']);
    _cache.removeWhere((key, _) => key.startsWith('jugadores_$equipoSnapId'));
  }

  // ─── Jugadores base (globales) ─────────────────────────────────────────────

  /// Jugadores_base que NO están inscritos en el equipo dado en la temporada actual.
  /// Se usa para el selector "inscribir jugador existente".
  Future<List<JugadorBase>> getJugadoresBaseDisponibles(
    String equipoBaseId,
  ) async {
    final cacheKey =
        'jugadores_base_disponibles_${equipoBaseId}_$_currentSeasonId';
    final cached = _getCache<List<JugadorBase>>(cacheKey);
    if (cached != null) return cached;

    // Todos los jugadores_base de la liga
    final todosSnap = await _jugadoresBaseRef
        .where('ligaId', isEqualTo: ligaId)
        .orderBy('nombre')
        .get();

    // Los ya inscritos en este equipo/temporada
    final inscritosSnap = await _inscripcionesRef
        .where('equipoId', isEqualTo: equipoBaseId)
        .where('temporadaId', isEqualTo: _currentSeasonId)
        .get();

    final inscritosIds = inscritosSnap.docs
        .map((d) => d.data()['jugadorBaseId'] as String)
        .toSet();

    final disponibles = todosSnap.docs
        .map((doc) => JugadorBase.fromFirestore(doc.id, doc.data()))
        .where((j) => !inscritosIds.contains(j.id))
        .toList();

    _setCache(cacheKey, disponibles, _ttlCorto);
    return disponibles;
  }

  /// Crea un jugador nuevo en jugadores_base y lo inscribe al equipo/temporada.
  Future<void> crearJugadorNuevo({
    required String equipoSnapId, // id en colección equipos
    required String equipoBaseId,
    required String nombre,
    required String numero,
    required String fotoUrl,
  }) async {
    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();

    // 1 — Crear en jugadores_base
    final baseRef = _jugadoresBaseRef.doc();
    batch.set(baseRef, {
      'ligaId': ligaId,
      'nombre': nombre,
      'fotoUrl': fotoUrl,
      'createdAt': now,
    });

    // 2 — Crear inscripción
    final inscRef = _inscripcionesRef.doc();
    batch.set(inscRef, {
      'jugadorBaseId': baseRef.id,
      'equipoId': equipoSnapId,
      'equipoBaseId': equipoBaseId,
      'temporadaId': _currentSeasonId,
      'nombre': nombre, // desnormalizado para queries rápidas
      'fotoUrl': fotoUrl,
      'numero': numero,
      'goles': 0,
      'createdAt': now,
    });

    // 3 — Incrementar contador en equipo snapshot
    batch.update(_equiposRef.doc(equipoSnapId), {
      'totalJugadores': FieldValue.increment(1),
    });

    await batch.commit();

    _cache.remove('jugadores_base');
    _cache.remove(
      'jugadores_base_disponibles_${equipoBaseId}_$_currentSeasonId',
    );
    _cache.remove('jugadores_$equipoSnapId');
    _invalidateForCurrentSeason(['equipos', 'home']);
  }

  /// Inscribe un jugador_base existente al equipo/temporada actual.
  Future<void> inscribirJugadorExistente({
    required JugadorBase jugadorBase,
    required String equipoSnapId,
    required String equipoBaseId,
    required String numero,
  }) async {
    // Verificar que no esté ya inscrito en este equipo/temporada
    final existe = await _inscripcionesRef
        .where('jugadorBaseId', isEqualTo: jugadorBase.id)
        .where('equipoId', isEqualTo: equipoSnapId)
        .where('temporadaId', isEqualTo: _currentSeasonId)
        .limit(1)
        .get();

    if (existe.docs.isNotEmpty) {
      debugPrint('⚠️ Jugador ya inscrito en este equipo/temporada');
      return;
    }

    final batch = _db.batch();
    final inscRef = _inscripcionesRef.doc();

    batch.set(inscRef, {
      'jugadorBaseId': jugadorBase.id,
      'equipoId': equipoSnapId,
      'equipoBaseId': equipoBaseId,
      'temporadaId': _currentSeasonId,
      'nombre': jugadorBase.nombre,
      'fotoUrl': jugadorBase.fotoUrl,
      'numero': numero,
      'goles': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    batch.update(_equiposRef.doc(equipoSnapId), {
      'totalJugadores': FieldValue.increment(1),
    });

    await batch.commit();

    _cache.remove(
      'jugadores_base_disponibles_${equipoBaseId}_$_currentSeasonId',
    );
    _cache.remove('jugadores_$equipoSnapId');
    _invalidateForCurrentSeason(['equipos', 'home']);
  }

  Future<void> editarJugador({
    required String jugadorBaseId,
    required String inscripcionId,
    required String equipoSnapId,
    required String equipoBaseId,
    required String nombre,
    required String numero,
    required String fotoUrl,
    String? fotoAnteriorUrl,
  }) async {
    final batch = _db.batch();

    // 1 — Actualizar jugador_base
    batch.update(_jugadoresBaseRef.doc(jugadorBaseId), {
      'nombre': nombre,
      'fotoUrl': fotoUrl,
    });

    // 2 — Actualizar inscripción (numero puede cambiar también)
    batch.update(_inscripcionesRef.doc(inscripcionId), {
      'nombre': nombre,
      'fotoUrl': fotoUrl,
      'numero': numero,
    });

    await batch.commit();

    // 3 — Actualizar colección goleadores
    // El doc ID en goleadores ES el inscripcionId (no jugadorBaseId)
    final goleadorDoc = await _goleadoresRef.doc(inscripcionId).get();
    if (goleadorDoc.exists) {
      await _goleadoresRef.doc(inscripcionId).update({
        'nombre': nombre,
        'fotoUrl': fotoUrl,
      });
    }

    // 4 — Propagar en arrays de goleadores dentro de partidos
    // jugadorId en el array del partido = inscripcionId
    final partidosSnap = await _db.collectionGroup('partidos').get();
    final writes = <void Function(WriteBatch)>[];

    for (final doc in partidosSnap.docs) {
      final data = doc.data();
      final jugado = data['jugado'] as bool? ?? false;
      if (!jugado) continue;

      final goleadores = data['goleadores'] as List<dynamic>?;
      if (goleadores == null || goleadores.isEmpty) continue;

      bool cambio = false;
      final actualizados = goleadores.map((g) {
        final map = Map<String, dynamic>.from(g as Map);
        if (map['jugadorId'] == inscripcionId) {
          map['nombre'] = nombre;
          map['fotoUrl'] = fotoUrl;
          cambio = true;
        }
        return map;
      }).toList();

      if (cambio) {
        writes.add(
          (b) => b.update(doc.reference, {'goleadores': actualizados}),
        );
      }
    }

    // 5 — Propagar también en partidos_liguilla
    final partidosLiguillaSnap = await _db
        .collection('partidos_liguilla')
        .where('jugado', isEqualTo: true)
        .get();

    for (final doc in partidosLiguillaSnap.docs) {
      final data = doc.data();
      final goleadores = data['goleadores'] as List<dynamic>?;
      if (goleadores == null || goleadores.isEmpty) continue;

      bool cambio = false;
      final actualizados = goleadores.map((g) {
        final map = Map<String, dynamic>.from(g as Map);
        if (map['jugadorId'] == inscripcionId) {
          map['nombre'] = nombre;
          map['fotoUrl'] = fotoUrl;
          cambio = true;
        }
        return map;
      }).toList();

      if (cambio) {
        writes.add(
          (b) => b.update(doc.reference, {'goleadores': actualizados}),
        );
      }
    }

    await _commitInChunks(writes);

    // 6 — Borrar foto anterior DESPUÉS de que todo terminó exitosamente
    if (fotoAnteriorUrl != null &&
        fotoAnteriorUrl.isNotEmpty &&
        fotoAnteriorUrl != fotoUrl) {
      try {
        await FirebaseStorage.instance.refFromURL(fotoAnteriorUrl).delete();
      } catch (e) {
        debugPrint('⚠️ No se pudo borrar foto anterior: $e');
      }
    }

    // 7 — Invalidar caché
    _cache.remove('jugadores_$equipoSnapId');
    _cache.remove(
      'jugadores_base_disponibles_${equipoBaseId}_$_currentSeasonId',
    );
    _cache.removeWhere(
      (key, _) =>
          key.startsWith('goleadores_') ||
          key.startsWith('goleadores_home_') ||
          key.startsWith('home_') ||
          key.startsWith('partidos_') ||
          key.startsWith('jornadas_con_partidos_'),
    );
    _invalidateForCurrentSeason(['home', 'goleadores']);
  }

  Future<void> eliminarJugadorDeTemporada({
    required String inscripcionId,
    required String equipoSnapId,
    required String equipoBaseId,
    // NO borra la foto — el jugador_base sigue existiendo
  }) async {
    final batch = _db.batch();
    batch.delete(_inscripcionesRef.doc(inscripcionId));
    batch.update(_equiposRef.doc(equipoSnapId), {
      'totalJugadores': FieldValue.increment(-1),
    });
    await batch.commit();

    _cache.remove('jugadores_$equipoSnapId');
    _cache.remove(
      'jugadores_base_disponibles_${equipoBaseId}_$_currentSeasonId',
    );
    _invalidateForCurrentSeason(['equipos', 'home']);
  }

  // ─── Lectura de jugadores ──────────────────────────────────────────────────

  /// Jugadores inscritos en un equipo para la temporada actual.
  Future<List<Jugador>> getJugadores(String equipoSnapId) async {
    final cacheKey = 'jugadores_$equipoSnapId';
    final cached = _getCache<List<Jugador>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _inscripcionesRef
        .where('equipoId', isEqualTo: equipoSnapId)
        .where('temporadaId', isEqualTo: _currentSeasonId)
        .orderBy('nombre')
        .get();

    final jugadores = snapshot.docs
        .map((doc) => Jugador.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, jugadores, _ttlLargo);
    return jugadores;
  }

  Stream<List<Jugador>> getJugadoresStream(String equipoSnapId) {
    return _inscripcionesRef
        .where('equipoId', isEqualTo: equipoSnapId)
        .where('temporadaId', isEqualTo: _currentSeasonId)
        .orderBy('nombre')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Jugador.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  // ─── Equipos de temporada ──────────────────────────────────────────────────

  Future<List<Equipo>> getEquipos() async {
    final seasonId = _currentSeasonId;
    final cacheKey = 'equipos_$seasonId';
    final cached = _getCache<List<Equipo>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _equiposRef
        .where('temporadaId', isEqualTo: seasonId)
        .orderBy('Pts', descending: true)
        .get();

    final equipos = snapshot.docs
        .map((doc) => Equipo.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, equipos, _ttlCorto);
    return equipos;
  }

  Future<List<Equipo>> getEquiposHome(String seasonId) async {
    final cacheKey = 'equipos_home_$seasonId';
    final cached = _getCache<List<Equipo>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _equiposRef
        .where('temporadaId', isEqualTo: seasonId)
        .orderBy('Pts', descending: true)
        .limit(3)
        .get();

    final equipos = snapshot.docs
        .map((doc) => Equipo.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, equipos, _ttlCorto);
    return equipos;
  }

  Future<List<Map<String, String>>> getEquiposResumen() async {
    final seasonId = _currentSeasonId;
    final cacheKey = 'equipos_resumen_$seasonId';
    final cached = _getCache<List<Map<String, String>>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _equiposRef
        .where('temporadaId', isEqualTo: seasonId)
        .get();

    final result = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'nombre': data['nombre'] as String? ?? 'Sin nombre',
        'logoUrl': data['logoUrl'] as String? ?? '',
        'color': data['color'] as String? ?? '#000000',
      };
    }).toList();

    _setCache(cacheKey, result, _ttlLargo);
    return result;
  }

  Future<Equipo?> getEquipoById(String equipoId) async {
    final seasonId = currentSeasonId.value;
    if (seasonId != null) {
      final cached = _getCache<List<Equipo>>('equipos_$seasonId');
      if (cached != null) {
        final found = cached.where((e) => e.id == equipoId).firstOrNull;
        if (found != null) return found;
      }
    }
    final doc = await _equiposRef.doc(equipoId).get();
    if (!doc.exists) return null;
    return Equipo.fromFirestore(doc.id, doc.data()!);
  }

  Stream<List<Equipo>> getEquiposStream() {
    return _equiposRef
        .where('temporadaId', isEqualTo: _currentSeasonId)
        .orderBy('nombre')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Equipo.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  // ─── Goleadores ────────────────────────────────────────────────────────────

  Future<List<Jugador>> getGoleadores() async {
    final seasonId = _currentSeasonId;
    final cacheKey = 'goleadores_$seasonId';
    final cached = _getCache<List<Jugador>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _goleadoresRef
        .where('temporadaId', isEqualTo: seasonId)
        .where('goles', isGreaterThan: 0)
        .orderBy('goles', descending: true)
        .get();

    final goleadores = snapshot.docs
        .map((doc) => Jugador.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, goleadores, _ttlCorto);
    return goleadores;
  }

  Future<List<Jugador>> getGoleadoresHome(String seasonId) async {
    final cacheKey = 'goleadores_home_$seasonId';
    final cached = _getCache<List<Jugador>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _goleadoresRef
        .where('temporadaId', isEqualTo: seasonId)
        .where('goles', isGreaterThan: 0)
        .orderBy('goles', descending: true)
        .limit(3)
        .get();

    final goleadores = snapshot.docs
        .map((doc) => Jugador.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, goleadores, _ttlCorto);
    return goleadores;
  }

  // ─── Jornadas ──────────────────────────────────────────────────────────────

  Future<List<Jornada>> getJornadas() async {
    final seasonId = _currentSeasonId;
    final cacheKey = 'jornadas_$seasonId';
    final cached = _getCache<List<Jornada>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _jornadasRef
        .where('temporadaId', isEqualTo: seasonId)
        .orderBy('numero', descending: true)
        .get();

    final jornadas = snapshot.docs
        .map((doc) => Jornada.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, jornadas, _ttlCorto);
    return jornadas;
  }

  Future<List<Partido>> getPartidos(String jornadaId) async {
    final cacheKey = 'partidos_$jornadaId';
    final cached = _getCache<List<Partido>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _jornadasRef
        .doc(jornadaId)
        .collection('partidos')
        .get();

    final partidos = snapshot.docs
        .map((doc) => Partido.fromFirestore(doc.id, doc.data()))
        .toList();

    _setCache(cacheKey, partidos, _ttlCorto);
    return partidos;
  }

  Future<List<Jornada>> loadJornadasConPartidos({
    bool forceRefresh = false,
  }) async {
    final seasonId = _currentSeasonId;
    final cacheKey = 'jornadas_con_partidos_$seasonId';

    if (!forceRefresh) {
      final cached = _getCache<List<Jornada>>(cacheKey);
      if (cached != null) return cached;
    } else {
      _cache.remove(cacheKey);
    }

    final snapshot = await _jornadasRef
        .where('temporadaId', isEqualTo: seasonId)
        .orderBy('numero', descending: true)
        .get();

    final jornadasBase = snapshot.docs
        .map((doc) => Jornada.fromFirestore(doc.id, doc.data()))
        .toList();

    if (jornadasBase.isEmpty) return [];

    final partidosPorJornada = await Future.wait(
      jornadasBase.map((j) => getPartidos(j.id)),
    );

    final resultado = List.generate(jornadasBase.length, (i) {
      final j = jornadasBase[i];
      return Jornada(
        id: j.id,
        ligaId: j.ligaId,
        temporadaId: j.temporadaId,
        numero: j.numero,
        createdAt: j.createdAt,
        partidos: partidosPorJornada[i],
      );
    });

    _setCache(cacheKey, resultado, _ttlCorto);
    return resultado;
  }

  Future<void> crearJornada({
    required int numero,
    required List<Partido> partidos,
  }) async {
    final jornadaRef = _jornadasRef.doc();
    final batch = _db.batch();
    final now = DateTime.now().toIso8601String();

    batch.set(jornadaRef, {
      'ligaId': ligaId,
      'temporadaId': _currentSeasonId,
      'numero': numero,
      'createdAt': now,
    });

    for (final p in partidos) {
      final partidoRef = jornadaRef.collection('partidos').doc();
      batch.set(partidoRef, {
        'equipo1Id': p.equipo1Id,
        'equipo1Nombre': p.equipo1Nombre,
        if (p.equipo1LogoUrl != null && p.equipo1LogoUrl!.isNotEmpty)
          'equipo1LogoUrl': p.equipo1LogoUrl,
        'equipo2Id': p.equipo2Id,
        'equipo2Nombre': p.equipo2Nombre,
        if (p.equipo2LogoUrl != null && p.equipo2LogoUrl!.isNotEmpty)
          'equipo2LogoUrl': p.equipo2LogoUrl,
        if (p.fecha != null) 'fecha': p.fecha!.toIso8601String(),
        if (p.hora != null) 'hora': p.hora,
        'jugado': false,
        'penales': false,
        'createdAt': now,
      });
    }

    batch.update(_temporadasRef.doc(_currentSeasonId), {
      'totalJornadas': FieldValue.increment(1),
      'totalPartidos': FieldValue.increment(partidos.length),
    });

    await batch.commit();
    _invalidateForCurrentSeason(['jornadas', 'home', 'proximo_partido']);
  }

  // ─── Resultado partido ─────────────────────────────────────────────────────

  Future<void> guardarResultadoPartido({
    required String jornadaId,
    required String partidoId,
    required Partido partidoActualizado,
    required Equipo equipo1Antes,
    required Equipo equipo2Antes,
    required Equipo? equipo1ResultadoAnterior,
    required Equipo? equipo2ResultadoAnterior,
    List<Goleador> goleadoresOriginales = const [],
  }) async {
    final partidoRef = _jornadasRef
        .doc(jornadaId)
        .collection('partidos')
        .doc(partidoId);

    await _db.runTransaction((tx) async {
      final partidoSnap = await tx.get(partidoRef);
      final data = partidoSnap.data() ?? {};

      final golesViejos =
          (data['golesEquipo1'] ?? 0) + (data['golesEquipo2'] ?? 0);
      final golesNuevos =
          partidoActualizado.golesEquipo1! + partidoActualizado.golesEquipo2!;
      final delta = golesNuevos - golesViejos;

      tx.update(partidoRef, {
        'golesEquipo1': partidoActualizado.golesEquipo1,
        'golesEquipo2': partidoActualizado.golesEquipo2,
        'penales': partidoActualizado.penales,
        'ganadorPenalesId': partidoActualizado.ganadorPenalesId,
        'goleadores': partidoActualizado.goleadores
            .map((g) => g.toMap())
            .toList(),
        'jugado': true,
        'fecha': partidoActualizado.fecha?.toIso8601String(),
        'hora': partidoActualizado.hora,
      });

      tx.update(_temporadasRef.doc(_currentSeasonId), {
        'totalGoles': FieldValue.increment(delta),
      });

      final statsEquipo1 = _calcularStatsActualizados(
        equipoAntes: equipo1Antes,
        resultadoAnterior: equipo1ResultadoAnterior,
        golesFavor: partidoActualizado.golesEquipo1!,
        golesContra: partidoActualizado.golesEquipo2!,
        penales: partidoActualizado.penales,
        ganoPenales:
            partidoActualizado.penales &&
            partidoActualizado.ganadorPenalesId == equipo1Antes.id,
      );
      tx.update(
        _equiposRef.doc(equipo1Antes.id),
        statsEquipo1.statsToFirestore(),
      );

      final statsEquipo2 = _calcularStatsActualizados(
        equipoAntes: equipo2Antes,
        resultadoAnterior: equipo2ResultadoAnterior,
        golesFavor: partidoActualizado.golesEquipo2!,
        golesContra: partidoActualizado.golesEquipo1!,
        penales: partidoActualizado.penales,
        ganoPenales:
            partidoActualizado.penales &&
            partidoActualizado.ganadorPenalesId == equipo2Antes.id,
      );
      tx.update(
        _equiposRef.doc(equipo2Antes.id),
        statsEquipo2.statsToFirestore(),
      );

      // Restar goleadores anteriores — usa jugadorBaseId como clave
      for (final goleador in goleadoresOriginales) {
        final inscRef = _inscripcionesRef.doc(goleador.jugadorId);
        tx.update(inscRef, {'goles': FieldValue.increment(-goleador.goles)});

        final goleadorRef = _goleadoresRef.doc(goleador.jugadorId);
        tx.update(goleadorRef, {
          'goles': FieldValue.increment(-goleador.goles),
        });
      }

      // Sumar goleadores nuevos
      for (final goleador in partidoActualizado.goleadores) {
        final inscRef = _inscripcionesRef.doc(goleador.jugadorId);
        tx.update(inscRef, {'goles': FieldValue.increment(goleador.goles)});

        final goleadorRef = _goleadoresRef.doc(goleador.jugadorId);
        tx.set(goleadorRef, {
          'temporadaId': _currentSeasonId,
          'equipoId': goleador.equipoId,
          'equipoNombre': goleador.equipoNombre,
          'nombre': goleador.nombre,
          'fotoUrl': goleador.fotoUrl ?? '',
          'goles': FieldValue.increment(goleador.goles),
        }, SetOptions(merge: true));
      }
    });

    _invalidateForCurrentSeason([
      'home',
      'partidos_$jornadaId',
      'goleadores',
      'equipos',
      'proximo_partido',
    ]);
    // Invalida caché de jugadores de ambos equipos
    _cache.remove('jugadores_${equipo1Antes.id}');
    _cache.remove('jugadores_${equipo2Antes.id}');
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────

  Equipo _calcularStatsActualizados({
    required Equipo equipoAntes,
    required Equipo? resultadoAnterior,
    required int golesFavor,
    required int golesContra,
    required bool penales,
    required bool ganoPenales,
  }) {
    int pj = equipoAntes.pj,
        pg = equipoAntes.pg,
        pe = equipoAntes.pe,
        pp = equipoAntes.pp,
        gf = equipoAntes.gf,
        gc = equipoAntes.gc,
        pts = equipoAntes.pts;

    if (resultadoAnterior != null) {
      pj -= resultadoAnterior.pj;
      pg -= resultadoAnterior.pg;
      pe -= resultadoAnterior.pe;
      pp -= resultadoAnterior.pp;
      gf -= resultadoAnterior.gf;
      gc -= resultadoAnterior.gc;
      pts -= resultadoAnterior.pts;
    }

    pj += 1;
    gf += golesFavor;
    gc += golesContra;

    if (golesFavor > golesContra) {
      pg += 1;
      pts += 3;
    } else if (golesFavor < golesContra) {
      pp += 1;
    } else {
      pe += 1;
      if (penales) pts += ganoPenales ? 2 : 1;
    }

    return equipoAntes.copyWith(
      pj: pj,
      pg: pg,
      pe: pe,
      pp: pp,
      gf: gf,
      gc: gc,
      pts: pts,
    );
  }

  // ─── Próximo partido ───────────────────────────────────────────────────────

  Future<({Partido? partido, int? jornadaNumero})> getProximoPartido() async {
    final seasonId = _currentSeasonId;
    final cacheKey = 'proximo_partido_$seasonId';
    final cached = _getCache<({Partido? partido, int? jornadaNumero})>(
      cacheKey,
    );
    if (cached != null) return cached;

    final ahora = DateTime.now();
    final inicioDia = DateTime(ahora.year, ahora.month, ahora.day);

    // Helper local
    DateTime combineFechaHora(DateTime fecha, String? hora) {
      if (hora == null || hora.isEmpty) return fecha;
      try {
        final partes = hora.split(':');
        return DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          int.parse(partes[0]),
          partes.length > 1 ? int.parse(partes[1]) : 0,
        );
      } catch (_) {
        return fecha;
      }
    }

    final jornadasSnap = await _jornadasRef
        .where('temporadaId', isEqualTo: seasonId)
        .get();

    if (jornadasSnap.docs.isEmpty) {
      final result = (partido: null as Partido?, jornadaNumero: null as int?);
      _setCache(cacheKey, result, _ttlCorto);
      return result;
    }

    final futures = jornadasSnap.docs.map((jDoc) async {
      final snap = await _jornadasRef
          .doc(jDoc.id)
          .collection('partidos')
          .where('jugado', isEqualTo: false)
          .get();

      final candidatos = snap.docs
          .map((d) => Partido.fromFirestore(d.id, d.data()))
          .where((p) {
            if (p.fecha == null) return false;
            final fechaHora = combineFechaHora(p.fecha!, p.hora);
            return (p.hora != null && p.hora!.isNotEmpty)
                ? fechaHora.isAfter(ahora)
                : !fechaHora.isBefore(inicioDia);
          })
          .toList();

      if (candidatos.isEmpty) return null;

      // ← usa combineFechaHora para ordenar correctamente
      candidatos.sort(
        (a, b) => combineFechaHora(
          a.fecha!,
          a.hora,
        ).compareTo(combineFechaHora(b.fecha!, b.hora)),
      );

      return (
        partido: candidatos.first,
        jornadaNumero: (jDoc.data()['numero'] as num?)?.toInt(),
      );
    });

    final resultados = await Future.wait(futures);
    final validos = resultados
        .whereType<({Partido partido, int? jornadaNumero})>()
        .toList();

    if (validos.isEmpty) {
      final result = (partido: null as Partido?, jornadaNumero: null as int?);
      _setCache(cacheKey, result, _ttlCorto);
      return result;
    }

    // ← también aquí
    validos.sort(
      (a, b) => combineFechaHora(
        a.partido.fecha!,
        a.partido.hora,
      ).compareTo(combineFechaHora(b.partido.fecha!, b.partido.hora)),
    );

    final best = validos.first;
    final result = (partido: best.partido, jornadaNumero: best.jornadaNumero);
    _setCache(cacheKey, result, _ttlCorto);
    return result;
  }

  // ─── Últimos 5 ─────────────────────────────────────────────────────────────

  List<String> getUltimos5({
    required String equipoId,
    required List<Jornada> jornadas,
  }) {
    final results = <String>[];
    for (final jornada in jornadas) {
      for (final partido in jornada.partidos) {
        if (!partido.tieneResultado) continue;
        String? result;
        if (partido.equipo1Id == equipoId) {
          result = partido.golesEquipo1! > partido.golesEquipo2!
              ? 'W'
              : partido.golesEquipo1! < partido.golesEquipo2!
              ? 'L'
              : 'D';
        } else if (partido.equipo2Id == equipoId) {
          result = partido.golesEquipo2! > partido.golesEquipo1!
              ? 'W'
              : partido.golesEquipo2! < partido.golesEquipo1!
              ? 'L'
              : 'D';
        }
        if (result != null) {
          results.add(result);
          if (results.length >= 5) return results;
        }
      }
      if (results.length >= 5) break;
    }
    return results;
  }

  // ─── Cache helpers públicos ────────────────────────────────────────────────

  void invalidateJornadasCache() {
    final seasonId = currentSeasonId.value;
    if (seasonId == null) return;
    _cache
      ..remove('jornadas_con_partidos_$seasonId')
      ..remove('jornadas_$seasonId')
      ..remove('home_$seasonId');
  }

  void invalidatePartidosCache(String jornadaId) {
    _cache.remove('partidos_$jornadaId');
    final seasonId = currentSeasonId.value;
    if (seasonId != null) {
      _cache
        ..remove('jornadas_con_partidos_$seasonId')
        ..remove('home_$seasonId')
        ..remove('equipos_home_$seasonId')
        ..remove('goleadores_home_$seasonId');
    }
  }

  // Pégalo al final de FirestoreService, antes del dispose()
  Future<
    ({
      Jornada? ultimaJornada,
      List<Partido> partidos,
      List<Equipo> topTeams,
      List<Jugador> topScorers,
    })
  >
  loadHomeData() async {
    final seasonId = _currentSeasonId;
    final cacheKey = 'home_$seasonId';
    final cached =
        _getCache<
          ({
            Jornada? ultimaJornada,
            List<Partido> partidos,
            List<Equipo> topTeams,
            List<Jugador> topScorers,
          })
        >(cacheKey);
    if (cached != null) return cached;

    final results = await Future.wait([
      getEquiposHome(seasonId),
      getGoleadoresHome(seasonId),
      loadJornadasConPartidos(),
    ]);

    final topTeams = results[0] as List<Equipo>;
    final topScorers = results[1] as List<Jugador>;
    final jornadas = results[2] as List<Jornada>;

    Jornada? ultimaJornada;
    List<Partido> partidos = [];

    for (final j in jornadas) {
      final jugados = j.partidos.where((p) => p.tieneResultado).toList();
      if (jugados.isNotEmpty) {
        ultimaJornada = j;
        partidos = jugados;
        break;
      }
    }

    final result = (
      ultimaJornada: ultimaJornada,
      partidos: partidos,
      topTeams: topTeams,
      topScorers: topScorers,
    );

    _setCache(cacheKey, result, _ttlCorto);
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // REEMPLAZA la sección "─── LIGUILLA ───" en firestore_service.dart
  // con todo este bloque (desde el comentario hasta el final del dispose).
  // ─────────────────────────────────────────────────────────────────────────────

  // ─── LIGUILLA ──────────────────────────────────────────────────────────────

  Future<String> cerrarLigaYGenerarLiguilla() async {
    final seasonId = currentSeasonId.value;
    if (seasonId == null) throw Exception('No hay temporada activa');

    final equipos = await getEquipos();
    if (equipos.length < 8) {
      throw Exception(
        'Se necesitan al menos 8 equipos (hay ${equipos.length})',
      );
    }
    final top8 = equipos.take(8).toList();

    final liguillaRef = _db.collection('liguillas').doc();
    final liguillaId = liguillaRef.id;

    // ── Refs: ida y vuelta por cruce ─────────────────────────────────────────
    // Cuartos: 4 cruces × 2 partidos = 8 docs
    final c1ida = _db.collection('partidos_liguilla').doc();
    final c1vta = _db.collection('partidos_liguilla').doc();
    final c2ida = _db.collection('partidos_liguilla').doc();
    final c2vta = _db.collection('partidos_liguilla').doc();
    final c3ida = _db.collection('partidos_liguilla').doc();
    final c3vta = _db.collection('partidos_liguilla').doc();
    final c4ida = _db.collection('partidos_liguilla').doc();
    final c4vta = _db.collection('partidos_liguilla').doc();
    // Semis: 2 cruces × 2 partidos = 4 docs
    final s1ida = _db.collection('partidos_liguilla').doc();
    final s1vta = _db.collection('partidos_liguilla').doc();
    final s2ida = _db.collection('partidos_liguilla').doc();
    final s2vta = _db.collection('partidos_liguilla').doc();
    // Final: 1 cruce × 2 partidos = 2 docs
    final f1ida = _db.collection('partidos_liguilla').doc();
    final f1vta = _db.collection('partidos_liguilla').doc();

    // ── IDs de cruce ─────────────────────────────────────────────────────────
    final cruceC1 = c1ida.id;
    final cruceC2 = c2ida.id;
    final cruceC3 = c3ida.id;
    final cruceC4 = c4ida.id;
    final cruceS1 = s1ida.id;
    final cruceS2 = s2ida.id;
    final cruceF1 = f1ida.id;

    // ── Helpers ───────────────────────────────────────────────────────────────

    Map<String, dynamic> _ida({
      required String liguillaId,
      required String cruceId,
      required String ronda,
      required int orden,
      required int posicion,
      required String siguienteIdaId,
      required String eq1Id,
      required String eq1Nombre,
      required String eq1Logo,
      required String eq2Id,
      required String eq2Nombre,
      required String eq2Logo,
    }) => {
      'liguillaId': liguillaId,
      'cruceId': cruceId,
      'numeroPartido': 1,
      'ronda': ronda,
      'orden': orden,
      'posicion': posicion,
      'siguientePartidoId': siguienteIdaId,
      'equipo1Id': eq1Id,
      'equipo1Nombre': eq1Nombre,
      'equipo1LogoUrl': eq1Logo,
      'equipo2Id': eq2Id,
      'equipo2Nombre': eq2Nombre,
      'equipo2LogoUrl': eq2Logo,
      'golesEquipo1': null,
      'golesEquipo2': null,
      'penales': false,
      'ganadorPenalesId': null,
      'ganadorId': null,
      'ganadorCruceId': null,
      'cruceResuelto': false,
      'jugado': false,
    };

    Map<String, dynamic> _vuelta({
      required String liguillaId,
      required String cruceId,
      required String ronda,
      required int orden,
      required int posicion,
      required String siguienteIdaId,
      required String eq1Id,
      required String eq1Nombre,
      required String eq1Logo,
      required String eq2Id,
      required String eq2Nombre,
      required String eq2Logo,
    }) => {
      'liguillaId': liguillaId,
      'cruceId': cruceId,
      'numeroPartido': 2,
      'ronda': ronda,
      'orden': orden,
      'posicion': posicion,
      'siguientePartidoId': siguienteIdaId,
      // En vuelta los equipos se invierten (equipo2 juega de local)
      'equipo1Id': eq2Id,
      'equipo1Nombre': eq2Nombre,
      'equipo1LogoUrl': eq2Logo,
      'equipo2Id': eq1Id,
      'equipo2Nombre': eq1Nombre,
      'equipo2LogoUrl': eq1Logo,
      'golesEquipo1': null,
      'golesEquipo2': null,
      'penales': false,
      'ganadorPenalesId': null,
      'ganadorId': null,
      'ganadorCruceId': null,
      'cruceResuelto': false,
      'jugado': false,
    };

    Map<String, dynamic> _vacio({
      required String liguillaId,
      required String cruceId,
      required String ronda,
      required int orden,
      required int posicion,
      required int numeroPartido,
      String? siguienteIdaId,
    }) => {
      'liguillaId': liguillaId,
      'cruceId': cruceId,
      'numeroPartido': numeroPartido,
      'ronda': ronda,
      'orden': orden,
      'posicion': posicion,
      'siguientePartidoId': siguienteIdaId,
      'equipo1Id': null,
      'equipo1Nombre': '',
      'equipo1LogoUrl': '',
      'equipo2Id': null,
      'equipo2Nombre': '',
      'equipo2LogoUrl': '',
      'golesEquipo1': null,
      'golesEquipo2': null,
      'penales': false,
      'ganadorPenalesId': null,
      'ganadorId': null,
      'ganadorCruceId': null,
      'cruceResuelto': false,
      'jugado': false,
    };

    // ── Batch ─────────────────────────────────────────────────────────────────
    final batch = _db.batch();

    // ── CUARTOS ───────────────────────────────────────────────────────────────
    //
    // Bracket visual:
    //   IZQ: C1 (ord 1) ─┐              ┌─ C2 (ord 2) :DER
    //                     ├─ S1 (ord 1) ─┤
    //   IZQ: C3 (ord 3) ─┘              └─ C4 (ord 4) :DER
    //
    // Regla: orden impar = izquierda → ambos van a S1
    //        orden par   = derecha   → ambos van a S2
    //
    // C1 (1° vs 8°) → S1, posicion 1
    batch.set(
      c1ida,
      _ida(
        liguillaId: liguillaId,
        cruceId: cruceC1,
        ronda: 'cuartos',
        orden: 1,
        posicion: 1,
        siguienteIdaId: s1ida.id,
        eq1Id: top8[0].id,
        eq1Nombre: top8[0].nombre,
        eq1Logo: top8[0].logoUrl,
        eq2Id: top8[7].id,
        eq2Nombre: top8[7].nombre,
        eq2Logo: top8[7].logoUrl,
      ),
    );
    batch.set(
      c1vta,
      _vuelta(
        liguillaId: liguillaId,
        cruceId: cruceC1,
        ronda: 'cuartos',
        orden: 1,
        posicion: 1,
        siguienteIdaId: s1ida.id,
        eq1Id: top8[0].id,
        eq1Nombre: top8[0].nombre,
        eq1Logo: top8[0].logoUrl,
        eq2Id: top8[7].id,
        eq2Nombre: top8[7].nombre,
        eq2Logo: top8[7].logoUrl,
      ),
    );

    // C2 (4° vs 5°) → S2, posicion 1  ← CORREGIDO (antes iba a S1 pos 2)
    batch.set(
      c2ida,
      _ida(
        liguillaId: liguillaId,
        cruceId: cruceC2,
        ronda: 'cuartos',
        orden: 3,
        posicion: 2,
        siguienteIdaId: s1ida.id,
        eq1Id: top8[3].id,
        eq1Nombre: top8[3].nombre,
        eq1Logo: top8[3].logoUrl,
        eq2Id: top8[4].id,
        eq2Nombre: top8[4].nombre,
        eq2Logo: top8[4].logoUrl,
      ),
    );
    batch.set(
      c2vta,
      _vuelta(
        liguillaId: liguillaId,
        cruceId: cruceC2,
        ronda: 'cuartos',
        orden: 3,
        posicion: 2,
        siguienteIdaId: s1ida.id,
        eq1Id: top8[3].id,
        eq1Nombre: top8[3].nombre,
        eq1Logo: top8[3].logoUrl,
        eq2Id: top8[4].id,
        eq2Nombre: top8[4].nombre,
        eq2Logo: top8[4].logoUrl,
      ),
    );

    // C3 (2° vs 7°) → S1, posicion 2  ← CORREGIDO (antes iba a S2 pos 1)
    batch.set(
      c3ida,
      _ida(
        liguillaId: liguillaId,
        cruceId: cruceC3,
        ronda: 'cuartos',
        orden: 2,
        posicion: 1,
        siguienteIdaId: s2ida.id,
        eq1Id: top8[1].id,
        eq1Nombre: top8[1].nombre,
        eq1Logo: top8[1].logoUrl,
        eq2Id: top8[6].id,
        eq2Nombre: top8[6].nombre,
        eq2Logo: top8[6].logoUrl,
      ),
    );
    batch.set(
      c3vta,
      _vuelta(
        liguillaId: liguillaId,
        cruceId: cruceC3,
        ronda: 'cuartos',
        orden: 2,
        posicion: 1,
        siguienteIdaId: s2ida.id,
        eq1Id: top8[1].id,
        eq1Nombre: top8[1].nombre,
        eq1Logo: top8[1].logoUrl,
        eq2Id: top8[6].id,
        eq2Nombre: top8[6].nombre,
        eq2Logo: top8[6].logoUrl,
      ),
    );

    // C4 (3° vs 6°) → S2, posicion 2
    batch.set(
      c4ida,
      _ida(
        liguillaId: liguillaId,
        cruceId: cruceC4,
        ronda: 'cuartos',
        orden: 4,
        posicion: 2,
        siguienteIdaId: s2ida.id,
        eq1Id: top8[2].id,
        eq1Nombre: top8[2].nombre,
        eq1Logo: top8[2].logoUrl,
        eq2Id: top8[5].id,
        eq2Nombre: top8[5].nombre,
        eq2Logo: top8[5].logoUrl,
      ),
    );
    batch.set(
      c4vta,
      _vuelta(
        liguillaId: liguillaId,
        cruceId: cruceC4,
        ronda: 'cuartos',
        orden: 4,
        posicion: 2,
        siguienteIdaId: s2ida.id,
        eq1Id: top8[2].id,
        eq1Nombre: top8[2].nombre,
        eq1Logo: top8[2].logoUrl,
        eq2Id: top8[5].id,
        eq2Nombre: top8[5].nombre,
        eq2Logo: top8[5].logoUrl,
      ),
    );

    // ── SEMIS (vacías) ────────────────────────────────────────────────────────
    // S1 recibe ganadores de C1 (pos 1) y C3 (pos 2) → su ganador va a Final pos 1
    batch.set(
      s1ida,
      _vacio(
        liguillaId: liguillaId,
        cruceId: cruceS1,
        ronda: 'semis',
        orden: 1,
        posicion: 1,
        numeroPartido: 1,
        siguienteIdaId: f1ida.id,
      ),
    );
    batch.set(
      s1vta,
      _vacio(
        liguillaId: liguillaId,
        cruceId: cruceS1,
        ronda: 'semis',
        orden: 1,
        posicion: 1,
        numeroPartido: 2,
        siguienteIdaId: f1ida.id,
      ),
    );

    // S2 recibe ganadores de C2 (pos 1) y C4 (pos 2) → su ganador va a Final pos 2
    batch.set(
      s2ida,
      _vacio(
        liguillaId: liguillaId,
        cruceId: cruceS2,
        ronda: 'semis',
        orden: 2,
        posicion: 2,
        numeroPartido: 1,
        siguienteIdaId: f1ida.id,
      ),
    );
    batch.set(
      s2vta,
      _vacio(
        liguillaId: liguillaId,
        cruceId: cruceS2,
        ronda: 'semis',
        orden: 2,
        posicion: 2,
        numeroPartido: 2,
        siguienteIdaId: f1ida.id,
      ),
    );

    // ── FINAL (vacía) ─────────────────────────────────────────────────────────
    batch.set(
      f1ida,
      _vacio(
        liguillaId: liguillaId,
        cruceId: cruceF1,
        ronda: 'final',
        orden: 1,
        posicion: 1,
        numeroPartido: 1,
      ),
    );
    batch.set(
      f1vta,
      _vacio(
        liguillaId: liguillaId,
        cruceId: cruceF1,
        ronda: 'final',
        orden: 1,
        posicion: 1,
        numeroPartido: 2,
      ),
    );

    batch.set(liguillaRef, {
      'temporadaId': seasonId,
      'tipo': 'A',
      'estado': 'en_curso',
      'fechaInicio': DateTime.now(),
    });
    batch.update(_temporadasRef.doc(seasonId), {'faseActual': 'liguilla'});
    await batch.commit();

    _currentLiguilla = Liguilla(
      id: liguillaId,
      temporadaId: seasonId,
      estado: 'en_curso',
      fechaInicio: DateTime.now(),
    );
    faseVista.value = 'liguilla';
    return liguillaId;
  }

  // ─── LIGUILLA B ────────────────────────────────────────────────────────────
  //
  // Lógica de byes:
  //   - Se toman los equipos del lugar 9 en adelante, ordenados por posición.
  //   - Se calcula la potencia de 2 más cercana superior o igual al total.
  //   - Los (potencia - total) mejores rankeados reciben BYE (pasan directo a cuartos).
  //   - Los restantes juegan ronda previa (octavos) en pares espejo:
  //       mejor disponible vs peor disponible.
  //
  // Estructura de `orden` en Firestore:
  //   - previo:  orden 1,2,3… (uno por cruce)
  //   - cuartos: orden 1,2,3,4… donde:
  //       orden 1,3,5… → lado IZQUIERDO del bracket
  //       orden 2,4,6… → lado DERECHO del bracket
  //   - semis:   orden 1 (izq), orden 2 (der)
  //   - final:   orden 1
  //
  // Emparejamiento espejo en cuartos:
  //   slot[0] vs slot[potencia/2 - 1]
  //   slot[1] vs slot[potencia/2 - 2]
  //   ...
  // Los slots con byes ya tienen equipo; los de ganadores de previo están vacíos.
  //
  // siguientePartidoId y posicion permiten propagar el ganador:
  //   posicion 1 → equipo1 del siguiente cruce
  //   posicion 2 → equipo2 del siguiente cruce

  Future<String> cerrarLigaYGenerarLiguillaB() async {
    final seasonId = currentSeasonId.value;
    if (seasonId == null) throw Exception('No hay temporada activa');

    final todosEquipos = await getEquipos();
    if (todosEquipos.length < 10) {
      throw Exception(
        'Se necesitan al menos 10 equipos para Liguilla B (hay ${todosEquipos.length})',
      );
    }

    final equipos = todosEquipos.skip(8).toList();
    final int n = equipos.length;

    int potencia = 1;
    while (potencia < n) potencia *= 2;

    final int numByes = potencia - n;
    final List<dynamic> conBye = equipos.sublist(0, numByes);
    final List<dynamic> sinBye = equipos.sublist(numByes);
    final int numPrevios = sinBye.length ~/ 2;

    final int clasificados = numByes + numPrevios;
    final int numCrucesCuartos = clasificados ~/ 2;
    final int numCrucesSemis = numCrucesCuartos ~/ 2;

    final liguillaRef = _db.collection('liguillas').doc();
    final liguillaId = liguillaRef.id;
    final batch = _db.batch();

    Map<String, dynamic> _mkP({
      required String cruceId,
      required int numeroPartido,
      required String ronda,
      required int orden,
      required int posicion,
      String? siguienteIdaId,
      String? eq1Id,
      String? eq1Nombre,
      String? eq1Logo,
      String? eq2Id,
      String? eq2Nombre,
      String? eq2Logo,
      bool invertir = false,
    }) => {
      'liguillaId': liguillaId,
      'cruceId': cruceId,
      'numeroPartido': numeroPartido,
      'ronda': ronda,
      'orden': orden,
      'posicion': posicion,
      'siguientePartidoId': siguienteIdaId,
      'equipo1Id': invertir ? eq2Id : eq1Id,
      'equipo1Nombre': (invertir ? eq2Nombre : eq1Nombre) ?? '',
      'equipo1LogoUrl': (invertir ? eq2Logo : eq1Logo) ?? '',
      'equipo2Id': invertir ? eq1Id : eq2Id,
      'equipo2Nombre': (invertir ? eq1Nombre : eq2Nombre) ?? '',
      'equipo2LogoUrl': (invertir ? eq1Logo : eq2Logo) ?? '',
      'golesEquipo1': null,
      'golesEquipo2': null,
      'penales': false,
      'ganadorPenalesId': null,
      'ganadorId': null,
      'ganadorCruceId': null,
      'cruceResuelto': false,
      'jugado': false,
      'esLiguillaB': true,
    };

    // ── Pre-genera referencias ───────────────────────────────────────────
    final cuartosIdaRef = List.generate(
      numCrucesCuartos,
      (_) => _db.collection('partidos_liguilla').doc(),
    );
    final cuartosVtaRef = List.generate(
      numCrucesCuartos,
      (_) => _db.collection('partidos_liguilla').doc(),
    );
    final cuartosIds = cuartosIdaRef.map((d) => d.id).toList();

    final semisIdaRef = List.generate(
      numCrucesSemis,
      (_) => _db.collection('partidos_liguilla').doc(),
    );
    final semisVtaRef = List.generate(
      numCrucesSemis,
      (_) => _db.collection('partidos_liguilla').doc(),
    );
    final semisIds = semisIdaRef.map((d) => d.id).toList();

    final finalIda = _db.collection('partidos_liguilla').doc();
    final finalVta = _db.collection('partidos_liguilla').doc();
    final finalId = finalIda.id;

    // ── Slots de cuartos ─────────────────────────────────────────────────
    // slot[0..clasificados-1], los primeros numByes son byes conocidos,
    // el resto null (se llenan con ganadores de previo).
    // Emparejamiento espejo: cruce j → slot[j] vs slot[clasificados-1-j]
    final List<dynamic?> slots = List<dynamic?>.filled(clasificados, null);
    for (int i = 0; i < numByes; i++) {
      slots[i] = conBye[i];
    }

    // ── CUARTOS ──────────────────────────────────────────────────────────
    //
    // 4 cruces (con 14 equipos). Bracket visual:
    //   IZQ: cruce 0 (ord 1) ─┐              ┌─ cruce 1 (ord 2) :DER
    //                           ├─ semi 0 ────┤
    //   IZQ: cruce 2 (ord 3) ─┘              └─ cruce 3 (ord 4) :DER
    //
    // Regla: ord impar (j=0,2) → izquierda → semi 0
    //        ord par   (j=1,3) → derecha   → semi 1
    //
    // Posición en semi:
    //   j=0 → semi0 pos 1 | j=1 → semi1 pos 1
    //   j=2 → semi0 pos 2 | j=3 → semi1 pos 2

    for (int j = 0; j < numCrucesCuartos; j++) {
      final eq1 = slots[j];
      final eq2 = slots[clasificados - 1 - j];

      final bool esIzquierda = j % 2 == 0;
      final int semiIdx = esIzquierda ? 0 : 1;
      final int posicionEnSemi = j < 2 ? 1 : 2;

      final String sigIdaId = numCrucesSemis > 0
          ? semisIdaRef[semiIdx].id
          : finalIda.id;

      final String cruceId = cuartosIds[j];

      batch.set(
        cuartosIdaRef[j],
        _mkP(
          cruceId: cruceId,
          numeroPartido: 1,
          ronda: 'cuartos',
          orden: j + 1,
          posicion: posicionEnSemi,
          siguienteIdaId: sigIdaId,
          eq1Id: eq1?.id,
          eq1Nombre: eq1?.nombre,
          eq1Logo: eq1?.logoUrl,
          eq2Id: eq2?.id,
          eq2Nombre: eq2?.nombre,
          eq2Logo: eq2?.logoUrl,
        ),
      );
      batch.set(
        cuartosVtaRef[j],
        _mkP(
          cruceId: cruceId,
          numeroPartido: 2,
          ronda: 'cuartos',
          orden: j + 1,
          posicion: posicionEnSemi,
          siguienteIdaId: sigIdaId,
          eq1Id: eq1?.id,
          eq1Nombre: eq1?.nombre,
          eq1Logo: eq1?.logoUrl,
          eq2Id: eq2?.id,
          eq2Nombre: eq2?.nombre,
          eq2Logo: eq2?.logoUrl,
          invertir: true,
        ),
      );
    }

    // ── RONDA PREVIA (octavos) ────────────────────────────────────────────────
    // El ordenPrevio = cruceDestinoIdx + 1 (mismo que el cruce de cuartos al que alimenta).
    // Esto garantiza que el bracket visual los alinee: ambos comparten orden%2 (izq/der)
    // y la misma posición dentro de su columna lateral.

    for (int i = 0; i < numPrevios; i++) {
      final eq1 = sinBye[i];
      final eq2 = sinBye[sinBye.length - 1 - i];

      final int slotIdx = numByes + i;

      int cruceDestinoIdx;
      int posicionEnCruce;

      if (slotIdx < numCrucesCuartos) {
        cruceDestinoIdx = slotIdx;
        posicionEnCruce = 1;
      } else {
        cruceDestinoIdx = clasificados - 1 - slotIdx;
        posicionEnCruce = 2;
      }

      final String sigIdaId = cuartosIdaRef[cruceDestinoIdx].id;

      // ← CORRECCIÓN: el orden del previo es idéntico al orden del cruce destino
      final int ordenPrevio = cruceDestinoIdx + 1;

      final crucePrevioId = _db.collection('partidos_liguilla').doc().id;
      final previoIda = _db.collection('partidos_liguilla').doc();
      final previoVta = _db.collection('partidos_liguilla').doc();

      batch.set(
        previoIda,
        _mkP(
          cruceId: crucePrevioId,
          numeroPartido: 1,
          ronda: 'previo',
          orden: ordenPrevio,
          posicion: posicionEnCruce,
          siguienteIdaId: sigIdaId,
          eq1Id: eq1.id,
          eq1Nombre: eq1.nombre,
          eq1Logo: eq1.logoUrl,
          eq2Id: eq2.id,
          eq2Nombre: eq2.nombre,
          eq2Logo: eq2.logoUrl,
        ),
      );
      batch.set(
        previoVta,
        _mkP(
          cruceId: crucePrevioId,
          numeroPartido: 2,
          ronda: 'previo',
          orden: ordenPrevio,
          posicion: posicionEnCruce,
          siguienteIdaId: sigIdaId,
          eq1Id: eq1.id,
          eq1Nombre: eq1.nombre,
          eq1Logo: eq1.logoUrl,
          eq2Id: eq2.id,
          eq2Nombre: eq2.nombre,
          eq2Logo: eq2.logoUrl,
          invertir: true,
        ),
      );
    }

    // ── SEMIS ─────────────────────────────────────────────────────────────
    // semi 0 (ord 1, izq) → Final pos 1
    // semi 1 (ord 2, der) → Final pos 2

    for (int i = 0; i < numCrucesSemis; i++) {
      final int posicion = i + 1;
      final String cruceId = semisIds[i];

      batch.set(
        semisIdaRef[i],
        _mkP(
          cruceId: cruceId,
          numeroPartido: 1,
          ronda: 'semis',
          orden: i + 1,
          posicion: posicion,
          siguienteIdaId: finalIda.id,
        ),
      );
      batch.set(
        semisVtaRef[i],
        _mkP(
          cruceId: cruceId,
          numeroPartido: 2,
          ronda: 'semis',
          orden: i + 1,
          posicion: posicion,
          siguienteIdaId: finalIda.id,
        ),
      );
    }

    // ── FINAL ─────────────────────────────────────────────────────────────
    batch.set(
      finalIda,
      _mkP(
        cruceId: finalId,
        numeroPartido: 1,
        ronda: 'final',
        orden: 1,
        posicion: 1,
      ),
    );
    batch.set(
      finalVta,
      _mkP(
        cruceId: finalId,
        numeroPartido: 2,
        ronda: 'final',
        orden: 1,
        posicion: 1,
      ),
    );

    // ── Documento de liguilla ─────────────────────────────────────────────
    batch.set(liguillaRef, {
      'temporadaId': seasonId,
      'tipo': 'B',
      'estado': 'en_curso',
      'fechaInicio': DateTime.now(),
    });

    await batch.commit();
    return liguillaId;
  }

  // ─── agruparEnCruces ───────────────────────────────────────────────────────
  //
  // Convierte la lista plana de PartidoLiguilla en Cruces agrupados.
  // Ordena respetando: previo → cuartos → semis → final, y dentro de cada
  // ronda por `orden` ascendente.
  //
  List<Cruce> agruparEnCruces(List<PartidoLiguilla> partidos) {
    final Map<String, List<PartidoLiguilla>> porCruce = {};

    for (final p in partidos) {
      final key = p.cruceId;

      if (key == null || key.isEmpty) {
        print('❌ ERROR: partido sin cruceId → ${p.id}');
        continue; // 🔥 no lo agrupes mal
      }

      porCruce.putIfAbsent(key, () => []).add(p);
    }

    final cruces = porCruce.entries.map((e) {
      final lista = e.value
        ..sort((a, b) => a.numeroPartido.compareTo(b.numeroPartido));

      final ida = lista.first;
      final vuelta = lista.length > 1 ? lista[1] : null;

      return Cruce(ida: ida, vuelta: vuelta);
    }).toList();

    const ordenRonda = {'previo': 0, 'cuartos': 1, 'semis': 2, 'final': 3};

    cruces.sort((a, b) {
      final r = (ordenRonda[a.ronda] ?? 0).compareTo(ordenRonda[b.ronda] ?? 0);
      return r != 0 ? r : a.orden.compareTo(b.orden);
    });

    print('✅ CRUCES AGRUPADOS: ${cruces.length}');

    return cruces;
  }

  /// Obtiene la liguilla B de la temporada activa.
  Future<Liguilla?> getLiguillaB() async {
    final seasonId = currentSeasonId.value;
    if (seasonId == null) return null;
    final snap = await _db
        .collection('liguillas')
        .where('temporadaId', isEqualTo: seasonId)
        .where('tipo', isEqualTo: 'B')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Liguilla.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Devuelve los partidos de la liguilla B.
  Future<List<PartidoLiguilla>> getPartidosLiguillaB() async {
    final liguilla = await getLiguillaB();
    if (liguilla == null) return [];
    final snap = await _db
        .collection('partidos_liguilla')
        .where('liguillaId', isEqualTo: liguilla.id)
        .get();
    final partidos = snap.docs
        .map((d) => PartidoLiguilla.fromMap(d.id, d.data()))
        .toList();
    const orden = {'previo': -1, 'cuartos': 0, 'semis': 1, 'final': 2};
    partidos.sort((a, b) {
      final r = (orden[a.ronda] ?? 0).compareTo(orden[b.ronda] ?? 0);
      if (r != 0) return r;
      final o = a.orden.compareTo(b.orden);
      return o != 0 ? o : a.numeroPartido.compareTo(b.numeroPartido);
    });
    return partidos;
  }

  /// Registra el resultado de un partido (ida o vuelta).
  ///
  /// Si es la vuelta, calcula el ganador del cruce por marcador global.
  /// En caso de empate global, requiere [ganadorPenalesId].
  /// Al resolverse el cruce propaga el ganador al siguiente cruce (ida + vuelta).
  Future<void> registrarResultadoLiguilla({
    required String partidoId,
    required int golesEquipo1,
    required int golesEquipo2,
    bool penales = false,
    String? ganadorPenalesId,
  }) async {
    final ref = _db.collection('partidos_liguilla').doc(partidoId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Partido no encontrado');
    final partido = PartidoLiguilla.fromMap(snap.id, snap.data()!);

    // Ganador de ESTE partido (puede ser null si hay empate en la ida)
    String? ganadorPartidoId;
    if (golesEquipo1 > golesEquipo2) {
      ganadorPartidoId = partido.equipo1Id;
    } else if (golesEquipo2 > golesEquipo1) {
      ganadorPartidoId = partido.equipo2Id;
    }
    // Si empatan no hay ganador de partido — es válido en liguilla

    final batch = _db.batch();

    // Actualiza este partido
    batch.update(ref, {
      'golesEquipo1': golesEquipo1,
      'golesEquipo2': golesEquipo2,
      'penales': penales,
      'ganadorPenalesId': ganadorPenalesId,
      'ganadorId': ganadorPartidoId,
      'jugado': true,
    });

    // ── Si es vuelta, intenta resolver el cruce ─────────────────────────────
    if (partido.esVuelta && partido.cruceId != null) {
      // Busca el partido de ida del mismo cruce
      final idaSnaps = await _db
          .collection('partidos_liguilla')
          .where('cruceId', isEqualTo: partido.cruceId)
          .where('numeroPartido', isEqualTo: 1)
          .limit(1)
          .get();

      if (idaSnaps.docs.isNotEmpty) {
        final idaData = idaSnaps.docs.first.data();
        final idaJugado = idaData['jugado'] as bool? ?? false;

        if (idaJugado) {
          // ── Calcula marcador global ────────────────────────────────────────
          // IDA: equipo1 del cruce (eq1Cruce) visita al equipo2 (eq2Cruce).
          // Los goles del cruce desde la perspectiva del equipo1Cruce (el del slot):
          //   Ida:    golesEquipo1Ida = goles eq1Cruce | golesEquipo2Ida = goles eq2Cruce
          //   Vuelta: en vuelta los equipos se invierten en el doc,
          //           así que golesEquipo2Vuelta = goles eq1Cruce | golesEquipo1Vuelta = goles eq2Cruce

          final golesIdaEq1Cruce =
              (idaData['golesEquipo1'] as num?)?.toInt() ?? 0;
          final golesIdaEq2Cruce =
              (idaData['golesEquipo2'] as num?)?.toInt() ?? 0;
          // En vuelta los equipos están invertidos en el doc
          final golesVueltaEq1Cruce =
              golesEquipo2; // equipo2 del doc vuelta = eq1 del cruce
          final golesVueltaEq2Cruce =
              golesEquipo1; // equipo1 del doc vuelta = eq2 del cruce

          final totalEq1 = golesIdaEq1Cruce + golesVueltaEq1Cruce;
          final totalEq2 = golesIdaEq2Cruce + golesVueltaEq2Cruce;

          // equipo1Id del cruce = equipo1Id del partido de ida
          final eq1CruceId = idaData['equipo1Id'] as String?;
          final eq2CruceId = idaData['equipo2Id'] as String?;
          final eq1Nombre = idaData['equipo1Nombre'] as String? ?? '';
          final eq2Nombre = idaData['equipo2Nombre'] as String? ?? '';
          final eq1Logo = idaData['equipo1LogoUrl'] as String? ?? '';
          final eq2Logo = idaData['equipo2LogoUrl'] as String? ?? '';

          String? ganadorCruceId;
          String ganadorNombre;
          String ganadorLogo;

          if (totalEq1 > totalEq2) {
            ganadorCruceId = eq1CruceId;
            ganadorNombre = eq1Nombre;
            ganadorLogo = eq1Logo;
          } else if (totalEq2 > totalEq1) {
            ganadorCruceId = eq2CruceId;
            ganadorNombre = eq2Nombre;
            ganadorLogo = eq2Logo;
          } else {
            // Empate global → avanza el mejor posicionado (eq1Cruce = mejor clasificado)
            ganadorCruceId = eq1CruceId;
            ganadorNombre = eq1Nombre;
            ganadorLogo = eq1Logo;
          }

          // Marca la vuelta como cruce resuelto
          batch.update(ref, {
            'ganadorCruceId': ganadorCruceId,
            'cruceResuelto': true,
          });

          // Propaga ganador al siguiente cruce (ida + vuelta del siguiente)
          if (partido.siguientePartidoId != null) {
            // siguientePartidoId apunta al partido de IDA del siguiente cruce
            final sigIdaRef = _db
                .collection('partidos_liguilla')
                .doc(partido.siguientePartidoId);
            final sigIdaSnap = await sigIdaRef.get();

            if (sigIdaSnap.exists) {
              final esSlot1 = partido.posicion == 1;
              final campoId = esSlot1 ? 'equipo1Id' : 'equipo2Id';
              final campoNombre = esSlot1 ? 'equipo1Nombre' : 'equipo2Nombre';
              final campoLogo = esSlot1 ? 'equipo1LogoUrl' : 'equipo2LogoUrl';

              // Actualiza ida del siguiente cruce
              batch.update(sigIdaRef, {
                campoId: ganadorCruceId,
                campoNombre: ganadorNombre,
                campoLogo: ganadorLogo,
              });

              // Busca y actualiza también la vuelta del siguiente cruce
              final sigCruceId = sigIdaSnap.data()?['cruceId'] as String?;
              if (sigCruceId != null) {
                final sigVueltaSnaps = await _db
                    .collection('partidos_liguilla')
                    .where('cruceId', isEqualTo: sigCruceId)
                    .where('numeroPartido', isEqualTo: 2)
                    .limit(1)
                    .get();

                if (sigVueltaSnaps.docs.isNotEmpty) {
                  final sigVueltaRef = sigVueltaSnaps.docs.first.reference;
                  // En vuelta los equipos están invertidos:
                  // slot1 → el ganador va al campo equipo2 de la vuelta
                  // slot2 → el ganador va al campo equipo1 de la vuelta
                  final campoVueltaId = esSlot1 ? 'equipo2Id' : 'equipo1Id';
                  final campoVueltaNombre = esSlot1
                      ? 'equipo2Nombre'
                      : 'equipo1Nombre';
                  final campoVueltaLogo = esSlot1
                      ? 'equipo2LogoUrl'
                      : 'equipo1LogoUrl';
                  batch.update(sigVueltaRef, {
                    campoVueltaId: ganadorCruceId,
                    campoVueltaNombre: ganadorNombre,
                    campoVueltaLogo: ganadorLogo,
                  });
                }
              }
            }
          }
        }
      }
    }

    await batch.commit();
  }

  Future<Liguilla?> getLiguilla() async {
    final seasonId = currentSeasonId.value;
    if (seasonId == null) return null;
    final snap = await _db
        .collection('liguillas')
        .where('temporadaId', isEqualTo: seasonId)
        .where('tipo', isEqualTo: 'A') // ← agrega esto
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final l = Liguilla.fromMap(snap.docs.first.id, snap.docs.first.data());
    _currentLiguilla = l;
    return l;
  }

  /// Devuelve todos los partidos de liguilla agrupados en [Cruce].
  Future<List<PartidoLiguilla>> getPartidosLiguilla() async {
    final liguilla = _currentLiguilla ?? await getLiguilla();
    if (liguilla == null) return [];
    final snap = await _db
        .collection('partidos_liguilla')
        .where('liguillaId', isEqualTo: liguilla.id)
        .get();
    final partidos = snap.docs
        .map((d) => PartidoLiguilla.fromMap(d.id, d.data()))
        .toList();
    const orden = {'cuartos': 0, 'semis': 1, 'final': 2};
    partidos.sort((a, b) {
      final r = (orden[a.ronda] ?? 0).compareTo(orden[b.ronda] ?? 0);
      if (r != 0) return r;
      final o = a.orden.compareTo(b.orden);
      return o != 0 ? o : a.numeroPartido.compareTo(b.numeroPartido);
    });
    return partidos;
  }

  Future<void> actualizarFechaHoraPartidoLiguilla({
    required String partidoId,
    DateTime? fecha,
    String? hora,
  }) async {
    await _db.collection('partidos_liguilla').doc(partidoId).update({
      'fecha': fecha?.toIso8601String(),
      'hora': hora ?? '',
    });
  }

  Future<void> actualizarFechaHoraPartido({
    required String jornadaId,
    required String partidoId,
    DateTime? fecha,
    String? hora,
  }) async {
    await _jornadasRef
        .doc(jornadaId)
        .collection('partidos')
        .doc(partidoId)
        .update({
          'fecha': fecha != null ? fecha.toIso8601String() : null,
          'hora': hora ?? '',
        });

    _invalidateForCurrentSeason(['home', 'proximo_partido']);
    _cache.remove('partidos_$jornadaId');
    _cache.remove('jornadas_con_partidos_${currentSeasonId.value}');
  }
}
