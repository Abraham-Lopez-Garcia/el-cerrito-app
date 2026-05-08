import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/partido_model.dart';
import '../models/jugador_model.dart';
import '../models/equipo_model.dart';
import '../models/goleador_model.dart';

// ─── PALETA ────────────────────────────────────────────────────────────────
class _P {
  static const bg = Color(0xFFF0F2F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8EAF0);
  static const slate = Color(0xFF9A9FBA);
  static const navy = Color(0xFF1A1A2E);
  static const blue = Color(0xFF3A6FD8);
  static const blueLight = Color(0xFFEAF1FF);
  static const green = Color(0xFF27AE60);
  static const greenLight = Color(0xFFE6F9F2);
  static const red = Color(0xFFE74C3C);
  static const redLight = Color(0xFFFEF0ED);
}

TextStyle _ts({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _P.navy,
  double height = 1.4,
  double letterSpacing = 0,
}) => GoogleFonts.dmSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

// ─── MAIN SCREEN ───────────────────────────────────────────────────────────
class EditMatchdayScreen extends StatefulWidget {
  final String matchdayId;
  final int matchdayNumber;

  const EditMatchdayScreen({
    super.key,
    required this.matchdayId,
    required this.matchdayNumber,
  });

  @override
  State<EditMatchdayScreen> createState() => _EditMatchdayScreenState();
}

class _EditMatchdayScreenState extends State<EditMatchdayScreen> {
  List<Partido> _partidos = [];
  List<Partido> _partidosOriginales = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isSaving = false;

  final Map<String, List<Jugador>> _jugadoresCache = {};
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadMatchday();
  }

  Future<void> _loadMatchday() async {
    try {
      final partidos = await _firestoreService.getPartidos(widget.matchdayId);
      setState(() {
        _partidos = partidos;
        _partidosOriginales = List.from(partidos);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar jornada: $e',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<List<Jugador>> _getJugadoresCached(String equipoId) async {
    if (_jugadoresCache.containsKey(equipoId))
      return _jugadoresCache[equipoId]!;
    final jugadores = await _firestoreService.getJugadores(equipoId);
    _jugadoresCache[equipoId] = jugadores;
    return jugadores;
  }

  void _showEditMatchDialog(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => _EditMatchDialog(
        partido: _partidos[index],
        getJugadores: _getJugadoresCached,
        onSave: (partidoActualizado) {
          setState(() {
            _partidos[index] = partidoActualizado;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final partidosModificados = <({Partido actual, Partido original})>[];
      for (int i = 0; i < _partidos.length; i++) {
        final actual = _partidos[i];
        final original = _partidosOriginales[i];
        if (_sinCambios(actual, original)) continue;
        // Solo requiere resultado para actualizar stats; fecha/hora siempre se guarda
        partidosModificados.add((actual: actual, original: original));
      }

      if (partidosModificados.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // Partidos que SÍ tienen resultado y necesitan recalcular stats
      final conResultado = partidosModificados
          .where((p) => p.actual.tieneResultado)
          .toList();

      // Partidos que solo cambiaron fecha/hora (sin resultado)
      final soloFechaHora = partidosModificados
          .where((p) => !p.actual.tieneResultado)
          .toList();

      // Guardar solo fecha/hora sin tocar stats
      await Future.wait(
        soloFechaHora.map(
          (p) => _firestoreService.actualizarFechaHoraPartido(
            jornadaId: widget.matchdayId,
            partidoId: p.actual.id,
            fecha: p.actual.fecha,
            hora: p.actual.hora,
          ),
        ),
      );

      if (conResultado.isNotEmpty) {
        final equipoIds = conResultado
            .expand((p) => [p.actual.equipo1Id, p.actual.equipo2Id])
            .toSet();

        final equiposLista = await Future.wait(
          equipoIds.map((id) => _firestoreService.getEquipoById(id)),
        );

        final equiposMap = <String, Equipo>{};
        for (final equipo in equiposLista) {
          if (equipo != null) equiposMap[equipo.id] = equipo;
        }

        for (final id in equipoIds) {
          if (!equiposMap.containsKey(id)) {
            throw Exception('No se encontró el equipo $id');
          }
        }

        await Future.wait(
          conResultado.map((p) {
            final equipo1 = equiposMap[p.actual.equipo1Id]!;
            final equipo2 = equiposMap[p.actual.equipo2Id]!;
            Equipo? equipo1Anterior;
            Equipo? equipo2Anterior;
            if (p.original.tieneResultado) {
              equipo1Anterior = _buildDeltaEquipo(
                equipo: equipo1,
                golesFavor: p.original.golesEquipo1!,
                golesContra: p.original.golesEquipo2!,
                penales: p.original.penales,
                ganoPenales:
                    p.original.penales &&
                    p.original.ganadorPenalesId == p.actual.equipo1Id,
              );
              equipo2Anterior = _buildDeltaEquipo(
                equipo: equipo2,
                golesFavor: p.original.golesEquipo2!,
                golesContra: p.original.golesEquipo1!,
                penales: p.original.penales,
                ganoPenales:
                    p.original.penales &&
                    p.original.ganadorPenalesId == p.actual.equipo2Id,
              );
            }
            return _firestoreService.guardarResultadoPartido(
              jornadaId: widget.matchdayId,
              partidoId: p.actual.id,
              partidoActualizado: p.actual,
              equipo1Antes: equipo1,
              equipo2Antes: equipo2,
              equipo1ResultadoAnterior: equipo1Anterior,
              equipo2ResultadoAnterior: equipo2Anterior,
              goleadoresOriginales: p.original.tieneResultado
                  ? p.original.goleadores
                  : [],
            );
          }),
        );
      }

      _partidosOriginales = List.from(_partidos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cambios guardados exitosamente',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: $e',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _sinCambios(Partido actual, Partido original) {
    // Comparar fechas solo por día (ignorar hora del objeto DateTime)
    final mismaFecha = _mismaFecha(actual.fecha, original.fecha);
    final mismaHora = (actual.hora ?? '') == (original.hora ?? '');

    return actual.golesEquipo1 == original.golesEquipo1 &&
        actual.golesEquipo2 == original.golesEquipo2 &&
        actual.penales == original.penales &&
        actual.ganadorPenalesId == original.ganadorPenalesId &&
        _mismasListasGoleadores(actual.goleadores, original.goleadores) &&
        mismaFecha &&
        mismaHora;
  }

  bool _mismaFecha(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Equipo _buildDeltaEquipo({
    required Equipo equipo,
    required int golesFavor,
    required int golesContra,
    required bool penales,
    required bool ganoPenales,
  }) {
    int pg = 0, pe = 0, pp = 0, pts = 0;
    if (golesFavor > golesContra) {
      pg = 1;
      pts = 3;
    } else if (golesFavor < golesContra) {
      pp = 1;
    } else {
      pe = 1;
      if (penales) pts = ganoPenales ? 2 : 1;
    }
    return equipo.copyWith(
      pj: 1,
      pg: pg,
      pe: pe,
      pp: pp,
      gf: golesFavor,
      gc: golesContra,
      pts: pts,
    );
  }

  bool _mismasListasGoleadores(List<Goleador> a, List<Goleador> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].jugadorId != b[i].jugadorId || a[i].goles != b[i].goles)
        return false;
    }
    return true;
  }

  // ─── STATS SUMMARY ─────────────────────────────────────────────────────
  int get _partidosJugados => _partidos.where((p) => p.tieneResultado).length;
  int get _totalGoles => _partidos.fold(
    0,
    (sum, p) => sum + (p.golesEquipo1 ?? 0) + (p.golesEquipo2 ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: _P.blue,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else ...[
              _buildStatsBar(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  itemCount: _partidos.length,
                  itemBuilder: (context, index) =>
                      _buildPartidoCard(_partidos[index], index),
                ),
              ),
            ],
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(6, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _P.navy,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JORNADA ${widget.matchdayNumber}',
                  style: _ts(
                    size: 20,
                    weight: FontWeight.w800,
                    letterSpacing: 1.6,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Editar partidos',
                  style: _ts(
                    size: 11,
                    color: _P.slate,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _P.redLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _P.red.withOpacity(0.3), width: 0.5),
              ),
              child: Text(
                'Sin guardar',
                style: _ts(size: 11, weight: FontWeight.w600, color: _P.red),
              ),
            ),
        ],
      ),
    );
  }

  // ─── STATS BAR ─────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _buildStatChip(
            icon: Icons.sports_soccer_rounded,
            label: '$_partidosJugados/${_partidos.length}',
            sublabel: 'jugados',
            color: _P.blue,
            bgColor: _P.blueLight,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            icon: Icons.emoji_events_rounded,
            label: '$_totalGoles',
            sublabel: 'goles',
            color: _P.green,
            bgColor: _P.greenLight,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            icon: Icons.pending_actions_rounded,
            label: '${_partidos.length - _partidosJugados}',
            sublabel: 'pendientes',
            color: _P.slate,
            bgColor: _P.bg,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _ts(size: 13, weight: FontWeight.w700, color: color),
                ),
                Text(
                  sublabel,
                  style: _ts(
                    size: 10,
                    color: _P.slate,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── PARTIDO CARD ───────────────────────────────────────────────────────
  Widget _buildPartidoCard(Partido p, int index) {
    final hasResult = p.tieneResultado;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasResult ? _P.green.withOpacity(0.30) : _P.border,
          width: hasResult ? 1 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showEditMatchDialog(index),
          borderRadius: BorderRadius.circular(14),
          splashColor: _P.blueLight,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // ── Status strip ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hasResult ? _P.greenLight : _P.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: hasResult
                              ? _P.green.withOpacity(0.35)
                              : _P.border,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasResult
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 10,
                            color: hasResult ? _P.green : _P.slate,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasResult ? 'Jugado' : 'Pendiente',
                            style: _ts(
                              size: 10,
                              weight: FontWeight.w600,
                              color: hasResult ? _P.green : _P.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (p.fecha != null)
                      Text(
                        _formatFecha(p.fecha!, p.hora),
                        style: _ts(size: 11, color: _P.slate),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _P.blueLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: _P.blue,
                        size: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Match row ─────────────────────────────────────────
                Row(
                  children: [
                    // Equipo 1
                    Expanded(
                      child: Text(
                        p.equipo1Nombre,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(size: 14, weight: FontWeight.w700),
                      ),
                    ),

                    // Score pill
                    Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: hasResult ? _P.greenLight : _P.bg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: hasResult
                              ? _P.green.withOpacity(0.40)
                              : _P.border,
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        hasResult
                            ? '${p.golesEquipo1} – ${p.golesEquipo2}'
                            : 'VS',
                        style: _ts(
                          size: hasResult ? 16 : 13,
                          weight: FontWeight.w800,
                          color: hasResult ? _P.green : _P.slate,
                        ),
                      ),
                    ),

                    // Equipo 2
                    Expanded(
                      child: Text(
                        p.equipo2Nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(size: 14, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),

                // ── Penales badge ────────────────────────────────────
                if (hasResult && p.penales) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _P.blueLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _P.blue.withOpacity(0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sports_soccer_rounded,
                          size: 12,
                          color: _P.blue,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Definido por penales',
                          style: _ts(
                            size: 11,
                            weight: FontWeight.w600,
                            color: _P.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Scorers preview ──────────────────────────────────
                if (hasResult && p.goleadores.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(height: 0, thickness: 0.5, color: _P.border),
                  const SizedBox(height: 10),
                  _buildScorersPreview(p),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScorersPreview(Partido p) {
    final allScorers = p.goleadores;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: allScorers.map((g) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: _P.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sports_soccer_rounded,
                size: 11,
                color: _P.slate,
              ),
              const SizedBox(width: 4),
              Text(
                g.goles > 1 ? '${g.nombre} ×${g.goles}' : g.nombre,
                style: _ts(size: 11, weight: FontWeight.w600, color: _P.navy),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── FOOTER ────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final canAct = _hasChanges && !_isSaving;

    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSaving ? null : () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _P.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _P.border, width: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancelar',
                    style: _ts(
                      size: 14,
                      weight: FontWeight.w600,
                      color: _P.slate,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canAct ? _saveChanges : null,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: canAct ? _P.green : _P.border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: canAct ? Colors.white : _P.slate,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Confirmar cambios',
                              style: _ts(
                                size: 14,
                                weight: FontWeight.w700,
                                color: canAct ? Colors.white : _P.slate,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────
  String _formatFecha(DateTime fecha, String? hora) {
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final base = '${fecha.day} ${meses[fecha.month - 1]}';
    if (hora != null && hora.isNotEmpty) return '$base · $hora';
    return base;
  }
}

// ============================================================================
// DIÁLOGO DE EDICIÓN
// ============================================================================

class _EditMatchDialog extends StatefulWidget {
  final Partido partido;
  final Future<List<Jugador>> Function(String equipoId) getJugadores;
  final ValueChanged<Partido> onSave;

  const _EditMatchDialog({
    required this.partido,
    required this.getJugadores,
    required this.onSave,
  });

  @override
  State<_EditMatchDialog> createState() => _EditMatchDialogState();
}

class _EditMatchDialogState extends State<_EditMatchDialog> {
  late TextEditingController _goals1Controller;
  late TextEditingController _goals2Controller;
  late List<Goleador> _goleadores1;
  late List<Goleador> _goleadores2;
  late bool _isPenalties;
  String? _penaltyWinner;
  DateTime? _matchDate;
  TimeOfDay? _matchTime;
  List<Jugador> _players1 = [];
  List<Jugador> _players2 = [];
  bool _isLoadingPlayers = true;

  @override
  void initState() {
    super.initState();
    final p = widget.partido;
    _goals1Controller = TextEditingController(
      text: p.golesEquipo1?.toString() ?? '',
    );
    _goals2Controller = TextEditingController(
      text: p.golesEquipo2?.toString() ?? '',
    );
    _goleadores1 = List.from(p.goleadoresEquipo1);
    _goleadores2 = List.from(p.goleadoresEquipo2);
    _isPenalties = p.penales;
    _penaltyWinner = p.ganadorPenalesId;
    _matchDate = p.fecha ?? DateTime.now();
    if (p.hora != null && p.hora!.isNotEmpty) {
      final parts = p.hora!.split(':');
      _matchTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      _matchTime = TimeOfDay.now();
    }
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      final results = await Future.wait([
        widget.getJugadores(widget.partido.equipo1Id),
        widget.getJugadores(widget.partido.equipo2Id),
      ]);
      if (mounted) {
        setState(() {
          _players1 = results[0];
          _players2 = results[1];
          _isLoadingPlayers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlayers = false);
    }
  }

  bool _validateScorers() {
    final goals1 = int.tryParse(_goals1Controller.text);
    final goals2 = int.tryParse(_goals2Controller.text);
    if (goals1 == null && goals2 == null) return true;
    if (goals1 == null || goals2 == null) return false;
    final total1 = _goleadores1.fold<int>(0, (s, g) => s + g.goles);
    final total2 = _goleadores2.fold<int>(0, (s, g) => s + g.goles);
    return total1 == goals1 && total2 == goals2;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _matchDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _P.blue,
            onPrimary: Colors.white,
            surface: _P.surface,
            onSurface: _P.navy,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _matchDate = date);
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _matchTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _P.blue,
            onPrimary: Colors.white,
            surface: _P.surface,
            onSurface: _P.navy,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _matchTime = time);
  }

  String _getHoraString() {
    if (_matchTime == null) return '';
    return '${_matchTime!.hour.toString().padLeft(2, '0')}:'
        '${_matchTime!.minute.toString().padLeft(2, '0')}';
  }

  String _formatFechaDisplay(DateTime d) {
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  void _onConfirm() {
    final goals1 = int.tryParse(_goals1Controller.text);
    final goals2 = int.tryParse(_goals2Controller.text);
    final todosLosGoleadores = [..._goleadores1, ..._goleadores2];
    widget.onSave(
      widget.partido.copyWith(
        golesEquipo1: goals1,
        golesEquipo2: goals2,
        penales: _isPenalties,
        ganadorPenalesId: _isPenalties ? _penaltyWinner : null,
        goleadores: todosLosGoleadores,
        fecha: _matchDate,
        hora: _getHoraString(),
        jugado: goals1 != null && goals2 != null,
      ),
    );
    Navigator.pop(context);
  }

  void _addGoleador(
    Jugador jugador,
    List<Goleador> lista,
    String equipoNombre,
  ) {
    setState(() {
      final idx = lista.indexWhere((g) => g.jugadorId == jugador.id);
      if (idx >= 0) {
        lista[idx] = Goleador(
          jugadorId: lista[idx].jugadorId,
          nombre: lista[idx].nombre,
          equipoId: lista[idx].equipoId,
          equipoNombre: lista[idx].equipoNombre,
          fotoUrl: lista[idx].fotoUrl,
          goles: lista[idx].goles + 1,
        );
      } else {
        lista.add(
          Goleador(
            jugadorId: jugador.id,
            nombre: jugador.nombre,
            equipoId: jugador.equipoId,
            equipoNombre: equipoNombre, // ✅
            fotoUrl: jugador.fotoUrl, // ✅
            goles: 1,
          ),
        );
      }
    });
  }

  void _removeGoleador(String jugadorId, List<Goleador> lista) {
    setState(() {
      final idx = lista.indexWhere((g) => g.jugadorId == jugadorId);
      if (idx < 0) return;
      if (lista[idx].goles > 1) {
        lista[idx] = Goleador(
          jugadorId: lista[idx].jugadorId,
          nombre: lista[idx].nombre,
          equipoId: lista[idx].equipoId,
          goles: lista[idx].goles - 1,
        );
      } else {
        lista.removeAt(idx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final goals1 = int.tryParse(_goals1Controller.text);
    final goals2 = int.tryParse(_goals2Controller.text);
    final isTie = goals1 != null && goals2 != null && goals1 == goals2;

    return Dialog(
      backgroundColor: _P.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _P.border, width: 0.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog header ─────────────────────────────────────────
            _buildDialogHeader(),
            const Divider(height: 0, thickness: 0.5, color: _P.border),

            // ── Scrollable body ───────────────────────────────────────
            Flexible(
              child: _isLoadingPlayers
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _P.blue,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Fecha y hora ──────────────────────────
                          _buildSectionLabel(
                            Icons.calendar_today_rounded,
                            'Fecha y hora',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateTimeButton(
                                  icon: Icons.calendar_today_rounded,
                                  label: _matchDate != null
                                      ? _formatFechaDisplay(_matchDate!)
                                      : 'Seleccionar',
                                  onTap: _selectDate,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDateTimeButton(
                                  icon: Icons.access_time_rounded,
                                  label: _matchTime != null
                                      ? _getHoraString()
                                      : 'Hora',
                                  onTap: _selectTime,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          Divider(height: 0, thickness: 0.5, color: _P.border),
                          const SizedBox(height: 20),

                          // ── Resultado ─────────────────────────────
                          _buildSectionLabel(
                            Icons.scoreboard_rounded,
                            'Resultado',
                          ),
                          const SizedBox(height: 10),
                          _buildScoreRow(),

                          // ── Penales ───────────────────────────────
                          if (isTie) ...[
                            const SizedBox(height: 14),
                            _buildPenalesSection(),
                          ],

                          // ── Goleadores ────────────────────────────
                          if (goals1 != null && goals1 > 0) ...[
                            const SizedBox(height: 20),
                            Divider(
                              height: 0,
                              thickness: 0.5,
                              color: _P.border,
                            ),
                            const SizedBox(height: 20),
                            _buildScorersSection(
                              teamName: widget.partido.equipo1Nombre,
                              players: _players1,
                              goleadores: _goleadores1,
                              requiredGoals: goals1,
                            ),
                          ],
                          if (goals2 != null && goals2 > 0) ...[
                            const SizedBox(height: 16),
                            _buildScorersSection(
                              teamName: widget.partido.equipo2Nombre,
                              players: _players2,
                              goleadores: _goleadores2,
                              requiredGoals: goals2,
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
            ),

            const Divider(height: 0, thickness: 0.5, color: _P.border),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  // ─── DIALOG HEADER ─────────────────────────────────────────────────────
  Widget _buildDialogHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _P.blueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.edit_rounded, color: _P.blue, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.partido.equipo1Nombre} vs ${widget.partido.equipo2Nombre}',
                  style: _ts(size: 14, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Editar partido',
                  style: _ts(
                    size: 11,
                    color: _P.slate,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, color: _P.slate),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION LABEL ─────────────────────────────────────────────────────
  Widget _buildSectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _P.blue),
        const SizedBox(width: 6),
        Text(
          label,
          style: _ts(
            size: 12,
            weight: FontWeight.w700,
            color: _P.slate,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ─── DATE TIME BUTTON ──────────────────────────────────────────────────
  Widget _buildDateTimeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _P.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: _ts(size: 12, weight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SCORE ROW ─────────────────────────────────────────────────────────
  Widget _buildScoreRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Team 1
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.partido.equipo1Nombre,
                  style: _ts(
                    size: 12,
                    weight: FontWeight.w600,
                    color: _P.slate,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildGoalField(_goals1Controller),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '–',
              style: _ts(size: 22, weight: FontWeight.w800, color: _P.border),
            ),
          ),

          // Team 2
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.partido.equipo2Nombre,
                  style: _ts(
                    size: 12,
                    weight: FontWeight.w600,
                    color: _P.slate,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildGoalField(_goals2Controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: _ts(size: 28, weight: FontWeight.w800),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: _ts(size: 28, weight: FontWeight.w800, color: _P.border),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _P.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _P.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _P.blue, width: 1.5),
        ),
        filled: true,
        fillColor: _P.bg,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // ─── PENALES ───────────────────────────────────────────────────────────
  Widget _buildPenalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle
        GestureDetector(
          onTap: () => setState(() {
            _isPenalties = !_isPenalties;
            if (!_isPenalties) _penaltyWinner = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isPenalties ? _P.blueLight : _P.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isPenalties ? _P.blue.withOpacity(0.35) : _P.border,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sports_soccer_rounded,
                  size: 16,
                  color: _isPenalties ? _P.blue : _P.slate,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Definido por penales',
                    style: _ts(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _isPenalties ? _P.blue : _P.navy,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _isPenalties ? _P.blue : _P.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment: _isPenalties
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Winner selector
        if (_isPenalties) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildPenaltyOption(
                  widget.partido.equipo1Id,
                  widget.partido.equipo1Nombre,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPenaltyOption(
                  widget.partido.equipo2Id,
                  widget.partido.equipo2Nombre,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPenaltyOption(String equipoId, String nombre) {
    final selected = _penaltyWinner == equipoId;
    return GestureDetector(
      onTap: () => setState(() => _penaltyWinner = equipoId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _P.blueLight : _P.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _P.blue : _P.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: selected ? _P.blue : _P.slate,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                nombre,
                style: _ts(
                  size: 12,
                  weight: FontWeight.w600,
                  color: selected ? _P.blue : _P.navy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SCORERS SECTION ───────────────────────────────────────────────────
  Widget _buildScorersSection({
    required String teamName,
    required List<Jugador> players,
    required List<Goleador> goleadores,
    required int requiredGoals,
  }) {
    final total = goleadores.fold<int>(0, (s, g) => s + g.goles);
    final isComplete = total == requiredGoals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            _buildSectionLabel(Icons.person_rounded, 'Goleadores · $teamName'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isComplete ? _P.greenLight : _P.redLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$total / $requiredGoals',
                style: _ts(
                  size: 11,
                  weight: FontWeight.w700,
                  color: isComplete ? _P.green : _P.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Current scorers
        if (goleadores.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: goleadores
                .map((g) => _buildScorerChip(g, goleadores))
                .toList(),
          ),
          const SizedBox(height: 10),
        ],

        // Add scorer dropdown
        if (!isComplete)
          _buildDropdown<String>(
            hint: 'Agregar goleador',
            items: players
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.nombre, style: _ts(size: 13)),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              _addGoleador(
                players.firstWhere((p) => p.id == id),
                goleadores,
                teamName,
              );
            },
          ),
      ],
    );
  }

  Widget _buildScorerChip(Goleador g, List<Goleador> lista) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_soccer_rounded, size: 12, color: _P.slate),
          const SizedBox(width: 5),
          Text(
            g.goles > 1 ? '${g.nombre} ×${g.goles}' : g.nombre,
            style: _ts(size: 12, weight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeGoleador(g.jugadorId, lista),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _P.redLight,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, size: 11, color: _P.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(hint, style: _ts(size: 13, color: _P.slate)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          borderRadius: BorderRadius.circular(10),
          items: items,
          onChanged: onChanged,
          value: null,
        ),
      ),
    );
  }

  // ─── DIALOG FOOTER ─────────────────────────────────────────────────────
  Widget _buildDialogFooter() {
    final canConfirm = _validateScorers();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _P.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _P.border, width: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancelar',
                    style: _ts(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _P.slate,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canConfirm ? _onConfirm : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: canConfirm ? _P.blue : _P.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Confirmar',
                    style: _ts(
                      size: 13,
                      weight: FontWeight.w700,
                      color: canConfirm ? Colors.white : _P.slate,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _goals1Controller.dispose();
    _goals2Controller.dispose();
    super.dispose();
  }
}
