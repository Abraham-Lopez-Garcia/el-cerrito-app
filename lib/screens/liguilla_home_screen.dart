import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/equipo_model.dart';
import '../models/partido_model.dart';
import '../models/jornada_model.dart';
import '../models/jugador_model.dart';
import '../models/liguilla_model.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/temporada_model.dart';

// ─── PALETA LIGUILLA ───────────────────────────────────────────────────────────
// Misma base que la app pero con énfasis dorado/épico para la fase final
class _P {
  static const bg = Color(0xFFF0F2F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8EAF0);
  static const slate = Color(0xFF9A9FBA);
  static const navy = Color(0xFF1A1A2E);
  static const blue = Color(0xFF3A6FD8);
  static const blueLight = Color(0xFFEAF1FF);
  static const green = Color(0xFF27AE60);
  static const red = Color(0xFFE74C3C);

  // Liguilla — azul profundo épico
  static const heroTop = Color(0xFF0D1B3E); // casi negro azulado
  static const heroMid = Color(0xFF1A2E6B); // azul royal profundo
  static const heroBot = Color(0xFF0F2347); // cierre oscuro
  static const gold = Color(0xFFFFD700); // dorado trofeo
  static const goldSoft = Color(0xFFFFAA00); // ámbar cálido
  static const goldLight = Color(0xFFFFF8E1); // fondo dorado suave
  static const silverLine = Color(0xFF3A5080); // línea/borde sobre oscuro
  static const textOnDark = Color(0xFFB8CFEE); // texto secundario sobre hero
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
class LiguillaHomeScreen extends StatefulWidget {
  final VoidCallback? onGoToMatchdays;
  final Function(bool showStandings)? onGoToTables;

  const LiguillaHomeScreen({
    super.key,
    this.onGoToMatchdays,
    this.onGoToTables,
  });

  @override
  State<LiguillaHomeScreen> createState() => _LiguillaHomeScreenState();
}

class _LiguillaHomeScreenState extends State<LiguillaHomeScreen>
    with TickerProviderStateMixin {
  // ── Datos ───────────────────────────────────────────────────────────────────
  // ── Liguilla A ──────────────────────────────────────────────────────────────
  List<Equipo> _clasificados = [];
  List<Partido> _partidos = [];
  Partido? _proximoPartido;
  int? _proximoJornadaNum;
  bool _isLoading = false;
  List<PartidoLiguilla> _partidosLiguilla = [];

  // ── Liguilla B ──────────────────────────────────────────────────────────────
  List<Equipo> _clasificadosB = [];
  bool _isLoadingB = false;
  List<PartidoLiguilla> _partidosLiguillaB = [];

  late AnimationController _bannerCtrl;
  late AnimationController _fadeBCtrl;

  final FirestoreService _service = FirestoreService();

  // ── Animaciones ─────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController
  _pulseCtrl; // pulso en el badge "EN VIVO" / "PRÓXIMO"

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🚀 LiguillaHomeScreen initState — '
      'liguillaActiva=${_service.liguillaActiva.value}',
    );

    // 1️⃣ PRIMERO: todos los controllers
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fadeBCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 2️⃣ SEGUNDO: listeners
    _service.liguillaActiva.addListener(_onLiguillaActivaChanged);
    _service.faseVista.addListener(_onFaseChanged);

    // 3️⃣ TERCERO: carga de datos
    if (_service.liguillaActiva.value == 'B') {
      debugPrint('🚀 initState → cargando B');
      _loadDataB();
    } else {
      debugPrint('🚀 initState → cargando A');
      _loadData();
    }
  }

  void _onFaseChanged() {
    if (mounted) setState(() {});
  }

  void _onLiguillaActivaChanged() {
    if (!mounted) return;
    setState(() {});
    // Siempre recargar al cambiar de liguilla, igual que matchdays
    if (_service.liguillaActiva.value == 'B') {
      _loadDataB();
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _bannerCtrl.dispose();
    _fadeBCtrl.dispose();
    _service.faseVista.removeListener(_onFaseChanged);
    _service.liguillaActiva.removeListener(_onLiguillaActivaChanged);
    super.dispose();
  }

  // ── Carga de datos ──────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    _fadeCtrl.reset();

    try {
      final results = await Future.wait([
        _service.getPartidosLiguilla(),
        _service.loadHomeData(),
        _service.getProximoPartido(),
      ]);

      final partidosLiguilla = results[0] as List<PartidoLiguilla>;
      final homeData =
          results[1]
              as ({
                Jornada? ultimaJornada,
                List<Partido> partidos,
                List<Equipo> topTeams,
                List<Jugador> topScorers,
              });
      final proximo = results[2] as ({Partido? partido, int? jornadaNumero});

      // Extraer equipos únicos de los partidos de liguilla
      final Map<String, Equipo> equiposMap = {};
      for (final p in partidosLiguilla) {
        if (p.equipo1Id != null && !equiposMap.containsKey(p.equipo1Id)) {
          equiposMap[p.equipo1Id!] = Equipo(
            id: p.equipo1Id!,
            ligaId: '',
            temporadaId: '',
            equipoBaseId: '',
            nombre: p.equipo1Nombre,
            logoUrl: p.equipo1LogoUrl,
            color: '',
          );
        }
        if (p.equipo2Id != null && !equiposMap.containsKey(p.equipo2Id)) {
          equiposMap[p.equipo2Id!] = Equipo(
            id: p.equipo2Id!,
            ligaId: '',
            temporadaId: '',
            equipoBaseId: '',
            nombre: p.equipo2Nombre,
            logoUrl: p.equipo2LogoUrl,
            color: '',
          );
        }
      }

      if (mounted) {
        setState(() {
          _clasificados = equiposMap.values.toList();
          _partidosLiguilla = partidosLiguilla;
          _partidos = homeData.partidos;
          _proximoPartido = proximo.partido;
          _proximoJornadaNum = proximo.jornadaNumero;
          _isLoading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('❌ LiguillaHome error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDataB() async {
    debugPrint('🔴 _loadDataB INICIO ABSOLUTO'); // ← primera línea
    if (!mounted) return;
    setState(() => _isLoadingB = true);
    _fadeBCtrl.reset();
    try {
      final partidos = await _service.getPartidosLiguillaB().timeout(
        const Duration(seconds: 15),
      ); // ← añadir timeout
      debugPrint('✅ _loadDataB() partidos recibidos: ${partidos.length}');
      final Map<String, Equipo> equiposMap = {};
      for (final p in partidos) {
        if (p.equipo1Id != null && !equiposMap.containsKey(p.equipo1Id)) {
          equiposMap[p.equipo1Id!] = Equipo(
            id: p.equipo1Id!,
            ligaId: '',
            temporadaId: '',
            equipoBaseId: '',
            nombre: p.equipo1Nombre,
            logoUrl: p.equipo1LogoUrl,
            color: '',
          );
        }
        if (p.equipo2Id != null && !equiposMap.containsKey(p.equipo2Id)) {
          equiposMap[p.equipo2Id!] = Equipo(
            id: p.equipo2Id!,
            ligaId: '',
            temporadaId: '',
            equipoBaseId: '',
            nombre: p.equipo2Nombre,
            logoUrl: p.equipo2LogoUrl,
            color: '',
          );
        }
      }
      if (mounted) {
        setState(() {
          _clasificadosB = equiposMap.values.toList();
          _partidosLiguillaB = partidos;
          _isLoadingB = false;
        });
        debugPrint(
          '✅ _loadDataB() estado actualizado, '
          'clasificadosB=${_clasificadosB.length} '
          'partidosB=${_partidosLiguillaB.length}',
        );
        _fadeBCtrl.forward();
      }
    } catch (e, stack) {
      debugPrint('❌ LiguillaHome B error: $e');
      debugPrint('❌ Stack: $stack'); // ← ver el error real
      if (mounted) setState(() => _isLoadingB = false);
    }
  }

  // ─── PRÓXIMO PARTIDO LIGUILLA ────────────────────────────────────────────────
  DateTime _combinarFechaHora(DateTime? fecha, String? hora) {
    if (fecha == null) return DateTime(9999); // sin fecha → va al final
    if (hora == null || hora.isEmpty) return fecha;
    try {
      // Limpia "22:00 hrs" → "22:00"
      final limpia = hora.replaceAll(RegExp(r'[^0-9:]'), '').trim();
      final partes = limpia.split(':');
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

  PartidoLiguilla? get _proximoPartidoLiguilla {
    final ahora = DateTime.now();
    final inicioDia = DateTime(ahora.year, ahora.month, ahora.day);

    final pendientes =
        _partidosActivos.where((p) => !p.jugado && p.listo).where((p) {
          final dt = _combinarFechaHora(p.fecha, p.hora);
          // Con hora: solo futuros. Sin hora: basta con que sea hoy o después
          if (p.hora != null && p.hora!.isNotEmpty) {
            return dt.isAfter(ahora);
          } else {
            return p.fecha != null && !p.fecha!.isBefore(inicioDia);
          }
        }).toList()..sort(
          (a, b) => _combinarFechaHora(
            a.fecha,
            a.hora,
          ).compareTo(_combinarFechaHora(b.fecha, b.hora)),
        );

    return pendientes.firstOrNull;
  }

  String _labelRonda(String ronda) {
    switch (ronda) {
      case 'cuartos':
        return 'Cuartos de Final';
      case 'semis':
        return 'Semifinal';
      case 'final':
        return 'Gran Final';
      default:
        return ronda;
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: RefreshIndicator(
        color: _P.gold,
        backgroundColor: _P.heroMid,
        onRefresh: () async {
          if (_esLiguillaA) {
            await _loadData();
          } else {
            await _loadDataB();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEpicHero(),
              _buildLiguillaToggle(),
              _buildLiguillaContenido(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraciasCard() {
    final hayGanador = _cruceFinal?.ganadorCruceId != null;
    if (!hayGanador) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text('⚽', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 12),
          Text(
            'Gracias por seguir la liga',
            textAlign: TextAlign.center,
            style: _ts(size: 16, weight: FontWeight.w800, color: _P.navy),
          ),
          const SizedBox(height: 8),
          Text(
            'La temporada ha concluido. Nos vemos en la siguiente, ¡hasta pronto!',
            textAlign: TextAlign.center,
            style: _ts(size: 13, color: _P.slate, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLiguillaToggle() {
    return ValueListenableBuilder<String>(
      valueListenable: _service.liguillaActiva,
      builder: (ctx, activa, _) => Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: Row(
          children: [
            _toggleLiguillaBtn(
              'A',
              'Liguilla A',
              const Color(0xFF8B5CF6),
              activa,
            ),
            _toggleLiguillaBtn('B', 'Liguilla B', _P.goldSoft, activa),
          ],
        ),
      ),
    );
  }

  Widget _buildLiguillaContenido() {
    debugPrint(
      '🏗️ _buildLiguillaContenido — '
      'liga=${_service.liguillaActiva.value} '
      'isLoadingActivo=$_isLoadingActivo '
      'clasificadosB=${_clasificadosB.length} '
      'partidosB=${_partidosLiguillaB.length}',
    );
    if (_isLoadingActivo) {
      debugPrint('🏗️ → mostrando CircularProgressIndicator');
      return SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(color: _P.gold, strokeWidth: 2.5),
        ),
      );
    }

    final clasificados = _clasificadosActivos;
    final cruceFinal = _cruceFinal;
    final hayGanador = cruceFinal?.ganadorCruceId != null;
    final proximo = _proximoPartidoLiguilla;

    return FadeTransition(
      opacity: _esLiguillaA ? _fadeCtrl : _fadeBCtrl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Carrusel clasificados
            if (clasificados.isNotEmpty) ...[
              _buildClassifiedBanner(),
              const SizedBox(height: 24),
            ],

            // 2. Campeón o próximo partido
            if (hayGanador) ...[
              _buildCampeonCard(
                hayGanador && cruceFinal!.ganadorCruceId == cruceFinal.equipo1Id
                    ? cruceFinal.equipo1Nombre
                    : cruceFinal!.equipo2Nombre,
                hayGanador && cruceFinal.ganadorCruceId == cruceFinal.equipo1Id
                    ? cruceFinal.equipo1LogoUrl
                    : cruceFinal.equipo2LogoUrl,
              ),
              const SizedBox(height: 24),
            ] else if (proximo != null) ...[
              _buildSectionLabel(
                'PRÓXIMO PARTIDO',
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 10),
              _buildNextMatchLiguillaCard(proximo),
              const SizedBox(height: 24),
            ],

            // 3. Bracket
            if (clasificados.length >= 4) ...[
              _buildSectionLabel(
                'BRACKET LIGUILLA',
                icon: Icons.account_tree_rounded,
              ),
              const SizedBox(height: 10),
              _buildBracketCard(),
              const SizedBox(height: 24),
            ],

            // 4. Cierre
            _buildGraciasCard(),
          ],
        ),
      ),
    );
  }

  Widget _toggleLiguillaBtn(
    String liga,
    String label,
    Color color,
    String activa,
  ) {
    final isActive = activa == liga;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_service.liguillaActiva.value == liga) return;
          _service.liguillaActiva.value = liga;
          // La carga la maneja _onLiguillaActivaChanged
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isActive ? color.withOpacity(0.4) : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 14,
                color: isActive ? color : _P.slate,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _ts(
                  size: 13,
                  weight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? color : _P.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── EPIC HERO ──────────────────────────────────────────────────────────────
  Widget _buildEpicHero() {
    return Column(
      children: [
        // ── Header idéntico al HomeScreen ──────────────────────────────
        Container(
          color: _P.surface,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
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
                _buildSeasonSelector(),
              ],
            ),
          ),
        ),

        // ── Selector Liga / Liguilla ────────────────────────────────────
        _buildFaseSelectorBar(),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    return ValueListenableBuilder<List<Temporada>>(
      valueListenable: _service.seasons,
      builder: (ctx, seasonsList, _) {
        if (seasonsList.isEmpty) {
          return const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: _P.blue),
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
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  style: _ts(size: 12, weight: FontWeight.w600, color: _P.blue),
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
            );
          },
        );
      },
    );
  }

  Widget _buildFaseSelectorBar() {
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
              border: Border.all(color: _P.blue.withOpacity(0.2), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _fasePill('Liga', fase == 'liga', () {
                    _service.faseVista.value = 'liga';
                  }),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _fasePill('Liguilla', fase == 'liguilla', () {
                    _service.faseVista.value = 'liguilla';
                  }),
                ),
              ],
            ),
          ),
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

  // ─── BANNER CLASIFICADOS ────────────────────────────────────────────────────
  Widget _buildClassifiedBanner() {
    final clasificados = _clasificadosActivos;
    if (clasificados.isEmpty) return const SizedBox.shrink();

    int _currentIndex = 0;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          children: [
            CarouselSlider.builder(
              itemCount: clasificados.length,
              itemBuilder: (context, index, _) =>
                  _buildClassifiedCard(clasificados[index], index),
              options: CarouselOptions(
                height: 160,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 6), // ← más tiempo
                autoPlayAnimationDuration: const Duration(milliseconds: 500),
                autoPlayCurve: Curves.easeInOut,
                viewportFraction: 0.90,
                enlargeCenterPage: true,
                enlargeFactor: 0.08,
                padEnds: true,
                clipBehavior: Clip.none,
                onPageChanged: (index, reason) {
                  setLocalState(() => _currentIndex = index);
                },
              ),
            ),

            // ── Espacio inferior + bolitas ────────────────────────────────
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(clasificados.length, (i) {
                final isActive = i == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? _P.gold : _P.silverLine,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClassifiedCard(Equipo eq, int index) {
    final teamColor = _colorFromHex(eq.color);
    // Si el color es el fallback (heroMid), usamos un azul más vivo
    final isDefaultColor = eq.color.isEmpty;
    final gradientA = isDefaultColor ? _P.blue : teamColor;
    final gradientB = isDefaultColor
        ? _P.heroTop
        : Color.lerp(teamColor, Colors.black, 0.55)!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientA, gradientB],
        ),
        border: Border.all(color: _P.silverLine, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: gradientA.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Círculo decorativo de fondo ──────────────────────────────
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                // Logo grande
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: eq.logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: eq.logoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.shield_outlined,
                              color: Colors.white54,
                              size: 32,
                            ),
                          )
                        : Icon(
                            Icons.shield_outlined,
                            color: Colors.white54,
                            size: 32,
                          ),
                  ),
                ),

                const SizedBox(width: 16),

                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Etiqueta
                      Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: _P.gold,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CLASIFICADO',
                            style: _ts(
                              size: 10,
                              weight: FontWeight.w800,
                              color: _P.gold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Nombre del equipo
                      Text(
                        eq.nombre,
                        style: _ts(
                          size: 20,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PRÓXIMO PARTIDO LIGUILLA ────────────────────────────────────────────────
  Widget _buildNextMatchLiguillaCard(PartidoLiguilla p) {
    final fecha = p.fecha;
    const meses = [
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

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _P.blue.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _P.heroTop,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _P.gold.withOpacity(0.6 + _pulseCtrl.value * 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _labelRonda(p.ronda),
                  style: _ts(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _P.gold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (p.hora != null)
                  Text('${p.hora}', style: _ts(size: 11, color: _P.textOnDark)),
              ],
            ),
          ),

          // Equipos
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _teamLogo(p.equipo1LogoUrl, size: 54),
                      const SizedBox(height: 8),
                      Text(
                        p.equipo1Nombre,
                        style: _ts(size: 13, weight: FontWeight.w700),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (fecha != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _P.heroTop,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${fecha.day}',
                              style: _ts(
                                size: 22,
                                weight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              meses[fecha.month - 1],
                              style: _ts(
                                size: 10,
                                weight: FontWeight.w700,
                                color: _P.textOnDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'VS',
                      style: _ts(
                        size: 16,
                        weight: FontWeight.w900,
                        color: _P.slate,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      _teamLogo(p.equipo2LogoUrl, size: 54),
                      const SizedBox(height: 8),
                      Text(
                        p.equipo2Nombre,
                        style: _ts(size: 13, weight: FontWeight.w700),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _goldButton(
              label: 'Ver todos los partidos →',
              onTap: widget.onGoToMatchdays,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD CAMPEÓN ────────────────────────────────────────────────────────────
  Widget _buildCampeonCard(String nombre, String logoUrl) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2E6B), Color(0xFF0D1B3E), Color(0xFF0F2347)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.gold.withOpacity(0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _P.gold.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Círculos decorativos
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _P.gold.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _P.gold.withOpacity(0.04),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                // Etiqueta superior
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_rounded, color: _P.gold, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'CAMPEÓN DE LA TEMPORADA',
                      style: _ts(
                        size: 10,
                        weight: FontWeight.w800,
                        color: _P.gold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.emoji_events_rounded, color: _P.gold, size: 15),
                  ],
                ),
                const SizedBox(height: 20),

                // Logo con anillo dorado animado
                AnimatedBuilder(
                  animation: _bannerCtrl,
                  builder: (_, __) => Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _P.gold.withOpacity(
                          0.55 + _bannerCtrl.value * 0.45,
                        ),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _P.gold.withOpacity(
                            0.20 + _bannerCtrl.value * 0.20,
                          ),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(child: _teamLogo(logoUrl, size: 100)),
                  ),
                ),
                const SizedBox(height: 16),

                // Nombre
                Text(
                  nombre,
                  textAlign: TextAlign.center,
                  style: _ts(
                    size: 26,
                    weight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),

                // Línea dorada decorativa
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 1,
                      color: _P.gold.withOpacity(0.3),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('🏆', style: TextStyle(fontSize: 18)),
                    ),
                    Container(
                      width: 32,
                      height: 1,
                      color: _P.gold.withOpacity(0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '¡Felicidades!',
                  style: _ts(
                    size: 12,
                    weight: FontWeight.w500,
                    color: _P.textOnDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── BRACKET LIGUILLA (una llave, ida + vuelta) ──────────────────────────────
  // ── Getters reactivos a liguilla activa ──────────────────────────────────────
  String _cruceKey(Cruce c) => c.cruceId ?? '${c.ronda}_${c.orden}';
  bool get _esLiguillaA => _service.liguillaActiva.value == 'A';

  List<PartidoLiguilla> get _partidosActivos =>
      _esLiguillaA ? _partidosLiguilla : _partidosLiguillaB;

  List<Equipo> get _clasificadosActivos =>
      _esLiguillaA ? _clasificados : _clasificadosB;

  bool get _isLoadingActivo {
    final val = _esLiguillaA ? _isLoading : _isLoadingB;
    debugPrint(
      '🔍 _isLoadingActivo: liga=${_service.liguillaActiva.value} '
      '_isLoading=$_isLoading _isLoadingB=$_isLoadingB → resultado=$val',
    );
    return val;
  }

  List<Cruce> get _crucesActivos => _service.agruparEnCruces(_partidosActivos);

  // DESPUÉS
  List<Cruce> _ordenarParaBracketHome(List<Cruce> cruces) {
    final izq = cruces.where((c) => c.orden % 2 == 1).toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final der = cruces.where((c) => c.orden % 2 == 0).toList()
      ..sort((a, b) => b.orden.compareTo(a.orden)); // invertido
    return [...izq, ...der];
  }

  List<Cruce> get _crucesPrevio => _ordenarParaBracketHome(
    _crucesActivos.where((c) => c.ronda == 'previo').toList(),
  );

  List<Cruce> get _crucesCuartos => _ordenarParaBracketHome(
    _crucesActivos.where((c) => c.ronda == 'cuartos').toList(),
  );

  List<Cruce> get _crucesSemis => _ordenarParaBracketHome(
    _crucesActivos.where((c) => c.ronda == 'semis').toList(),
  );

  Cruce? get _cruceFinal =>
      _crucesActivos.where((c) => c.ronda == 'final').firstOrNull;

  Widget _buildBracketCard() {
    if (_partidosActivos.isEmpty) return const SizedBox.shrink();

    final previo = _crucesPrevio;
    final cuartos = _crucesCuartos;
    final semis = _crucesSemis;
    final final_ = _cruceFinal;

    final List<({String label, List<Cruce> cruces})> rondas = [
      if (previo.isNotEmpty) (label: 'OCTAVOS', cruces: previo),
      if (cuartos.isNotEmpty) (label: 'CUARTOS', cruces: cuartos),
      if (semis.isNotEmpty) (label: 'SEMIS', cruces: semis),
    ];

    if (rondas.isEmpty && final_ == null) return const SizedBox.shrink();

    const double cardW = 108.0;
    const double connW = 28.0;
    const double finalW = 108.0;
    const double hPad = 12.0;

    // ── KeyMap — igual que bracket_screen ─────────────────────────────
    final Map<String, GlobalKey> keyMap = {};
    for (final r in rondas) {
      for (final c in r.cruces) {
        keyMap[_cruceKey(c)] = GlobalKey();
      }
    }
    if (final_ != null) keyMap[_cruceKey(final_!)] = GlobalKey();

    // ── Connections — igual que bracket_screen ────────────────────────
    final List<_HomeConnection> connections = [];
    final rondasLists = rondas.map((r) => r.cruces).toList();

    for (int ri = 0; ri < rondasLists.length; ri++) {
      final currentRonda = rondasLists[ri];
      final nextRonda = ri + 1 < rondasLists.length
          ? rondasLists[ri + 1]
          : (final_ != null ? [final_!] : <Cruce>[]);
      if (nextRonda.isEmpty) continue;

      for (final fromCruce in currentRonda) {
        final fk = keyMap[_cruceKey(fromCruce)];
        if (fk == null) continue;

        // Buscar destino por siguientePartidoId (ida del cruce destino)
        // El siguientePartidoId del ida de fromCruce apunta al ida del cruce destino
        final sigId = fromCruce.ida.siguientePartidoId;

        Cruce? destino;
        if (sigId != null) {
          // Buscar en nextRonda el cruce cuya ida tiene ese id
          destino = nextRonda.where((c) => c.ida.id == sigId).firstOrNull;
        }

        // Fallback: orden del previo = orden del cuarto destino
        if (destino == null) {
          destino = nextRonda
              .where((c) => c.orden == fromCruce.orden)
              .firstOrNull;
        }

        if (destino != null) {
          final tk = keyMap[_cruceKey(destino)];
          if (tk != null) {
            connections.add(_HomeConnection(fromKey: fk, toKey: tk));
          }
        }
      }
    }

    // ── Ancho total ───────────────────────────────────────────────────
    final int n = rondas.length;
    // n rondas + n conectores + final
    final double totalW = cardW * n + connW * (n + 1) + finalW;

    final hayGanador = final_?.ganadorCruceId != null;
    final campeonNombre = hayGanador ? final_!.ganadorNombre : null;
    final campeonLogo = hayGanador ? final_!.ganadorLogoUrl : null;
    const double colChamp = 80.0;
    final double totalWConChamp = hayGanador
        ? totalW + connW + colChamp
        : totalW;

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _P.gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'BRACKET',
                  style: _ts(
                    size: 10,
                    weight: FontWeight.w800,
                    color: _P.navy,
                    letterSpacing: 2.5,
                  ),
                ),
                const Spacer(),
                _bracketPhaseChipCruce(cuartos, semis, final_),
              ],
            ),
          ),
          Divider(height: 0, thickness: 0.5, color: _P.border),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, 14),
              child: SizedBox(
                width: totalWConChamp,
                child: _buildBracketWithLinesHome(
                  rondas: rondas,
                  final_: final_,
                  keyMap: keyMap,
                  connections: connections,
                  cardW: cardW,
                  connW: connW,
                  finalW: finalW,
                  hayGanador: hayGanador,
                  campeonNombre: campeonNombre,
                  campeonLogo: campeonLogo,
                  colChamp: colChamp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBracketWithLinesHome({
    required List<({String label, List<Cruce> cruces})> rondas,
    required Cruce? final_,
    required Map<String, GlobalKey> keyMap,
    required List<_HomeConnection> connections,
    required double cardW,
    required double connW,
    required double finalW,
    required bool hayGanador,
    required String? campeonNombre,
    required String? campeonLogo,
    required double colChamp,
  }) {
    final labels = rondas.map((r) => r.label).toList();
    final int n = rondas.length;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Labels de ronda ──────────────────────────────────────
            Row(
              children: [
                for (int i = 0; i < n; i++) ...[
                  SizedBox(width: cardW, child: _bracketRoundLabel(labels[i])),
                  SizedBox(width: connW),
                ],
                SizedBox(
                  width: finalW,
                  child: _bracketRoundLabel('FINAL', gold: true),
                ),
                if (hayGanador) ...[
                  SizedBox(width: connW),
                  SizedBox(
                    width: colChamp,
                    child: _bracketRoundLabel('CAMPEÓN', gold: true),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // ── Cards ─────────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < n; i++) ...[
                    SizedBox(
                      width: cardW,
                      child: _columnaKeyed(rondas[i].cruces, keyMap),
                    ),
                    SizedBox(width: connW),
                  ],
                  SizedBox(
                    width: finalW,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KeyedSubtree(
                          key: final_ != null
                              ? keyMap[_cruceKey(final_!)]
                              : null,
                          child: _bracketCruceFinalCard(final_),
                        ),
                      ],
                    ),
                  ),
                  if (hayGanador) ...[
                    SizedBox(
                      width: connW,
                      child: Center(
                        child: Container(
                          height: 1.5,
                          color: _P.gold.withOpacity(0.5),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: colChamp,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _bracketChampion(campeonNombre!, campeonLogo),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // ── Overlay de líneas — igual que bracket_screen ──────────────
        Positioned.fill(
          child: IgnorePointer(
            child: _HomeBracketLinesOverlay(connections: connections),
          ),
        ),
      ],
    );
  }

  Widget _columnaKeyed(List<Cruce> cruces, Map<String, GlobalKey> keyMap) {
    if (cruces.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < cruces.length; i++) ...[
          Container(
            key: keyMap[_cruceKey(cruces[i])],
            child: _bracketCruceCard(cruces[i]),
          ),
          if (i < cruces.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  // ── Card de cruce (cuartos / semis) con ida+vuelta ───────────────────────────
  Widget _bracketCruceCard(Cruce? c) {
    if (c == null) {
      return Container(
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: _bracketEmptySlot(),
      );
    }

    final resuelto = c.resuelto;
    final enCurso = !resuelto && (c.idaJugada || c.vueltaJugada);
    final hayEq1 = c.equipo1Id != null || c.equipo1Nombre.isNotEmpty;
    final hayEq2 = c.equipo2Id != null || c.equipo2Nombre.isNotEmpty;
    final totalmenteVacio = !hayEq1 && !hayEq2;

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: resuelto
              ? _P.blue.withOpacity(0.35)
              : enCurso
              ? _P.goldSoft.withOpacity(0.5)
              : _P.border,
          width: (resuelto || enCurso) ? 1 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: totalmenteVacio
          ? _bracketEmptySlot()
          : _bracketCruceContentPartial(c),
    );
  }

  Widget _bracketCruceContent(Cruce c) {
    final eq1gana = c.resuelto && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = c.resuelto && c.ganadorCruceId == c.equipo2Id;
    final mostrarGoles = c.idaJugada || c.vueltaJugada;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bracketTeamRow(
          logoUrl: c.equipo1LogoUrl,
          nombre: c.equipo1Nombre,
          goles: mostrarGoles ? c.golesGlobalesEq1 : null,
          gano: eq1gana,
          perdio: c.resuelto && !eq1gana,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Divider(height: 0, thickness: 0.5, color: _P.border),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  c.resuelto ? 'FT' : (c.idaJugada ? 'IDA' : 'I+V'),
                  style: _ts(
                    size: 6,
                    weight: FontWeight.w700,
                    color: c.resuelto ? _P.blue : _P.slate,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: Divider(height: 0, thickness: 0.5, color: _P.border),
              ),
            ],
          ),
        ),
        _bracketTeamRow(
          logoUrl: c.equipo2LogoUrl,
          nombre: c.equipo2Nombre,
          goles: mostrarGoles ? c.golesGlobalesEq2 : null,
          gano: eq2gana,
          perdio: c.resuelto && !eq2gana,
        ),
        const SizedBox(height: 4),
        // Pills ida / vuelta
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _idaVueltaPill(jugado: c.idaJugada, label: 'I'),
            const SizedBox(width: 3),
            _idaVueltaPill(jugado: c.vueltaJugada, label: 'V'),
          ],
        ),
        if (c.vuelta?.penales == true && c.resuelto) ...[
          const SizedBox(height: 3),
          Text(
            'PEN',
            style: _ts(size: 7, weight: FontWeight.w800, color: _P.goldSoft),
          ),
        ],
      ],
    );
  }

  /// Igual que _bracketCruceContent pero soporta equipos parciales
  /// (uno definido y el otro en espera) — igual que bracket_screen
  Widget _bracketCruceContentPartial(Cruce c) {
    final eq1gana = c.resuelto && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = c.resuelto && c.ganadorCruceId == c.equipo2Id;
    final mostrarGoles = c.idaJugada || c.vueltaJugada;
    final hayEq1 = c.equipo1Id != null || c.equipo1Nombre.isNotEmpty;
    final hayEq2 = c.equipo2Id != null || c.equipo2Nombre.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Equipo 1 o slot vacío
        hayEq1
            ? _bracketTeamRow(
                logoUrl: c.equipo1LogoUrl,
                nombre: c.equipo1Nombre,
                goles: mostrarGoles ? c.golesGlobalesEq1 : null,
                gano: eq1gana,
                perdio: c.resuelto && !eq1gana,
              )
            : _bracketEmptyTeamRow(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Divider(height: 0, thickness: 0.5, color: _P.border),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  c.resuelto ? 'FT' : (c.idaJugada ? 'IDA' : 'I+V'),
                  style: _ts(
                    size: 6,
                    weight: FontWeight.w700,
                    color: c.resuelto ? _P.blue : _P.slate,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: Divider(height: 0, thickness: 0.5, color: _P.border),
              ),
            ],
          ),
        ),
        // Equipo 2 o slot vacío
        hayEq2
            ? _bracketTeamRow(
                logoUrl: c.equipo2LogoUrl,
                nombre: c.equipo2Nombre,
                goles: mostrarGoles ? c.golesGlobalesEq2 : null,
                gano: eq2gana,
                perdio: c.resuelto && !eq2gana,
              )
            : _bracketEmptyTeamRow(),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _idaVueltaPill(jugado: c.idaJugada, label: 'I'),
            const SizedBox(width: 3),
            _idaVueltaPill(jugado: c.vueltaJugada, label: 'V'),
          ],
        ),
        if (c.vuelta?.penales == true && c.resuelto) ...[
          const SizedBox(height: 3),
          Text(
            'PEN',
            style: _ts(size: 7, weight: FontWeight.w800, color: _P.goldSoft),
          ),
        ],
      ],
    );
  }

  /// Fila de equipo vacío (rival por definir) — una sola línea compacta
  Widget _bracketEmptyTeamRow() {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _P.bg,
            shape: BoxShape.circle,
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Icon(Icons.shield_outlined, color: _P.border, size: 12),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Por definir',
            style: _ts(size: 8, color: _P.border),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _idaVueltaPill({required bool jugado, required String label}) {
    return Container(
      width: 16,
      height: 12,
      decoration: BoxDecoration(
        color: jugado ? _P.blue.withOpacity(0.15) : _P.bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: jugado ? _P.blue.withOpacity(0.4) : _P.border,
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: _ts(
          size: 6,
          weight: FontWeight.w700,
          color: jugado ? _P.blue : _P.slate,
        ),
      ),
    );
  }

  // ── Card final con Cruce (ida+vuelta) ────────────────────────────────────────
  Widget _bracketCruceFinalCard(Cruce? c) {
    final hayGanador = c?.ganadorCruceId != null;
    final empty = c == null || !c.tieneEquipos;
    final eq1gana = c != null && hayGanador && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = c != null && hayGanador && c.ganadorCruceId == c.equipo2Id;
    final mostrarGoles = c != null && (c.idaJugada || c.vueltaJugada);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.heroMid, _P.heroTop],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hayGanador ? _P.gold.withOpacity(0.5) : _P.silverLine,
          width: hayGanador ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hayGanador
                ? _P.gold.withOpacity(0.15)
                : _P.blue.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: hayGanador ? _P.gold : Colors.white.withOpacity(0.3),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'GRAN FINAL',
                  style: _ts(
                    size: 7,
                    weight: FontWeight.w800,
                    color: hayGanador ? _P.gold : Colors.white.withOpacity(0.3),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 0,
            thickness: 0.5,
            color: Colors.white.withOpacity(0.1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
            child: empty
                ? Column(
                    children: [
                      _bracketEmptySlotDark(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'VS',
                          style: _ts(
                            size: 7,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                      _bracketEmptySlotDark(),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bracketTeamRowDark(
                        logoUrl: c!.equipo1LogoUrl,
                        nombre: c.equipo1Nombre,
                        goles: mostrarGoles ? c.golesGlobalesEq1 : null,
                        gano: eq1gana,
                        perdio: hayGanador && !eq1gana,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                height: 0,
                                thickness: 0.5,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(
                                c.resuelto
                                    ? 'FT'
                                    : (c.idaJugada ? 'IDA' : 'I+V'),
                                style: _ts(
                                  size: 7,
                                  weight: FontWeight.w700,
                                  color: c.resuelto
                                      ? const Color(0xFF7AAECB)
                                      : Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                height: 0,
                                thickness: 0.5,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _bracketTeamRowDark(
                        logoUrl: c.equipo2LogoUrl,
                        nombre: c.equipo2Nombre,
                        goles: mostrarGoles ? c.golesGlobalesEq2 : null,
                        gano: eq2gana,
                        perdio: hayGanador && !eq2gana,
                      ),
                      const SizedBox(height: 5),
                      // Pills ida / vuelta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _idaVueltaPillDark(jugado: c.idaJugada, label: 'I'),
                          const SizedBox(width: 3),
                          _idaVueltaPillDark(
                            jugado: c.vueltaJugada,
                            label: 'V',
                          ),
                        ],
                      ),
                      if (c.vuelta?.penales == true && c.resuelto) ...[
                        const SizedBox(height: 5),
                        Text(
                          'PENALES',
                          style: _ts(
                            size: 7,
                            weight: FontWeight.w800,
                            color: _P.goldSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          if (hayGanador) ...[
            Divider(
              height: 0,
              thickness: 0.5,
              color: _P.gold.withOpacity(0.25),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: _P.gold.withOpacity(0.10),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Text(
                '🏆  CAMPEÓN',
                textAlign: TextAlign.center,
                style: _ts(
                  size: 7,
                  weight: FontWeight.w800,
                  color: _P.gold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _idaVueltaPillDark({required bool jugado, required String label}) {
    return Container(
      width: 16,
      height: 12,
      decoration: BoxDecoration(
        color: jugado
            ? _P.gold.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: jugado
              ? _P.gold.withOpacity(0.4)
              : Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: _ts(
          size: 6,
          weight: FontWeight.w700,
          color: jugado ? _P.gold : Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _bracketPhaseChipCruce(
    List<Cruce> cuartos,
    List<Cruce> semis,
    Cruce? final_,
  ) {
    final resueltosC = cuartos.where((c) => c.resuelto).length;
    final resueltosS = semis.where((c) => c.resuelto).length;
    final resueltaF = final_?.resuelto ?? false;

    String fase;
    Color color;
    if (resueltaF) {
      fase = 'Finalizado';
      color = _P.goldSoft;
    } else if (resueltosS > 0) {
      fase = 'Semifinales';
      color = _P.blue;
    } else if (resueltosC > 0) {
      fase = 'Cuartos';
      color = _P.green;
    } else {
      fase = 'Por iniciar';
      color = _P.slate;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            fase,
            style: _ts(size: 9, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ── Labels de ronda ──────────────────────────────────────────────────────────
  Widget _bracketRoundLabel(String text, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: gold ? _P.gold.withOpacity(0.12) : _P.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: gold ? _P.gold.withOpacity(0.35) : _P.border,
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _ts(
          size: 8,
          weight: FontWeight.w800,
          color: gold ? _P.goldSoft : _P.slate,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── Card mini partido (cuartos / semis) ──────────────────────────────────────
  Widget _bracketMiniCard(PartidoLiguilla? p) {
    final empty = p == null || (p.equipo1Id == null && p.equipo2Id == null);
    final eq1gano = !empty && p!.jugado && p.ganadorId == p.equipo1Id;
    final eq2gano = !empty && p!.jugado && p.ganadorId == p.equipo2Id;

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (!empty && p!.jugado) ? _P.blue.withOpacity(0.35) : _P.border,
          width: (!empty && p!.jugado) ? 1 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: empty
          ? _bracketEmptySlot()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _bracketTeamRow(
                  logoUrl: p!.equipo1LogoUrl,
                  nombre: p.equipo1Nombre,
                  goles: p.golesEquipo1,
                  gano: eq1gano,
                  perdio: p.jugado && !eq1gano,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 0, thickness: 0.5, color: _P.border),
                ),
                _bracketTeamRow(
                  logoUrl: p.equipo2LogoUrl,
                  nombre: p.equipo2Nombre,
                  goles: p.golesEquipo2,
                  gano: eq2gano,
                  perdio: p.jugado && !eq2gano,
                ),
                if (p.penales && p.jugado) ...[
                  const SizedBox(height: 3),
                  Text(
                    'PEN',
                    style: _ts(
                      size: 7,
                      weight: FontWeight.w800,
                      color: _P.goldSoft,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  // ── Columna campeón ──────────────────────────────────────────────────────────
  Widget _bracketChampion(String nombre, String? logoUrl) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _P.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: _P.gold.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipOval(child: _teamLogo(logoUrl, size: 52)),
        ),
        const SizedBox(height: 6),
        const Icon(Icons.emoji_events_rounded, color: _P.gold, size: 18),
        const SizedBox(height: 4),
        Text(
          nombre,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _ts(size: 9, weight: FontWeight.w800, color: _P.navy),
        ),
      ],
    );
  }

  // ── Team row claro (cuartos/semis) ───────────────────────────────────────────
  Widget _bracketTeamRow({
    required String logoUrl,
    required String nombre,
    required int? goles,
    required bool gano,
    required bool perdio,
  }) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            _teamLogo(logoUrl, size: 26),
            if (perdio)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _P.surface.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            nombre.isNotEmpty ? _abreviarNombre(nombre) : '—',
            style: _ts(
              size: 8,
              weight: gano ? FontWeight.w700 : FontWeight.w400,
              color: perdio
                  ? _P.border
                  : gano
                  ? _P.navy
                  : _P.slate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (goles != null) ...[
          const SizedBox(width: 3),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: gano ? _P.blueLight : _P.bg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: gano ? _P.blue.withOpacity(0.3) : _P.border,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$goles',
              style: _ts(
                size: 9,
                weight: FontWeight.w800,
                color: gano ? _P.blue : _P.slate,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Team row oscuro (final) ───────────────────────────────────────────────────
  Widget _bracketTeamRowDark({
    required String logoUrl,
    required String nombre,
    required int? goles,
    required bool gano,
    required bool perdio,
  }) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            _teamLogo(logoUrl, size: 26),
            if (perdio)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _P.heroTop.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            nombre.isNotEmpty ? _abreviarNombre(nombre) : '—',
            style: _ts(
              size: 8,
              weight: gano ? FontWeight.w700 : FontWeight.w400,
              color: perdio
                  ? Colors.white.withOpacity(0.2)
                  : gano
                  ? Colors.white
                  : const Color(0xFF7AAECB),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (goles != null) ...[
          const SizedBox(width: 3),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: gano
                  ? _P.gold.withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: gano
                    ? _P.gold.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$goles',
              style: _ts(
                size: 9,
                weight: FontWeight.w800,
                color: gano ? _P.gold : Colors.white.withOpacity(0.25),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Empty slots ───────────────────────────────────────────────────────────────
  Widget _bracketEmptySlot() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _P.bg,
                shape: BoxShape.circle,
                border: Border.all(color: _P.border, width: 0.5),
              ),
              child: Icon(Icons.shield_outlined, color: _P.border, size: 12),
            ),
            const SizedBox(width: 4),
            Text('???', style: _ts(size: 8, color: _P.border)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 0, thickness: 0.5, color: _P.border),
        ),
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _P.bg,
                shape: BoxShape.circle,
                border: Border.all(color: _P.border, width: 0.5),
              ),
              child: Icon(Icons.shield_outlined, color: _P.border, size: 12),
            ),
            const SizedBox(width: 4),
            Text('???', style: _ts(size: 8, color: _P.border)),
          ],
        ),
      ],
    );
  }

  Widget _bracketEmptySlotDark() {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.shield_outlined,
            color: Colors.white.withOpacity(0.15),
            size: 12,
          ),
        ),
        const SizedBox(width: 4),
        Text('???', style: _ts(size: 8, color: Colors.white.withOpacity(0.2))),
      ],
    );
  }

  // ── Abreviar nombre ───────────────────────────────────────────────────────────
  String _abreviarNombre(String nombre) => nombre.trim().split(' ').first;

  // ─── SECTION LABEL ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: _P.blue),
          const SizedBox(width: 7),
        ],
        Text(
          title,
          style: _ts(
            size: 12,
            weight: FontWeight.w800,
            color: _P.slate,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // ─── BOTONES ────────────────────────────────────────────────────────────────
  Widget _goldButton({required String label, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_P.heroTop, _P.heroMid]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _P.silverLine, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _ts(size: 13, weight: FontWeight.w700, color: _P.textOnDark),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: _P.blue),
              const SizedBox(width: 7),
              Text(
                label,
                style: _ts(size: 13, weight: FontWeight.w600, color: _P.navy),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────
  Widget _teamLogo(String? url, {double size = 28}) {
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _P.heroMid,
          shape: BoxShape.circle,
          border: Border.all(color: _P.silverLine, width: 1),
        ),
        child: Icon(Icons.shield_outlined, color: _P.slate, size: size * 0.5),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
          child: Icon(Icons.shield_outlined, color: _P.slate, size: size * 0.5),
        ),
      ),
    );
  }

  Color _colorFromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {}
    return _P.heroMid;
  }
}

/// Conector 4 cuartos → 2 semis (lado izquierdo)
class _BracketConnLeft4to2 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0D4E8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Los 4 cuartos están en spaceEvenly → aprox en 12.5%, 37.5%, 62.5%, 87.5%
    final q1 = size.height * 0.125;
    final q2 = size.height * 0.375;
    final q3 = size.height * 0.625;
    final q4 = size.height * 0.875;
    // Las 2 semis están en spaceEvenly → aprox 25% y 75%
    final s1 = size.height * 0.25;
    final s2 = size.height * 0.75;
    final cx = size.width * 0.5;

    // Cuartos 1+2 → Semi 1
    canvas.drawLine(Offset(0, q1), Offset(cx, q1), paint);
    canvas.drawLine(Offset(0, q2), Offset(cx, q2), paint);
    canvas.drawLine(Offset(cx, q1), Offset(cx, q2), paint);
    canvas.drawLine(Offset(cx, s1), Offset(size.width, s1), paint);

    // Cuartos 3+4 → Semi 2
    canvas.drawLine(Offset(0, q3), Offset(cx, q3), paint);
    canvas.drawLine(Offset(0, q4), Offset(cx, q4), paint);
    canvas.drawLine(Offset(cx, q3), Offset(cx, q4), paint);
    canvas.drawLine(Offset(cx, s2), Offset(size.width, s2), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Conector 2 semis → 1 final
/// Conector genérico N entradas → M salidas (izquierda a derecha)
class _BracketConnGeneric extends CustomPainter {
  final int fromCount;
  final int toCount;
  const _BracketConnGeneric({required this.fromCount, required this.toCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0D4E8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Posiciones Y de los "from" (spaceEvenly)
    List<double> fromYs = List.generate(fromCount, (i) {
      final slot = size.height / fromCount;
      return slot * i + slot / 2;
    });

    // Posiciones Y de los "to"
    List<double> toYs = List.generate(toCount, (i) {
      final slot = size.height / toCount;
      return slot * i + slot / 2;
    });

    final cx = size.width / 2;

    // Agrupa los "from" que alimentan a cada "to"
    final ratio = fromCount / toCount;
    for (int ti = 0; ti < toCount; ti++) {
      final start = (ti * ratio).floor();
      final end = ((ti + 1) * ratio).floor().clamp(start + 1, fromCount);
      final groupFromYs = fromYs.sublist(start, end);
      final midY = groupFromYs.reduce((a, b) => a + b) / groupFromYs.length;
      // Líneas desde cada "from" hasta el punto medio
      for (final fy in groupFromYs) {
        canvas.drawLine(Offset(0, fy), Offset(cx, fy), paint);
      }
      // Línea vertical que los une
      if (groupFromYs.length > 1) {
        canvas.drawLine(
          Offset(cx, groupFromYs.first),
          Offset(cx, groupFromYs.last),
          paint,
        );
      }
      // Línea horizontal hacia el "to"
      canvas.drawLine(Offset(cx, midY), Offset(size.width, toYs[ti]), paint);
    }
  }

  @override
  bool shouldRepaint(_BracketConnGeneric old) =>
      old.fromCount != fromCount || old.toCount != toCount;
}

/// Conector 2 semis → 1 final
class _BracketConnLeft2to1 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A6FD8).withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final s1 = size.height * 0.25;
    final s2 = size.height * 0.75;
    final mid = size.height * 0.5;
    final cx = size.width * 0.5;

    canvas.drawLine(Offset(0, s1), Offset(cx, s1), paint);
    canvas.drawLine(Offset(0, s2), Offset(cx, s2), paint);
    canvas.drawLine(Offset(cx, s1), Offset(cx, s2), paint);
    canvas.drawLine(Offset(cx, mid), Offset(size.width, mid), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Modelo de conexión para el bracket del home (izquierda→derecha) ────────
class _HomeConnection {
  final GlobalKey fromKey;
  final GlobalKey toKey;
  const _HomeConnection({required this.fromKey, required this.toKey});
}

// ── Overlay de líneas (igual que bracket_screen pero solo izq→der) ─────────
class _HomeBracketLinesOverlay extends StatefulWidget {
  final List<_HomeConnection> connections;
  const _HomeBracketLinesOverlay({super.key, required this.connections});
  @override
  State<_HomeBracketLinesOverlay> createState() =>
      _HomeBracketLinesOverlayState();
}

class _HomeBracketLinesOverlayState extends State<_HomeBracketLinesOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HomeBracketLinesPainter(
      connections: widget.connections,
      overlayContext: context,
    ),
  );
}

class _HomeBracketLinesPainter extends CustomPainter {
  final List<_HomeConnection> connections;
  final BuildContext overlayContext;
  const _HomeBracketLinesPainter({
    required this.connections,
    required this.overlayContext,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0D4E8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    for (final conn in connections) {
      final fromBox =
          conn.fromKey.currentContext?.findRenderObject() as RenderBox?;
      final toBox = conn.toKey.currentContext?.findRenderObject() as RenderBox?;
      if (fromBox == null || toBox == null) continue;

      final fromLocal = overlayBox.globalToLocal(
        fromBox.localToGlobal(Offset.zero),
      );
      final toLocal = overlayBox.globalToLocal(
        toBox.localToGlobal(Offset.zero),
      );

      final fromCY = fromLocal.dy + fromBox.size.height / 2;
      final toCY = toLocal.dy + toBox.size.height / 2;
      final startX = fromLocal.dx + fromBox.size.width;
      final endX = toLocal.dx;
      final midX = (startX + endX) / 2;

      canvas.drawPath(
        Path()
          ..moveTo(startX, fromCY)
          ..lineTo(midX, fromCY)
          ..lineTo(midX, toCY)
          ..lineTo(endX, toCY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HomeBracketLinesPainter old) =>
      old.connections != connections;
}
