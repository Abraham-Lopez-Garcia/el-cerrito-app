import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/temporada_model.dart';

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
  static const amber = Color(0xFFF39C12);
  static const amberLight = Color(0xFFFEF9ED);
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

class AdminPanelScreen extends StatefulWidget {
  final VoidCallback? onGoToMatchdays;
  final VoidCallback? onGoToTeams;
  final VoidCallback? onGoBack; // ← NUEVO

  const AdminPanelScreen({
    super.key,
    this.onGoToMatchdays,
    this.onGoToTeams,
    this.onGoBack, // ← NUEVO
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  bool _isLoading = false;
  bool _hayLiguilla = false;
  bool _hayLiguillaB = false;
  late AnimationController _fadeCtrl;

  Temporada? _currentSeason;
  int _totalEquipos = 0;
  int _totalJornadas = 0;
  int _totalGoles = 0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (_service.currentSeasonId.value == null) return;
    setState(() => _isLoading = true);
    _fadeCtrl.reset();
    try {
      final season = _service.currentSeason;
      final equipos = await _service.getEquipos();
      final liguilla = await _service.getLiguilla();
      final liguillaB = await _service.getLiguillaB();
      if (mounted) {
        setState(() {
          _currentSeason = season;
          _totalEquipos = equipos.length;
          _totalJornadas = season?.totalJornadas ?? 0;
          _totalGoles = season?.totalGoles ?? 0;
          _hayLiguilla = liguilla != null;
          _isLoading = false;
          _hayLiguillaB = liguillaB != null;
        });
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('❌ AdminPanel stats error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _P.blue,
          backgroundColor: _P.surface,
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_isLoading)
                  const SizedBox(
                    height: 300,
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
                          _buildSeasonCard(),
                          const SizedBox(height: 20),
                          _buildStatsRow(),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Gestión de temporada'),
                          const SizedBox(height: 10),
                          _buildActionsGrid(),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Fase de liguilla'),
                          const SizedBox(height: 10),
                          _buildLiguillaBanner(),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Zona peligrosa'),
                          const SizedBox(height: 10),
                          _buildDangerZone(),
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
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
      child: Row(
        children: [
          // ← Botón volver
          GestureDetector(
            onTap: widget.onGoBack,
            child: Container(
              width: 36,
              height: 36,

              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _P.navy,
                size: 16,
              ),
            ),
          ),

          // Ícono admin
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A6FD8), Color(0xFF1E3050)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Título
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel de administrador',
                  style: _ts(size: 17, weight: FontWeight.w700),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: _service.currentSeasonId,
                  builder: (_, id, __) {
                    final season = _service.currentSeason;
                    return Text(
                      season?.nombre ?? 'Sin temporada activa',
                      style: _ts(size: 12, color: _P.slate),
                    );
                  },
                ),
              ],
            ),
          ),

          // Badge ADMIN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _P.blueLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.blue.withOpacity(0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, size: 11, color: _P.blue),
                const SizedBox(width: 5),
                Text(
                  'ADMIN',
                  style: _ts(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _P.blue,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEASON CARD ───────────────────────────────────────────────────────────

  Widget _buildSeasonCard() {
    return ValueListenableBuilder<List<Temporada>>(
      valueListenable: _service.seasons,
      builder: (_, seasonsList, __) {
        if (seasonsList.isEmpty) return _buildEmptySeasonCard();

        return ValueListenableBuilder<String?>(
          valueListenable: _service.currentSeasonId,
          builder: (_, seasonId, __) {
            String validId = seasonId ?? seasonsList.first.id;
            if (!seasonsList.any((s) => s.id == validId)) {
              validId = seasonsList.first.id;
            }

            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A5F), Color(0xFF111D2B)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3A6FD8).withOpacity(0.20),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4A7FA5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'TEMPORADA ACTIVA',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7AAECB),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 0.5,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: validId,
                            dropdownColor: const Color(0xFF1E3050),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF7AAECB),
                              size: 16,
                            ),
                            isDense: true,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7AAECB),
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
                              if (val != null) {
                                _service.setSeason(val);
                                _loadStats();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _currentSeason?.nombre ?? '—',
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentSeason != null
                        ? 'Creada el ${_formatDate(_currentSeason!.createdAt)}'
                        : '',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFF7AAECB),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptySeasonCard() {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_outlined, color: _P.slate, size: 36),
          const SizedBox(height: 12),
          Text(
            'No hay temporadas',
            style: _ts(size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Crea tu primera temporada para comenzar.',
            style: _ts(size: 13, color: _P.slate),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildPrimaryButton(
            label: 'Crear primera temporada',
            icon: Icons.add_rounded,
            onTap: _confirmCreateSeason,
          ),
        ],
      ),
    );
  }

  // ─── STATS ROW ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Equipos',
            value: '$_totalEquipos',
            icon: Icons.shield_outlined,
            iconColor: _P.blue,
            iconBg: _P.blueLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            label: 'Jornadas',
            value: '$_totalJornadas',
            icon: Icons.calendar_today_outlined,
            iconColor: _P.amber,
            iconBg: _P.amberLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            label: 'Goles',
            value: '$_totalGoles',
            icon: Icons.sports_soccer_rounded,
            iconColor: _P.green,
            iconBg: _P.greenLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: _ts(size: 22, weight: FontWeight.w800, height: 1.0),
          ),
          const SizedBox(height: 2),
          Text(label, style: _ts(size: 11, color: _P.slate)),
        ],
      ),
    );
  }

  // ─── SECTION LABEL ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: _ts(
        size: 13,
        weight: FontWeight.w700,
        color: _P.slate,
        letterSpacing: 0.3,
      ),
    );
  }

  // ─── ACTIONS GRID ──────────────────────────────────────────────────────────

  Widget _buildActionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle_outline_rounded,
                iconColor: _P.blue,
                iconBg: _P.blueLight,
                title: 'Nueva jornada',
                subtitle: 'Registrar partidos',
                onTap: widget.onGoToMatchdays,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.groups_outlined,
                iconColor: _P.green,
                iconBg: _P.greenLight,
                title: 'Equipos',
                subtitle: 'Gestionar plantillas',
                onTap: widget.onGoToTeams,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.edit_note_rounded,
                iconColor: _P.amber,
                iconBg: _P.amberLight,
                title: 'Resultados',
                subtitle: 'Editar marcadores',
                onTap: widget.onGoToMatchdays,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_box_outlined,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFFF3F0FF),
                title: 'Nueva temporada',
                subtitle: 'Archivar la actual',
                onTap: _confirmCreateSeason,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: _P.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: iconColor.withOpacity(0.08),
        highlightColor: iconColor.withOpacity(0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(height: 12),
                Text(title, style: _ts(size: 14, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: _ts(size: 12, color: _P.slate)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── LIGUILLA BANNER ───────────────────────────────────────────────────────

  Widget _buildLiguillaBanner() {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fase de liguilla',
                        style: _ts(size: 15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Liguilla A (Top 8) + Liguilla B (resto)',
                        style: _ts(size: 12, color: _P.slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 0, thickness: 0.5, color: _P.border),
          // Liguilla A
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'A',
                    style: _ts(
                      size: 11,
                      weight: FontWeight.w800,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Liguilla A · Top 8 equipos',
                  style: _ts(size: 13, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: _hayLiguilla
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: _P.greenLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _P.green.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _P.green,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Liguilla A ya generada',
                            style: _ts(
                              size: 14,
                              weight: FontWeight.w600,
                              color: _P.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildPrimaryButton(
                      label: 'Cerrar liga y generar Liguilla A',
                      icon: Icons.lock_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: _confirmCloseLiga,
                    ),
            ),
          ),
          Divider(height: 0, thickness: 0.5, color: _P.border),
          // Liguilla B
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _P.amberLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'B',
                    style: _ts(
                      size: 11,
                      weight: FontWeight.w800,
                      color: _P.amber,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Liguilla B · Del 9° lugar en adelante',
                  style: _ts(size: 13, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: _hayLiguillaB
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: _P.greenLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _P.green.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _P.green,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Liguilla B ya generada',
                            style: _ts(
                              size: 14,
                              weight: FontWeight.w600,
                              color: _P.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildPrimaryButton(
                      label: 'Generar Liguilla B',
                      icon: Icons.emoji_events_outlined,
                      color: _P.amber,
                      onTap: _confirmCloseLigaB,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiguillaStepper({
    required String step,
    required String label,
    required bool done,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done ? _P.greenLight : _P.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? _P.green : _P.border,
                  width: 1,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: _P.green, size: 13)
                  : Center(
                      child: Text(
                        step,
                        style: _ts(
                          size: 11,
                          weight: FontWeight.w700,
                          color: _P.slate,
                        ),
                      ),
                    ),
            ),
            if (!isLast) Container(width: 1, height: 20, color: _P.border),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: _ts(
              size: 13,
              color: done ? _P.navy : _P.slate,
              weight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  // ─── DANGER ZONE ───────────────────────────────────────────────────────────

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.red.withOpacity(0.25), width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _P.redLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: _P.red,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zona de peligro',
                        style: _ts(
                          size: 14,
                          weight: FontWeight.w700,
                          color: _P.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Acciones irreversibles sobre la temporada',
                        style: _ts(size: 12, color: _P.slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0, thickness: 0.5, color: _P.red.withOpacity(0.15)),
          _buildDangerItem(
            icon: Icons.add_box_outlined,
            label: 'Crear nueva temporada',
            subtitle: 'Archiva la actual y abre una nueva',
            onTap: _confirmCreateSeason,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        splashColor: _P.red.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _P.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: _ts(
                        size: 14,
                        weight: FontWeight.w500,
                        color: _P.red,
                      ),
                    ),
                    Text(subtitle, style: _ts(size: 12, color: _P.slate)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _P.red),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BOTÓN PRIMARIO ────────────────────────────────────────────────────────

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Color color = _P.blue,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 17),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: _ts(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── DIALOGS ───────────────────────────────────────────────────────────────

  Future<void> _confirmCreateSeason() async {
    final confirmed = await _showConfirmDialog(
      title: 'Crear nueva temporada',
      message:
          '¿Estás seguro?\nSe creará una nueva temporada y la actual quedará archivada.',
      confirmLabel: 'Crear',
      confirmColor: _P.blue,
    );
    if (confirmed != true) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      await _service.crearTemporada();
      await _loadStats();
      if (mounted) _showSnack('Nueva temporada creada ✓', _P.green);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', _P.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmCloseLiga() async {
    final equipos = await _service.getEquipos();
    if (equipos.length < 8) {
      if (mounted)
        _showSnack(
          'Se necesitan al menos 8 equipos (hay ${equipos.length})',
          _P.red,
        );
      return;
    }
    final confirmed = await _showConfirmDialog(
      title: 'Cerrar liga y generar liguilla',
      message:
          'Se generará el bracket con los 8 mejores equipos:\n\n'
          '• C1: 1° vs 8°\n• C2: 4° vs 5°\n• C3: 2° vs 7°\n• C4: 3° vs 6°\n\n'
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Cerrar liga',
      confirmColor: const Color(0xFF8B5CF6),
    );
    if (confirmed != true) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      await _service.cerrarLigaYGenerarLiguilla();
      await _loadStats();
      if (mounted) _showSnack('¡Liguilla A generada! 🏆', _P.green);
    } on Exception catch (e) {
      if (mounted) _showSnack('Error: $e', _P.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmCloseLigaB() async {
    final equipos = await _service.getEquipos();
    final restantes = equipos.length - 8;
    if (restantes < 2) {
      if (mounted)
        _showSnack(
          'Se necesitan al menos 2 equipos para Liguilla B (del 9° en adelante)',
          _P.red,
        );
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Generar Liguilla B',
      message:
          'Se generará el bracket con los equipos del 9° lugar en adelante ($restantes equipos).\n\n'
          'Los mejor rankeados recibirán bye automático.\n\n'
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Generar',
      confirmColor: _P.amber,
    );

    if (confirmed != true) return;
    if (!mounted) return; // ← GUARD antes de setState

    setState(() => _isLoading = true);

    try {
      await _service.cerrarLigaYGenerarLiguillaB();
      await _loadStats();
      if (mounted) _showSnack('¡Liguilla B generada! 🏆', _P.green);
    } on Exception catch (e) {
      if (mounted) _showSnack('Error: $e', _P.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _P.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _P.border, width: 0.5),
        ),
        title: Text(title, style: _ts(size: 17, weight: FontWeight.w700)),
        content: Text(
          message,
          style: _ts(size: 14, color: _P.slate, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: _ts(color: _P.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: _ts(color: Colors.white, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    // Guarda referencia ANTES de cualquier await
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _ts(color: Colors.white, size: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── UTIL ──────────────────────────────────────────────────────────────────

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
  }
}
