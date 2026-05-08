import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../models/equipo_model.dart';
import '../models/jugador_model.dart';
import '../models/partido_model.dart';
import '../models/jornada_model.dart';
import '../models/temporada_model.dart';
import 'package:google_fonts/google_fonts.dart'; // ← agrega este import arriba
import '../widgets/app_drawer.dart';
import 'liguilla_home_screen.dart';

// ─── PALETA ────────────────────────────────────────────────────────────────────
// Fiel al mockup compartido
// #F0F2F5  Cloud Gray    — fondo base de la pantalla
// #FFFFFF  Pure White    — cards y superficies
// #E8EAF0  Border Gray   — bordes y separadores
// #9A9FBA  Slate         — texto secundario / labels / íconos inactivos
// #1A1A2E  Deep Navy     — texto principal / títulos
// #3A6FD8  Royal Blue    — acento principal / pills / pts / botones
// #EAF1FF  Blue Light    — fondos de pills y badges azules
// #27AE60  Stadium Green — goles totales / positivo
// #E6F9F2  Green Light   — fondo badge verde
// #E74C3C  Goal Red      — goleadores / alertas
// #FEF0ED  Red Light     — fondo badge rojo
// #1E3050  Hero Dark     — solo la tarjeta del último partido
// ───────────────────────────────────────────────────────────────────────────────

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
  static const heroDark = Color(0xFF1E3050);
  static const heroText = Color(0xFF6A8FAF);
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

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToMatchdays;
  final Function(bool showStandings)? onGoToTables;
  final VoidCallback? onOpenDrawer;

  const HomeScreen({
    super.key,
    this.onGoToMatchdays,
    this.onGoToTables,
    this.onOpenDrawer,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Partido? _proximoPartido;
  int? _proximoJornadaNumero;
  bool _isLoading = true;
  Jornada? _ultimaJornada;
  List<Partido> _partidos = [];
  List<Equipo> _topTeams = [];
  List<Jugador> _topScorers = [];
  int? _selectedIndex;

  final FirestoreService _service = FirestoreService();
  Timer? _debounce;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _initData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fadeCtrl.dispose();
    _service.currentSeasonId.removeListener(_onSeasonChanged);
    super.dispose();
  }

  Future<void> _initData() async {
    _service.currentSeasonId.addListener(_onSeasonChanged);
    await _service.loadSeasons();
    if (_service.currentSeasonId.value != null) {
      await _loadData();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSeasonChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _loadData);
  }

  Future<void> _loadData() async {
    if (_service.currentSeasonId.value == null) return;
    if (mounted) setState(() => _isLoading = true);
    _fadeCtrl.reset();
    try {
      final results = await Future.wait([
        _service.loadHomeData(),
        _service.getProximoPartido(),
      ]);

      final data =
          results[0]
              as ({
                Jornada? ultimaJornada,
                List<Partido> partidos,
                List<Equipo> topTeams,
                List<Jugador> topScorers,
              });

      final proximo = results[1] as ({Partido? partido, int? jornadaNumero});

      if (mounted) {
        setState(() {
          _ultimaJornada = data.ultimaJornada;
          _partidos = data.partidos;
          _topTeams = data.topTeams;
          _topScorers = data.topScorers;
          _proximoPartido = proximo.partido;
          _proximoJornadaNumero = proximo.jornadaNumero;
          _isLoading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('❌ Home error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _service.faseVista,
      builder: (context, fase, _) {
        final temporada = _service.currentSeason;
        final esLiguilla =
            temporada?.faseActual == 'liguilla' && fase == 'liguilla';

        if (esLiguilla) {
          return LiguillaHomeScreen(
            onGoToMatchdays: widget.onGoToMatchdays,
            onGoToTables: widget.onGoToTables,
          );
        }
        return Scaffold(
          backgroundColor: _P.bg,
          body: SafeArea(
            child: RefreshIndicator(
              color: _P.blue,
              backgroundColor: _P.surface,
              onRefresh: () async {
                _service.setSeason(_service.currentSeasonId.value!);
                await _loadData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    if (_isLoading)
                      SizedBox(
                        height: 320,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _P.blue,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else
                      FadeTransition(
                        opacity: _fadeCtrl,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero: último partido
                              if (_ultimaJornada != null &&
                                  _partidos.isNotEmpty) ...[
                                _buildHeroCard(),
                                const SizedBox(height: 20),
                              ],

                              // En el build, entre _buildHeroCard() y _buildSectionHeader('Última jornada'):
                              if (_ultimaJornada != null ||
                                  _topTeams.isNotEmpty) ...[
                                _buildSeasonStatsRow(),
                                const SizedBox(height: 20),
                              ],

                              // Últimos resultados
                              if (_partidos.isNotEmpty) ...[
                                _buildSectionHeader(
                                  'Última jornada',
                                  trailing: _ultimaJornada != null
                                      ? 'Jornada ${_ultimaJornada!.numero}'
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                _buildMatchesCard(),
                                const SizedBox(height: 22),
                              ],
                              // Próximo partido
                              if (_proximoPartido != null) ...[
                                _buildSectionHeader('Próximo partido'),
                                const SizedBox(height: 10),
                                _buildProximoPartidoCard(
                                  _proximoPartido!,
                                  _proximoJornadaNumero,
                                ),
                                const SizedBox(height: 22),
                              ],
                              // Líderes
                              if (_topTeams.isNotEmpty) ...[
                                _buildSectionHeader(
                                  'Líderes',
                                  onTrailingTap: () {
                                    widget.onGoToTables?.call(
                                      true,
                                    ); // 👈 tabla general
                                  },
                                ),
                                const SizedBox(height: 10),
                                _buildRankCard(
                                  items: _topTeams
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => _RankItem(
                                          pos: e.key + 1,
                                          name: e.value.nombre,
                                          value: '${e.value.pts} pts',
                                          logoUrl: e.value.logoUrl.isNotEmpty
                                              ? e.value.logoUrl
                                              : null,
                                          teamColor: _colorFromHex(
                                            e.value.color,
                                          ),
                                          valueBg: _P.blueLight,
                                          valueColor: _P.blue,
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 22),
                              ],

                              // Goleadores
                              if (_topScorers.isNotEmpty) ...[
                                _buildSectionHeader(
                                  'Goleadores',
                                  onTrailingTap: () {
                                    widget.onGoToTables?.call(false); // 👈 AQUÍ
                                  },
                                ),
                                const SizedBox(height: 10),
                                _buildRankCard(
                                  items: _topScorers
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => _RankItem(
                                          pos: e.key + 1,
                                          name: e.value.nombre,
                                          value: '${e.value.goles} goles',
                                          photoUrl: e.value.fotoUrl,
                                          valueBg: _P.redLight,
                                          valueColor: _P.red,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],

                              // Empty state
                              if (_ultimaJornada == null &&
                                  _topTeams.isEmpty &&
                                  _topScorers.isEmpty)
                                _buildEmptyState(),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaseSelector() {
    return ValueListenableBuilder<String?>(
      valueListenable: _service.currentSeasonId,
      builder: (ctx, _, __) {
        final temporada = _service.currentSeason;
        if (temporada?.faseActual != 'liguilla') return const SizedBox.shrink();

        return ValueListenableBuilder<String>(
          valueListenable: _service.faseVista,
          builder: (ctx, fase, _) {
            return Container(
              color: _P.surface,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                height: 36,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _P.blueLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _P.blue.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: _fasePill('Liga', fase == 'liga', () {
                        _service.faseVista.value = 'liga';
                        _loadData();
                      }),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: _fasePill('Liguilla', fase == 'liguilla', () {
                        _service.faseVista.value = 'liguilla';
                        _loadData();
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _fasePill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _P.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: _ts(
            size: 11,
            weight: FontWeight.w600,
            color: active ? Colors.white : _P.blue,
          ),
        ),
      ),
    );
  }
  // ─── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          color: _P.surface,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              // Botón menú hamburguesa
              GestureDetector(
                onTap: widget.onOpenDrawer,
                child: Container(
                  width: 20,
                  height: 20,
                  child: const Icon(
                    Icons.menu_rounded,
                    color: _P.navy,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Logo + título
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _P.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _P.border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/images/logo_p.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CERRITO',
                      style: _ts(
                        size: 20,
                        weight: FontWeight.w800,
                        letterSpacing: 1.8,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Liga de fútbol',
                      style: _ts(
                        size: 11,
                        color: _P.slate,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Selector de temporada
              _buildSeasonSelector(),
            ],
          ),
        ),
        // Selector Liga / Liguilla — debajo del header, solo si aplica
        _buildFaseSelector(),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    return ValueListenableBuilder<List<Temporada>>(
      valueListenable: _service.seasons,
      builder: (ctx, seasonsList, _) {
        if (seasonsList.isEmpty) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _P.blue,
                ),
              ),
            ],
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: _service.currentSeasonId,
          builder: (ctx, seasonId, _) {
            String validId = seasonId ?? seasonsList.first.id;
            if (!seasonsList.any((s) => s.id == validId)) {
              validId = seasonsList.first.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _service.setSeason(validId);
              });
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _P.blueLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _P.blue.withOpacity(0.25),
                      width: 0.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: validId,
                      dropdownColor: _P.surface,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _P.blue,
                        size: 16,
                      ),
                      isDense: true,
                      style: _ts(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _P.blue,
                      ),
                      items: seasonsList
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) _service.setSeason(val);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── HERO CARD (último partido destacado) ──────────────────────────────────

  // ─── COLORES HERO ACTUALIZADOS ─────────────────────────────────────────────
  // Reemplaza las constantes hero en _P:
  //   static const heroDark  = Color(0xFF1A2B3E);  // azul marino más oscuro
  //   static const heroTag   = Color(0xFF4A7FA5);  // azul medio para tag/fecha
  //   static const heroScore = Color(0xFFFFFFFF);  // blanco puro para el score

  Widget _buildHeroCard() {
    final partido = _partidos.first;
    final totalGoles =
        (partido.golesEquipo1 ?? 0) + (partido.golesEquipo2 ?? 0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF111D2B)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3A6FD8).withOpacity(0.22),
            blurRadius: 18,
            spreadRadius: -2,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4A7FA5), width: 1),
            ),
            child: Text(
              'ÚLTIMO PARTIDO',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7AAECB),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fila: info izquierda + marcador derecha
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Columna izquierda
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${partido.equipo1Nombre} vs ${partido.equipo2Nombre}',
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
                      _buildFechaJornada(partido),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF7AAECB),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Marcador
              if (partido.tieneResultado)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${partido.golesEquipo1}–${partido.golesEquipo2}',
                      style: GoogleFonts.dmSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalGoles goles',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF7AAECB),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Fila inferior: penales + botón
          Row(
            children: [
              if (partido.penales)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Definido en penales',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber,
                    ),
                  ),
                ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onGoToMatchdays,
                  borderRadius: BorderRadius.circular(10),
                  splashColor: _P.blue.withOpacity(0.2),
                  highlightColor: _P.blue.withOpacity(0.1),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF3A6080),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Text(
                        'Ver jornada completa →',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF7AAECB),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonStatsRow() {
    final temporada = _service.currentSeason;
    final jornadas = temporada?.totalJornadas ?? _ultimaJornada?.numero ?? 0;
    final totalGoles = temporada?.totalGoles ?? 0;
    final totalPartidos = temporada?.totalPartidos ?? 0;
    final lider = _topTeams.isNotEmpty ? _topTeams.first : null;

    final promedio = jornadas > 0
        ? (totalGoles / jornadas).toStringAsFixed(1)
        : '—';

    return Row(
      children: [
        Expanded(
          child: _buildStatCardAnimated(
            index: 0,
            label: 'Jornadas',
            value: '$jornadas',
            sub: totalPartidos > 0 ? '$totalPartidos partidos' : ' ',
            subColor: _P.slate,
            subBg: _P.bg,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCardAnimated(
            index: 1,
            label: 'Goles totales',
            value: '$totalGoles',
            valueColor: _P.green,
            sub: jornadas > 0 ? '$promedio x jornada' : ' ',
            subColor: _P.green,
            subBg: _P.greenLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCardAnimated(
            index: 2,
            label: 'Líder actual',
            value: lider?.nombre ?? '—',
            valueFontSize: lider != null && lider.nombre.length > 7 ? 15 : 18,
            sub: lider != null ? '${lider.pts} pts' : ' ',
            subColor: _P.blue,
            subBg: _P.blueLight,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    double? valueFontSize,
    Color valueColor = _P.navy,
    String? sub,
    Color subColor = _P.blue,
    Color? subBg,
  }) {
    return Container(
      height: 100, // 🔥 clave para que todas midan lo mismo
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // 🔥 distribuye parejo
        children: [
          Text(label, style: _ts(size: 11, color: _P.slate, height: 1.35)),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _ts(
              size: valueFontSize ?? 20,
              weight: FontWeight.w700,
              color: valueColor,
              height: 1.1,
            ),
          ),

          // 🔥 SIEMPRE ocupa espacio aunque esté vacío
          Container(
            height: 18,
            alignment: Alignment.centerLeft,
            child: sub != null && sub.trim().isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: subBg ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sub,
                      style: _ts(
                        size: 10,
                        weight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardAnimated({
    required int index,
    required String label,
    required String value,
    double? valueFontSize,
    Color valueColor = _P.navy,
    String? sub,
    Color subColor = _P.blue,
    Color? subBg,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          // toggle (puedes quitar esto si quieres que siempre haya uno activo)
          _selectedIndex = _selectedIndex == index ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, isSelected ? -6.0 : 0.0)
          ..scale(isSelected ? 1.03 : 1.0),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _P.border, // 🔥 siempre gris
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _P.blue.withOpacity(isSelected ? 0.25 : 0.05),
              blurRadius: isSelected ? 14 : 6,
              offset: Offset(0, isSelected ? 8 : 2),
            ),
          ],
        ),
        child: _statCard(
          label: label,
          value: value,
          valueFontSize: valueFontSize,
          valueColor: valueColor,
          sub: sub,
          subColor: subColor,
          subBg: subBg,
        ),
      ),
    );
  }

  // ─── HELPER: construye el texto de jornada + fecha ─────────────────────────
  // Agrégalo también en _HomeScreenState
  String _buildFechaJornada(Partido p) {
    final jornada = 'Jornada ${_ultimaJornada!.numero}';
    if (p.fecha == null) return jornada;

    // Formato: "Sáb 5 Abr"
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
    final d = p.fecha!;
    final dia = dias[d.weekday - 1];
    final mes = meses[d.month - 1];
    return '$jornada · $dia ${d.day} $mes';
  }

  // ─── SECTION HEADER ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    String title, {
    String? trailing,
    VoidCallback? onTrailingTap,
  }) {
    final showButton = onTrailingTap != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (trailing != null && !showButton)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: _ts(size: 16, weight: FontWeight.w700),
                ),
                const WidgetSpan(child: SizedBox(width: 8)),
                TextSpan(
                  text: trailing,
                  style: _ts(
                    size: 12,
                    color: _P.slate,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          Text(title, style: _ts(size: 16, weight: FontWeight.w700)),

        // 👉 Empuja SOLO cuando hay botón
        if (showButton) const Spacer(),

        // 👉 CASO 2: botón a la derecha
        if (showButton)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(8),
              splashColor: _P.blue.withOpacity(0.15),
              highlightColor: _P.blue.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'Ver todos →',
                  style: _ts(size: 13, weight: FontWeight.w600, color: _P.blue),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── MATCHES CARD ──────────────────────────────────────────────────────────

  Widget _buildMatchesCard() {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        children: _partidos.asMap().entries.map((e) {
          final isLast = e.key == _partidos.length - 1;
          return Column(
            children: [
              _buildMatchRow(e.value),
              if (!isLast)
                Divider(
                  height: 0,
                  thickness: 0.5,
                  color: _P.border,
                  indent: 14,
                  endIndent: 14,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMatchRow(Partido p) {
    final score = p.tieneResultado
        ? '${p.golesEquipo1} – ${p.golesEquipo2}'
        : 'VS';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // Equipo local
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    p.equipo1Nombre,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(size: 13, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                _miniLogo(p.equipo1LogoUrl),
              ],
            ),
          ),

          // Marcador pill
          Container(
            width: 66,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: p.tieneResultado ? _P.blueLight : _P.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              score,
              style: _ts(
                size: 13,
                weight: FontWeight.w700,
                color: p.tieneResultado ? _P.blue : _P.slate,
              ),
            ),
          ),

          // Equipo visitante
          Expanded(
            child: Row(
              children: [
                _miniLogo(p.equipo2LogoUrl),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    p.equipo2Nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(size: 13, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── RANK CARD ─────────────────────────────────────────────────────────────

  Widget _buildRankCard({required List<_RankItem> items}) {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              _buildRankRow(e.value),
              if (!isLast)
                Divider(
                  height: 0,
                  thickness: 0.5,
                  color: _P.border,
                  indent: 14,
                  endIndent: 14,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankRow(_RankItem item) {
    final isTop = item.pos == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // Número de posición
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop ? item.valueBg : _P.bg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${item.pos}',
              style: _ts(
                size: 12,
                weight: FontWeight.w700,
                color: isTop ? item.valueColor : _P.slate,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Logo o foto
          if (item.logoUrl != null || item.teamColor != null)
            _miniLogoOrDot(item.logoUrl, item.teamColor)
          else if (item.photoUrl != null)
            _miniPhoto(item.photoUrl)
          else
            _miniLogo(null),
          const SizedBox(width: 10),

          // Nombre
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ts(size: 14, weight: FontWeight.w500),
            ),
          ),

          // Badge valor
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: item.valueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.value,
              style: _ts(
                size: 12,
                weight: FontWeight.w700,
                color: item.valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
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
                Icons.sports_soccer_outlined,
                color: _P.slate,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Sin datos en esta temporada',
              style: _ts(size: 15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Los resultados aparecerán\ncuando se registren partidos.',
              textAlign: TextAlign.center,
              style: _ts(size: 13, color: _P.slate, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS DE IMAGEN ─────────────────────────────────────────────────────

  /// Logo de equipo desde URL (círculo con borde)
  Widget _miniLogo(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _P.bg,
          shape: BoxShape.circle,
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: const Icon(Icons.shield_outlined, color: _P.slate, size: 14),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
          child: const Icon(Icons.shield_outlined, color: _P.slate, size: 14),
        ),
      ),
    );
  }

  /// Si hay logoUrl lo usa, si no pinta un dot del color del equipo
  Widget _miniLogoOrDot(String? logoUrl, Color? teamColor) {
    if (logoUrl != null && logoUrl.isNotEmpty) return _miniLogo(logoUrl);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: teamColor ?? _P.slate,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Foto de jugador goleador
  Widget _miniPhoto(String? url) {
    if (url == null || url.isEmpty) return _miniLogo(null);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        ),
        errorWidget: (_, __, ___) => _miniLogo(null),
      ),
    );
  }

  // ─── PRÓXIMO PARTIDO ──────────────────────────────────────────────────────

  Widget _buildProximoPartidoCard(Partido p, int? jornadaNumero) {
    final fecha = p.fecha!;

    const mesesAbrev = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];

    final diaStr = fecha.day.toString();
    final mesStr = mesesAbrev[fecha.month - 1];
    final horaStr = p.hora ?? '';
    final jornadaStr = jornadaNumero != null ? 'Jornada $jornadaNumero' : '';
    final subtitulo = [
      jornadaStr,
      if (horaStr.isNotEmpty) '$horaStr hrs',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Badge fecha
            Container(
              width: 48,
              height: 52,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(58, 111, 216, 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    diaStr,
                    style: _ts(
                      size: 20,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    mesStr,
                    style: _ts(
                      size: 10,
                      weight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.equipo1Nombre} vs ${p.equipo2Nombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitulo, style: _ts(size: 12, color: _P.slate)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UTIL ──────────────────────────────────────────────────────────────────

  /// Convierte "#RRGGBB" o "RRGGBB" en Color. Devuelve _P.slate si falla.
  Color _colorFromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return _P.slate;
  }
}

// ─── DATA CLASS ────────────────────────────────────────────────────────────────

class _RankItem {
  final int pos;
  final String name;
  final String value;
  final String? logoUrl;
  final String? photoUrl;
  final Color? teamColor;
  final Color valueBg;
  final Color valueColor;

  const _RankItem({
    required this.pos,
    required this.name,
    required this.value,
    this.logoUrl,
    this.photoUrl,
    this.teamColor,
    required this.valueBg,
    required this.valueColor,
  });
}
