import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/liguilla_model.dart';
import '../widgets/liguilla_download_dialog.dart';
import '../widgets/liguilla_section_tabs.dart';

// ─── PALETA ────────────────────────────────────────────────────────────────────
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
  static const amber = Color(0xFFF39C12);
  static const amberLight = Color(0xFFFFF8E6);
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

// ─── SCREEN ────────────────────────────────────────────────────────────────────
class LiguillaMatchdaysView extends StatefulWidget {
  const LiguillaMatchdaysView({super.key});

  @override
  State<LiguillaMatchdaysView> createState() => _LiguillaMatchdaysViewState();
}

class _LiguillaMatchdaysViewState extends State<LiguillaMatchdaysView>
    with TickerProviderStateMixin {
  // ─── Estado ───────────────────────────────────────────────────────────────
  final FirestoreService _service = FirestoreService();

  // Liguilla A
  List<Cruce> _cruces = [];
  bool _isLoading = true;
  late AnimationController _fadeCtrl;

  // Liguilla B
  List<Cruce> _crucesB = [];
  bool _isLoadingB = false;
  late AnimationController _fadeBCtrl;

  final _scrollController = ScrollController();
  final _keyPrevio = GlobalKey();
  final _keyCuartos = GlobalKey();
  final _keySemis = GlobalKey();
  final _keyFinal = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeBCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _service.liguillaActiva.addListener(_onLiguillaChanged);

    // Carga únicamente la liguilla activa al entrar
    if (_service.liguillaActiva.value == 'B') {
      _loadPartidosB();
    } else {
      _loadPartidos();
    }
  }

  void _onLiguillaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _fadeBCtrl.dispose();
    _service.liguillaActiva.removeListener(_onLiguillaChanged);
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Carga de datos ───────────────────────────────────────────────────────

  Future<void> _loadPartidos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _fadeCtrl.reset();
    try {
      final partidos = await _service.getPartidosLiguilla();
      final cruces = _service.agruparEnCruces(partidos);
      if (!mounted) return;
      setState(() {
        _cruces = cruces;
        _isLoading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      debugPrint('❌ LiguillaMatchdays A: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPartidosB() async {
    if (!mounted) return;
    setState(() => _isLoadingB = true);
    _fadeBCtrl.reset();
    try {
      final partidos = await _service.getPartidosLiguillaB();
      final cruces = _service.agruparEnCruces(partidos);
      if (!mounted) return;
      setState(() {
        _crucesB = cruces;
        _isLoadingB = false;
      });
      _fadeBCtrl.forward();
    } catch (e) {
      debugPrint('❌ LiguillaMatchdays B: $e');
      if (!mounted) return;
      setState(() => _isLoadingB = false);
    }
  }

  Widget _buildHeader() {
    final crucesActivos = _service.liguillaActiva.value == 'A'
        ? _cruces
        : _crucesB;
    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIGUILLA',
                  style: _ts(
                    size: 22,
                    weight: FontWeight.w800,
                    letterSpacing: 1.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Cruces y resultados',
                  style: _ts(
                    size: 11,
                    color: _P.slate,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (crucesActivos.isEmpty) return;
              showDialog(
                context: context,
                builder: (_) => LiguillaDownloadDialog(
                  cruces: crucesActivos,
                  liguillaLabel: _service.liguillaActiva.value,
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _P.blueLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _P.blue.withOpacity(0.25),
                  width: 0.5,
                ),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: _P.blue,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        // ── Toggle A / B ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _P.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Row(
            children: [
              _toggleBtn('A', 'Liguilla A', const Color(0xFF8B5CF6)),
              _toggleBtn('B', 'Liguilla B', _P.amber),
            ],
          ),
        ),
        // ── Contenido ────────────────────────────────────────────────────
        Expanded(
          child: _service.liguillaActiva.value == 'A'
              ? _buildContenidoA()
              : _buildContenidoB(),
        ),
      ],
    );
  }

  Widget _toggleBtn(String liga, String label, Color color) {
    final activo = _service.liguillaActiva.value == liga;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_service.liguillaActiva.value == liga) return;
          _service.liguillaActiva.value = liga;
          if (liga == 'B') {
            // Solo carga si no tiene datos válidos
            if (_crucesB.isEmpty) _loadPartidosB();
          } else {
            if (_cruces.isEmpty) _loadPartidos();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? _P.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 14,
                color: activo ? color : _P.slate,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _ts(
                  size: 13,
                  weight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: activo ? color : _P.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Contenido A ─────────────────────────────────────────────────────────

  Widget _buildContenidoA() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _P.blue, strokeWidth: 2.5),
      );
    }
    if (_cruces.isEmpty) return _buildEmptyState('A');

    final cuartos = _cruces.where((c) => c.ronda == 'cuartos').toList();
    final semis = _cruces.where((c) => c.ronda == 'semis').toList();
    final finalC = _cruces.where((c) => c.ronda == 'final').toList();

    return Stack(
      children: [
        RefreshIndicator(
          // ← el que ya tenías
          color: _P.blue,
          backgroundColor: _P.surface,
          onRefresh: _loadPartidos,
          child: FadeTransition(
            opacity: _fadeCtrl,
            child: _buildListaPartidos(
              cuartos: cuartos,
              semis: semis,
              finalC: finalC,
            ),
          ),
        ),
        Positioned(
          // ← NUEVO
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: LiguillaSectionTabs(
              scrollController: _scrollController,
              tabs: [
                SectionTab(
                  label: 'CUARTOS',
                  color: _P.blue,
                  bgColor: _P.blueLight,
                  sectionKey: _keyCuartos,
                ),
                SectionTab(
                  label: 'SEMIS',
                  color: _P.green,
                  bgColor: _P.greenLight,
                  sectionKey: _keySemis,
                ),
                SectionTab(
                  label: 'FINAL',
                  color: _P.amber,
                  bgColor: _P.amberLight,
                  sectionKey: _keyFinal,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Contenido B ─────────────────────────────────────────────────────────

  Widget _buildContenidoB() {
    if (_isLoadingB) {
      return const Center(
        child: CircularProgressIndicator(color: _P.amber, strokeWidth: 2.5),
      );
    }
    if (_crucesB.isEmpty) return _buildEmptyState('B');

    final previos = _crucesB.where((c) => c.ronda == 'previo').toList();
    final cuartos = _crucesB.where((c) => c.ronda == 'cuartos').toList();
    final semis = _crucesB.where((c) => c.ronda == 'semis').toList();
    final finalC = _crucesB.where((c) => c.ronda == 'final').toList();

    return Stack(
      children: [
        RefreshIndicator(
          color: _P.amber,
          backgroundColor: _P.surface,
          onRefresh: _loadPartidosB,
          child: FadeTransition(
            opacity: _fadeBCtrl,
            child: _buildListaPartidos(
              previos: previos,
              cuartos: cuartos,
              semis: semis,
              finalC: finalC,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: LiguillaSectionTabs(
              scrollController: _scrollController,
              tabs: [
                if (previos.isNotEmpty)
                  SectionTab(
                    label: 'PREVIOS',
                    color: const Color(0xFF8B5CF6),
                    bgColor: const Color(0xFFF3EEFF),
                    sectionKey: _keyPrevio,
                  ),
                SectionTab(
                  label: 'CUARTOS',
                  color: _P.blue,
                  bgColor: _P.blueLight,
                  sectionKey: _keyCuartos,
                ),
                SectionTab(
                  label: 'SEMIS',
                  color: _P.green,
                  bgColor: _P.greenLight,
                  sectionKey: _keySemis,
                ),
                SectionTab(
                  label: 'FINAL',
                  color: _P.amber,
                  bgColor: _P.amberLight,
                  sectionKey: _keyFinal,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Lista de partidos (compartida entre A y B) ───────────────────────────

  Widget _buildListaPartidos({
    List<Cruce> previos = const [],
    required List<Cruce> cuartos,
    required List<Cruce> semis,
    required List<Cruce> finalC,
  }) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PREVIOS (solo Liguilla B puede tenerlos)
          if (previos.isNotEmpty) ...[
            SizedBox(key: _keyPrevio),
            _buildRondaHeader(
              titulo: 'Octavos de final',
              badge: '${previos.length} cruces',
              badgeColor: const Color(0xFF8B5CF6),
              badgeBg: const Color(0xFFF3EEFF),
              barColor: const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 10),
            ...previos.map((c) => _buildCruceCard(c, 'Octavos')),
          ],

          // CUARTOS
          if (cuartos.isNotEmpty) ...[
            if (previos.isNotEmpty)
              _buildConnector('ganadores avanzan a cuartos de final'),
            SizedBox(key: _keyCuartos),
            _buildRondaHeader(
              titulo: 'Cuartos de final',
              badge: '${cuartos.length} cruces',
              badgeColor: _P.blue,
              badgeBg: _P.blueLight,
              barColor: _P.blue,
            ),
            const SizedBox(height: 10),
            ...cuartos.map((c) => _buildCruceCard(c, 'Cuartos')),
          ],

          // SEMIS
          if (semis.isNotEmpty) ...[
            _buildConnector('ganadores avanzan a semifinales'),
            SizedBox(key: _keySemis),
            _buildRondaHeader(
              titulo: 'Semifinales',
              badge: '${semis.length} cruces',
              badgeColor: _P.green,
              badgeBg: _P.greenLight,
              barColor: _P.green,
            ),
            const SizedBox(height: 10),
            ...semis.map((c) => _buildCruceCard(c, 'Semifinal')),
          ],

          // FINAL
          if (finalC.isNotEmpty) ...[
            _buildConnector('ganadores avanzan a la final'),
            SizedBox(key: _keyFinal),
            _buildRondaHeader(
              titulo: 'Gran Final',
              badge: '🏆 Final',
              badgeColor: _P.amber,
              badgeBg: _P.amberLight,
              barColor: _P.amber,
            ),
            const SizedBox(height: 10),
            ...finalC.map((c) => _buildFinalCard(c)),
          ],
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(String liga) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.border, width: 0.5),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: _P.slate,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Liguilla $liga no iniciada',
            style: _ts(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            liga == 'A'
                ? 'Los partidos aparecerán aquí\ncuando se genere la liguilla.'
                : 'El admin debe generar la Liguilla B\ndesde el panel de administrador.',
            textAlign: TextAlign.center,
            style: _ts(size: 13, color: _P.slate, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ─── RONDA HEADER ─────────────────────────────────────────────────────────
  Widget _buildRondaHeader({
    required String titulo,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
    required Color barColor,
  }) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(titulo, style: _ts(size: 15, weight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge.toUpperCase(),
            style: _ts(
              size: 10,
              weight: FontWeight.w700,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Container(height: 0.5, color: _P.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: _ts(size: 10, color: _P.slate, weight: FontWeight.w500),
            ),
          ),
          Expanded(child: Container(height: 0.5, color: _P.border)),
        ],
      ),
    );
  }

  // ─── CRUCE CARD ───────────────────────────────────────────────────────────
  Widget _buildCruceCard(Cruce c, String rondaLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.resuelto
              ? _P.blue.withValues(alpha: 0.22)
              : c.tieneEquipos
              ? _P.amber.withValues(alpha: 0.35)
              : _P.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          _buildCruceStatusBanner(c, rondaLabel),

          // ── Marcador global ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _buildMarcadorGlobal(c),
          ),

          // ── Desglose Ida / Vuelta ────────────────────────────────────────
          if (c.tieneEquipos) ...[
            const SizedBox(height: 10),
            Divider(height: 0, thickness: 0.5, color: _P.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  _buildPartidoRow(
                    partido: c.ida,
                    label: 'IDA',
                    esIda: true,
                    cruceResuelto: c.resuelto,
                    ganadorCruceId: c.ganadorCruceId,
                    onFecha: () => _openFechaDialog(c.ida),
                    onResultado: () => _openResultDialog(c.ida, c),
                  ),
                  if (c.vuelta != null) ...[
                    const SizedBox(height: 8),
                    _buildPartidoRow(
                      partido: c.vuelta!,
                      label: 'VUELTA',
                      esIda: false,
                      cruceResuelto: c.resuelto,
                      ganadorCruceId: c.ganadorCruceId,
                      onFecha: c.idaJugada
                          ? () => _openFechaDialog(c.vuelta!)
                          : null,
                      onResultado: c.idaJugada
                          ? () => _openResultDialog(c.vuelta!, c)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Tag ganador ──────────────────────────────────────────────────
          if (c.resuelto) ...[
            Divider(height: 0, thickness: 0.5, color: _P.border),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _P.greenLight,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '✓',
                    style: TextStyle(color: _P.green, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${c.ganadorNombre} avanza',
                    style: _ts(
                      size: 11,
                      weight: FontWeight.w600,
                      color: _P.green,
                    ),
                  ),
                  if (c.vuelta?.penales == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _P.amberLight,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Penales',
                        style: _ts(
                          size: 9,
                          weight: FontWeight.w600,
                          color: _P.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── MARCADOR GLOBAL ──────────────────────────────────────────────────────
  Widget _buildMarcadorGlobal(Cruce c) {
    if (!c.tieneEquipos) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Esperando resultado de ronda anterior',
          style: _ts(size: 12, color: _P.slate),
        ),
      );
    }

    final eq1gana = c.resuelto && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = c.resuelto && c.ganadorCruceId == c.equipo2Id;
    final mostrarGoles = c.idaJugada || c.vueltaJugada;

    return Row(
      children: [
        // Equipo 1
        Expanded(
          child: Row(
            children: [
              _teamAvatar(
                c.equipo1Nombre,
                c.equipo1LogoUrl,
                isGanador: eq1gana,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  c.equipo1Nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(
                    size: 13,
                    weight: eq1gana ? FontWeight.w700 : FontWeight.w600,
                    color: eq1gana ? _P.navy : _P.slate,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Marcador global
        Container(
          width: 80,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: mostrarGoles ? _P.blueLight : _P.bg,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: mostrarGoles
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${c.golesGlobalesEq1} – ${c.golesGlobalesEq2}',
                      style: _ts(
                        size: 14,
                        weight: FontWeight.w700,
                        color: _P.blue,
                      ),
                    ),
                    Text(
                      'GLOBAL',
                      style: _ts(
                        size: 7,
                        weight: FontWeight.w700,
                        color: _P.slate,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                )
              : Text(
                  'IDA + VTA',
                  style: _ts(size: 9, weight: FontWeight.w600, color: _P.slate),
                ),
        ),

        // Equipo 2
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  c.equipo2Nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: _ts(
                    size: 13,
                    weight: eq2gana ? FontWeight.w700 : FontWeight.w600,
                    color: eq2gana ? _P.navy : _P.slate,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _teamAvatar(
                c.equipo2Nombre,
                c.equipo2LogoUrl,
                isGanador: eq2gana,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── FILA IDA / VUELTA ────────────────────────────────────────────────────
  Widget _buildPartidoRow({
    required PartidoLiguilla partido,
    required String label,
    required bool esIda,
    required bool cruceResuelto,
    required String? ganadorCruceId,
    VoidCallback? onFecha,
    VoidCallback? onResultado,
  }) {
    final disponible = onResultado != null;
    final jugado = partido.jugado;

    final localNombre = partido.equipo1Nombre;
    final visitanteNombre = partido.equipo2Nombre;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: jugado ? _P.blueLight.withOpacity(0.5) : _P.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: jugado ? _P.blue.withValues(alpha: 0.2) : _P.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Label ida/vuelta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: jugado ? _P.blue : _P.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: _ts(
                size: 9,
                weight: FontWeight.w700,
                color: jugado ? Colors.white : _P.slate,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Partido
          Expanded(
            child: jugado
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          localNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ts(size: 12, weight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _P.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${partido.golesEquipo1}–${partido.golesEquipo2}',
                          style: _ts(
                            size: 12,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          visitanteNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: _ts(size: 12, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        disponible
                            ? '$localNombre vs $visitanteNombre'
                            : (esIda
                                  ? 'Pendiente de jugar'
                                  : 'Disponible tras la ida'),
                        style: _ts(size: 12, color: _P.slate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (disponible && partido.fecha != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 10,
                              color: _P.slate,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateShort(partido.fecha!),
                              style: _ts(
                                size: 10,
                                color: _P.slate,
                                weight: FontWeight.w500,
                              ),
                            ),
                            if (partido.hora != null)
                              Text(
                                '  ·  ${partido.hora}',
                                style: _ts(
                                  size: 10,
                                  color: _P.slate,
                                  weight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),

          // Botones acción
          const SizedBox(width: 8),
          if (disponible) ...[
            if (onFecha != null)
              _smallBtn(
                icon: Icons.schedule_rounded,
                color: _P.slate,
                onTap: onFecha,
              ),
            const SizedBox(width: 6),
            _smallBtn(
              icon: jugado
                  ? Icons.edit_rounded
                  : Icons.add_circle_outline_rounded,
              color: jugado ? _P.blue : _P.green,
              onTap: onResultado,
            ),
          ] else
            const SizedBox(width: 58),
        ],
      ),
    );
  }

  Widget _smallBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  // ─── STATUS BANNER ────────────────────────────────────────────────────────
  Widget _buildCruceStatusBanner(Cruce c, String rondaLabel) {
    final Color dotColor;
    final Color textColor;
    final Color bgColor;
    final String label;

    if (c.resuelto) {
      dotColor = _P.green;
      textColor = _P.green;
      bgColor = _P.greenLight;
      label = 'RESUELTO · $rondaLabel ${c.orden}';
    } else if (c.tieneEquipos && (c.idaJugada || c.vueltaJugada)) {
      dotColor = _P.amber;
      textColor = _P.amber;
      bgColor = _P.amberLight;
      final jugados = (c.idaJugada ? 1 : 0) + (c.vueltaJugada ? 1 : 0);
      label = 'EN CURSO $jugados/2 · $rondaLabel ${c.orden}';
    } else if (c.tieneEquipos) {
      dotColor = _P.slate;
      textColor = _P.slate;
      bgColor = _P.bg;
      label = 'PENDIENTE · $rondaLabel ${c.orden}';
    } else {
      dotColor = _P.border;
      textColor = _P.slate;
      bgColor = _P.bg;
      label = 'EN ESPERA · $rondaLabel ${c.orden}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13.5)),
        border: Border(bottom: BorderSide(color: _P.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: _ts(
              size: 10,
              weight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FINAL CARD ───────────────────────────────────────────────────────────
  Widget _buildFinalCard(Cruce c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF111D2B)],
        ),
        boxShadow: [
          BoxShadow(
            color: _P.blue.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4A7FA5), width: 1),
                ),
                child: Text(
                  'GRAN FINAL',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7AAECB),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              if (c.tieneEquipos) ...[
                _heroBtn(
                  label: c.ida.fecha != null ? 'Fecha →' : '+ Fecha (I)',
                  onTap: () => _openFechaDialog(c.ida),
                ),
                if (c.idaJugada && c.vuelta != null) ...[
                  const SizedBox(width: 6),
                  _heroBtn(
                    label: c.vuelta!.fecha != null ? 'Fecha →' : '+ Fecha (V)',
                    onTap: () => _openFechaDialog(c.vuelta!),
                  ),
                ],
              ],
            ],
          ),

          const SizedBox(height: 16),

          if (!c.tieneEquipos) ...[
            Text(
              'Esperando semifinales',
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Los finalistas se definirán cuando terminen las semis',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFF7AAECB),
              ),
            ),
          ] else if (c.resuelto) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.equipo1Nombre} vs ${c.equipo2Nombre}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            'Campeón: ${c.ganadorNombre}',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _P.amber,
                            ),
                          ),
                        ],
                      ),
                      if (c.vuelta?.penales == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Definido en penales',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: const Color(0xFF7AAECB),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    Text(
                      '${c.golesGlobalesEq1}–${c.golesGlobalesEq2}',
                      style: GoogleFonts.dmSans(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      'global',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF7AAECB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.equipo1Nombre} vs ${c.equipo2Nombre}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Partido decisivo de la temporada',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF7AAECB),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'I+V',
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.2),
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ],

          // Desglose partidos
          if (c.tieneEquipos) ...[
            const SizedBox(height: 14),
            Divider(
              height: 0,
              thickness: 0.5,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 12),
            _buildPartidoRow(
              partido: c.ida,
              label: 'IDA',
              esIda: true,
              cruceResuelto: c.resuelto,
              ganadorCruceId: c.ganadorCruceId,
              onFecha: () => _openFechaDialog(c.ida),
              onResultado: () => _openResultDialog(c.ida, c),
            ),
            if (c.vuelta != null) ...[
              const SizedBox(height: 8),
              _buildPartidoRow(
                partido: c.vuelta!,
                label: 'VUELTA',
                esIda: false,
                cruceResuelto: c.resuelto,
                ganadorCruceId: c.ganadorCruceId,
                onFecha: c.idaJugada ? () => _openFechaDialog(c.vuelta!) : null,
                onResultado: c.idaJugada
                    ? () => _openResultDialog(c.vuelta!, c)
                    : null,
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── DIALOG: FECHA Y HORA ─────────────────────────────────────────────────
  Future<void> _openFechaDialog(PartidoLiguilla p) async {
    DateTime? selectedDate = p.fecha;
    TimeOfDay? selectedTime = p.hora != null ? _parseHora(p.hora!) : null;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: _P.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _P.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
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
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: _P.blue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha y hora',
                            style: _ts(size: 15, weight: FontWeight.w700),
                          ),
                          Text(
                            '${_rondaNombre(p.ronda)} ${p.orden} · ${p.numeroPartido == 1 ? "Ida" : "Vuelta"}',
                            style: _ts(size: 11, color: _P.slate),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          color: _P.slate,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0, thickness: 0.5, color: _P.border),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                child: Column(
                  children: [
                    // Selector fecha
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          locale: const Locale('es'),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _P.blue,
                                onPrimary: Colors.white,
                                surface: _P.surface,
                                onSurface: _P.navy,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setS(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _P.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedDate != null
                                ? _P.blue.withValues(alpha: 0.4)
                                : _P.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selectedDate != null
                                    ? _P.blueLight
                                    : _P.bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: selectedDate != null
                                    ? _P.blue
                                    : _P.slate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha del partido',
                                    style: _ts(
                                      size: 11,
                                      color: _P.slate,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedDate != null
                                        ? _formatDate(selectedDate!)
                                        : 'Seleccionar fecha',
                                    style: _ts(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: selectedDate != null
                                          ? _P.navy
                                          : _P.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _P.slate,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Selector hora
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _P.blue,
                                onPrimary: Colors.white,
                                surface: _P.surface,
                                onSurface: _P.navy,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setS(() => selectedTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _P.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedTime != null
                                ? _P.blue.withValues(alpha: 0.4)
                                : _P.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selectedTime != null
                                    ? _P.blueLight
                                    : _P.bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: selectedTime != null
                                    ? _P.blue
                                    : _P.slate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hora del partido',
                                    style: _ts(
                                      size: 11,
                                      color: _P.slate,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedTime != null
                                        ? _formatTime(selectedTime!)
                                        : 'Seleccionar hora',
                                    style: _ts(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: selectedTime != null
                                          ? _P.navy
                                          : _P.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _P.slate,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),

              const Divider(height: 0, thickness: 0.5, color: _P.border),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: _dialogBtn(
                        label: 'Cancelar',
                        filled: false,
                        loading: false,
                        onTap: isSaving ? null : () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dialogBtn(
                        label: 'Guardar',
                        filled: true,
                        loading: isSaving,
                        onTap: isSaving
                            ? null
                            : () async {
                                setS(() => isSaving = true);
                                try {
                                  final horaStr = selectedTime != null
                                      ? _formatTime(selectedTime!)
                                      : null;
                                  await _service
                                      .actualizarFechaHoraPartidoLiguilla(
                                        partidoId: p.id,
                                        fecha: selectedDate,
                                        hora: horaStr,
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  // Recarga la liguilla activa
                                  _service.liguillaActiva.value == 'A'
                                      ? _loadPartidos()
                                      : _loadPartidosB();
                                  _showSnack('Fecha actualizada');
                                } catch (e) {
                                  setS(() => isSaving = false);
                                  _showSnack('Error: $e', isError: true);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── DIALOG: RESULTADO ────────────────────────────────────────────────────
  Future<void> _openResultDialog(PartidoLiguilla p, Cruce cruce) async {
    final ctrl1 = TextEditingController(
      text: p.jugado ? '${p.golesEquipo1}' : '',
    );
    final ctrl2 = TextEditingController(
      text: p.jugado ? '${p.golesEquipo2}' : '',
    );
    bool isSaving = false;
    final esVuelta = p.esVuelta;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final g1 = int.tryParse(ctrl1.text) ?? -1;
          final g2 = int.tryParse(ctrl2.text) ?? -1;
          final ambos = g1 >= 0 && g2 >= 0;

          int? totalEq1, totalEq2;
          bool empateGlobal = false;
          if (esVuelta && ambos && cruce.idaJugada) {
            final golesVueltaEq1Cruce = g2;
            final golesVueltaEq2Cruce = g1;
            totalEq1 = (cruce.ida.golesEquipo1 ?? 0) + golesVueltaEq1Cruce;
            totalEq2 = (cruce.ida.golesEquipo2 ?? 0) + golesVueltaEq2Cruce;
            empateGlobal = totalEq1 == totalEq2;
          }

          return Dialog(
            backgroundColor: _P.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _P.border, width: 0.5),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
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
                          child: const Icon(
                            Icons.sports_soccer_rounded,
                            color: _P.blue,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.jugado
                                    ? 'Editar resultado'
                                    : 'Registrar resultado',
                                style: _ts(size: 15, weight: FontWeight.w700),
                              ),
                              Text(
                                '${_rondaNombre(p.ronda)} ${p.orden} · ${esVuelta ? "Vuelta" : "Ida"}',
                                style: _ts(
                                  size: 11,
                                  color: _P.slate,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final foco = FocusManager.instance.primaryFocus;
                            if (foco != null) {
                              foco.unfocus();
                              await Future.delayed(
                                const Duration(milliseconds: 300),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              color: _P.slate,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0, thickness: 0.5, color: _P.border),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                    child: Column(
                      children: [
                        // Info ida (solo vuelta)
                        if (esVuelta && cruce.idaJugada) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _P.blueLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _P.blue.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 13,
                                  color: _P.blue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ida: ${cruce.equipo1Nombre} ${cruce.ida.golesEquipo1}–${cruce.ida.golesEquipo2} ${cruce.equipo2Nombre}',
                                  style: _ts(
                                    size: 11,
                                    color: _P.blue,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Inputs goles
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _teamAvatar(
                                    p.equipo1Nombre,
                                    p.equipo1LogoUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.equipo1Nombre,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _ts(
                                      size: 11,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'LOCAL',
                                    style: _ts(
                                      size: 8,
                                      color: _P.slate,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  _goalInput(ctrl1, () => setS(() {})),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      '–',
                                      style: _ts(
                                        size: 22,
                                        weight: FontWeight.w700,
                                        color: _P.slate,
                                      ),
                                    ),
                                  ),
                                  _goalInput(ctrl2, () => setS(() {})),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  _teamAvatar(
                                    p.equipo2Nombre,
                                    p.equipo2LogoUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.equipo2Nombre,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _ts(
                                      size: 11,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'VISITANTE',
                                    style: _ts(
                                      size: 8,
                                      color: _P.slate,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Preview marcador global
                        if (esVuelta &&
                            ambos &&
                            cruce.idaJugada &&
                            totalEq1 != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: empateGlobal
                                  ? _P.amberLight
                                  : _P.greenLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: empateGlobal
                                    ? _P.amber.withValues(alpha: 0.3)
                                    : _P.green.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'MARCADOR GLOBAL',
                                  style: _ts(
                                    size: 9,
                                    weight: FontWeight.w700,
                                    color: empateGlobal ? _P.amber : _P.green,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${cruce.equipo1Nombre} $totalEq1 – $totalEq2 ${cruce.equipo2Nombre}',
                                  style: _ts(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: empateGlobal ? _P.amber : _P.green,
                                  ),
                                ),
                                if (empateGlobal) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Empate global — avanza el mejor posicionado en liga',
                                    textAlign: TextAlign.center,
                                    style: _ts(size: 10, color: _P.amber),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  const Divider(height: 0, thickness: 0.5, color: _P.border),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _dialogBtn(
                            label: 'Cancelar',
                            filled: false,
                            loading: false,
                            onTap: isSaving
                                ? null
                                : () async {
                                    final foco =
                                        FocusManager.instance.primaryFocus;
                                    if (foco != null) {
                                      foco.unfocus();
                                      await Future.delayed(
                                        const Duration(milliseconds: 300),
                                      );
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dialogBtn(
                            label: 'Guardar',
                            filled: true,
                            loading: isSaving,
                            onTap: isSaving
                                ? null
                                : () async {
                                    final foco =
                                        FocusManager.instance.primaryFocus;
                                    if (foco != null) {
                                      foco.unfocus();
                                      await Future.delayed(
                                        const Duration(milliseconds: 300),
                                      );
                                    }
                                    final g1v = int.tryParse(ctrl1.text);
                                    final g2v = int.tryParse(ctrl2.text);
                                    if (g1v == null || g2v == null) {
                                      _showSnack(
                                        'Ingresa los goles de ambos equipos',
                                        isError: true,
                                      );
                                      return;
                                    }
                                    setS(() => isSaving = true);
                                    try {
                                      await _service.registrarResultadoLiguilla(
                                        partidoId: p.id,
                                        golesEquipo1: g1v,
                                        golesEquipo2: g2v,
                                        penales: false,
                                        ganadorPenalesId: null,
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      // Recarga la liguilla activa
                                      _service.liguillaActiva.value == 'A'
                                          ? _loadPartidos()
                                          : _loadPartidosB();
                                      _showSnack(
                                        esVuelta && cruce.idaJugada
                                            ? 'Cruce resuelto ✓'
                                            : 'Resultado guardado',
                                      );
                                    } catch (e) {
                                      setS(() => isSaving = false);
                                      _showSnack('Error: $e', isError: true);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Future.delayed(Duration.zero);
    if (mounted) {
      ctrl1.dispose();
      ctrl2.dispose();
    }
  }

  // ─── HELPERS DE WIDGET ────────────────────────────────────────────────────
  Widget _teamAvatar(
    String nombre,
    String logoUrl, {
    bool isGanador = false,
    double size = 32,
  }) {
    if (logoUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isGanador ? _P.green.withValues(alpha: 0.5) : _P.border,
            width: isGanador ? 1.5 : 0.5,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: logoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => _avatarFallback(nombre, size, isGanador),
            errorWidget: (_, __, ___) =>
                _avatarFallback(nombre, size, isGanador),
          ),
        ),
      );
    }
    return _avatarFallback(nombre, size, isGanador);
  }

  Widget _avatarFallback(String nombre, double size, bool isGanador) {
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isGanador ? _P.greenLight : _P.blueLight,
        shape: BoxShape.circle,
        border: Border.all(
          color: isGanador
              ? _P.green.withValues(alpha: 0.4)
              : _P.blue.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: _ts(
          size: size * 0.38,
          weight: FontWeight.w700,
          color: isGanador ? _P.green : _P.blue,
        ),
      ),
    );
  }

  Widget _goalInput(TextEditingController ctrl, VoidCallback onChange) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => onChange(),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: _ts(size: 22, weight: FontWeight.w800),
        maxLength: 2,
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _heroBtn({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7AAECB),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogBtn({
    required String label,
    required bool filled,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: filled ? _P.blue : _P.bg,
            borderRadius: BorderRadius.circular(10),
            border: filled ? null : Border.all(color: _P.border, width: 0.5),
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: filled ? Colors.white : _P.blue,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: _ts(
                    size: 13,
                    weight: FontWeight.w600,
                    color: filled ? Colors.white : _P.slate,
                  ),
                ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _ts(color: Colors.white, size: 13)),
        backgroundColor: isError ? _P.red : _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── HELPERS DE FORMATO ───────────────────────────────────────────────────
  String _rondaNombre(String ronda) {
    switch (ronda) {
      case 'previo':
        return 'Octavos';
      case 'cuartos':
        return 'Cuartos';
      case 'semis':
        return 'Semifinal';
      case 'final':
        return 'Final';
      default:
        return ronda;
    }
  }

  String _formatDate(DateTime d) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
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
    return '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m hrs';
  }

  TimeOfDay? _parseHora(String hora) {
    try {
      final clean = hora.replaceAll('hrs', '').trim();
      final parts = clean.split(':');
      if (parts.length != 2) return null;
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatDateShort(DateTime d) {
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
    return '${d.day} ${meses[d.month - 1]}';
  }
}
