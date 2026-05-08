import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' show cos, sin, pi;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../services/firestore_service.dart';
import '../models/jornada_model.dart';
import '../models/partido_model.dart';
import '../models/goleador_model.dart';
import 'add_matchday_screen.dart';
import 'edit_matchday_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'liguilla_matchdays_screen.dart';

// ─── PALETA (UNIFIED WITH HOME SCREEN) ──────────────────────────────────────
class _P {
  static const bg = Color(0xFFF0F2F5); // Cloud Gray
  static const surface = Color(0xFFFFFFFF); // Pure White
  static const border = Color(0xFFE8EAF0); // Border Gray
  static const slate = Color(0xFF9A9FBA); // Slate
  static const navy = Color(0xFF1A1A2E); // Deep Navy
  static const blue = Color(0xFF3A6FD8); // Royal Blue
  static const blueLight = Color(0xFFEAF1FF); // Blue Light
  static const green = Color(0xFF27AE60); // Stadium Green
  static const greenLight = Color(0xFFE6F9F2); // Green Light
  static const red = Color(0xFFE74C3C); // Goal Red
  static const redLight = Color(0xFFFEF0ED); // Red Light
  static const heroDark = Color(0xFF1E3050); // Hero Dark
  static const heroText = Color(0xFF6A8FAF); // Hero Text
}

// ─── TEXT STYLES (UNIFIED) ─────────────────────────────────────────────────
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
class MatchdaysScreen extends StatefulWidget {
  const MatchdaysScreen({super.key});

  @override
  State<MatchdaysScreen> createState() => _MatchdaysScreenState();
}

class _MatchdaysScreenState extends State<MatchdaysScreen>
    with TickerProviderStateMixin {
  List<Jornada> _matchdays = [];
  bool _isLoading = true;
  String? _expandedMatchdayId;
  late AnimationController _fadeCtrl;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadMatchdays();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _precacheLogos(List<Jornada> jornadas) async {
    if (!mounted) return;
    final cacheManager = DefaultCacheManager();
    final urls = jornadas
        .expand((j) => j.partidos)
        .expand((p) => [p.equipo1LogoUrl, p.equipo2LogoUrl])
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet();

    await Future.wait(
      urls.map((url) async {
        try {
          final existing = await cacheManager.getFileFromCache(url);
          if (existing != null) return;
          await cacheManager.downloadFile(url);
        } catch (_) {}
      }),
    );
  }

  Future<void> _loadMatchdays({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);
    _fadeCtrl.reset();

    try {
      final jornadas = await _firestoreService.loadJornadasConPartidos(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _matchdays = jornadas;
          if (_matchdays.isNotEmpty && _expandedMatchdayId == null) {
            _expandedMatchdayId = _matchdays.first.id;
          }
          _isLoading = false;
        });
        _fadeCtrl.forward();
        _precacheLogos(jornadas);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar jornadas: $e',
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

  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => _DownloadDialog(matchdays: _matchdays),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: ValueListenableBuilder<String>(
          valueListenable: _firestoreService.faseVista,
          builder: (ctx, fase, _) {
            if (fase == 'liguilla') {
              return const LiguillaMatchdaysView();
            }

            // Liga: comportamiento original intacto
            return RefreshIndicator(
              color: _P.blue,
              backgroundColor: _P.surface,
              onRefresh: () async => _loadMatchdays(forceRefresh: true),
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
                              if (_matchdays.isEmpty)
                                _buildEmptyState()
                              else ...[
                                _buildHeroMatchday(_matchdays.first),
                                const SizedBox(height: 22),
                                if (_matchdays.length > 1) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: _P.blue,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Jornadas anteriores',
                                        style: _ts(
                                          size: 15,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ..._matchdays.skip(1).map(_buildMatchdayCard),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
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
                  'JORNADAS',
                  style: _ts(
                    size: 22,
                    weight: FontWeight.w800,
                    letterSpacing: 1.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Todos los partidos',
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
            onTap: _showDownloadDialog,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
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
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMatchdayScreen()),
              );
              _firestoreService.invalidateJornadasCache();
              _loadMatchdays();
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
              child: const Icon(Icons.add_rounded, color: _P.blue, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HERO MATCHDAY CARD ─────────────────────────────────────────────────
  Widget _buildHeroMatchday(Jornada jornada) {
    if (jornada.partidos.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner superior ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(color: _P.green),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'JORNADA ${jornada.numero}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${jornada.partidos.length} partidos',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.80),
                  ),
                ),
                const Spacer(),
                // Botón editar
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditMatchdayScreen(
                          matchdayId: jornada.id,
                          matchdayNumber: jornada.numero,
                        ),
                      ),
                    );
                    _firestoreService.invalidatePartidosCache(jornada.id);
                    _loadMatchdays();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.30),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'Editar →',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de partidos ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: List.generate(jornada.partidos.length, (i) {
                final p = jornada.partidos[i];
                final isLast = i == jornada.partidos.length - 1;
                return Column(
                  children: [
                    _buildHeroMatchRow(p),
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
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MATCH ROW dentro del Hero ───────────────────────────────────────────
  Widget _buildHeroMatchRow(Partido p) {
    final hasResult = p.tieneResultado;
    final score = hasResult
        ? '${p.golesEquipo1}–${p.golesEquipo2}'
        : (p.fecha != null ? _buildFechaPartido(p) : 'VS');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // Equipo 1
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

          // Marcador / fecha
          Container(
            width: 72,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: hasResult ? _P.greenLight : _P.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasResult ? _P.green.withOpacity(0.35) : _P.border,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              score,
              style: _ts(
                size: hasResult ? 14 : 11,
                weight: FontWeight.w700,
                color: hasResult ? _P.green : _P.slate,
              ),
            ),
          ),

          // Equipo 2
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

  // ─── MATCHDAY CARD (compact) ────────────────────────────────────────────
  Widget _buildMatchdayCard(Jornada jornada) {
    final isExpanded = _expandedMatchdayId == jornada.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedMatchdayId = isExpanded ? null : jornada.id;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Number badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _P.blueLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${jornada.numero}',
                      style: _ts(
                        size: 16,
                        weight: FontWeight.w700,
                        color: _P.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jornada ${jornada.numero}',
                          style: _ts(size: 14, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${jornada.partidos.length} partidos',
                          style: _ts(size: 12, color: _P.slate),
                        ),
                      ],
                    ),
                  ),

                  // Edit button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditMatchdayScreen(
                              matchdayId: jornada.id,
                              matchdayNumber: jornada.numero,
                            ),
                          ),
                        );
                        _firestoreService.invalidatePartidosCache(jornada.id);
                        _loadMatchdays();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit_rounded,
                          color: _P.blue,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _P.slate,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Offstage(
              offstage: !isExpanded,
              child: Column(
                children: [
                  Divider(
                    height: 0,
                    thickness: 0.5,
                    color: _P.border,
                    indent: 14,
                    endIndent: 14,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: jornada.partidos
                          .map((p) => _buildMatchRow(p))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MATCH ROW (inside expandable card) ─────────────────────────────────
  Widget _buildMatchRow(Partido p) {
    final score = p.tieneResultado
        ? '${p.golesEquipo1} – ${p.golesEquipo2}'
        : 'VS';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Team 1
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

          // Score pill
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

          // Team 2
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

  // ─── SECTION HEADER ────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(title, style: _ts(size: 16, weight: FontWeight.w700));
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────
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
              'Sin jornadas registradas',
              style: _ts(size: 15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Crea una jornada nueva para\ncomenzar a registrar partidos.',
              textAlign: TextAlign.center,
              style: _ts(size: 13, color: _P.slate, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────
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

  String _buildFechaPartido(Partido p) {
    if (p.fecha == null) return '—';
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
    return '$dia ${d.day} $mes';
  }
}

// ============================================================================
// DOWNLOAD DIALOG
// ============================================================================

class _DownloadDialog extends StatefulWidget {
  final List<Jornada> matchdays;
  const _DownloadDialog({required this.matchdays});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  bool _isFullMatchday = true;
  String? _selectedMatchdayId;
  int? _selectedMatchIndex;
  bool _useBackgroundImage = false;
  File? _selectedImage;
  bool _isGenerating = false;
  Uint8List? _previewImageBytes;
  bool _isGeneratingPreview = false;

  final Map<String, ui.Image> _imagePool = {};

  @override
  void initState() {
    super.initState();
    if (widget.matchdays.isNotEmpty) {
      _selectedMatchdayId = widget.matchdays.first.id;
    }
  }

  Jornada get _selectedMatchday => widget.matchdays.firstWhere(
    (m) => m.id == _selectedMatchdayId,
    orElse: () => widget.matchdays.first,
  );

  Future<ui.Image?> _getImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (_imagePool.containsKey(url)) return _imagePool[url];

    try {
      final response = await HttpClient().getUrl(Uri.parse(url));
      final bytes = await response
          .close()
          .then((res) => res.toList())
          .then(
            (chunks) => Uint8List.fromList(chunks.expand((x) => x).toList()),
          );
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _imagePool[url] = frame.image;
      return frame.image;
    } catch (e) {
      debugPrint('Error cargando imagen: $url — $e');
      return null;
    }
  }

  Future<void> _preloadMatchdayLogos() async {
    final urls = _selectedMatchday.partidos
        .expand((p) => [p.equipo1LogoUrl, p.equipo2LogoUrl])
        .whereType<String>()
        .where((url) => url.isNotEmpty && !_imagePool.containsKey(url))
        .toSet();

    if (urls.isEmpty) return;
    await Future.wait(urls.map(_getImage));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _previewImageBytes = null;
      });
    }
  }

  Future<void> _generatePreview() async {
    if (_isGeneratingPreview) return;
    setState(() {
      _isGeneratingPreview = true;
      _previewImageBytes = null;
    });

    try {
      await _preloadMatchdayLogos();
      final imageBytes = _isFullMatchday
          ? await _generateFullMatchdayImage()
          : await _generateSingleMatchImage();

      if (mounted) {
        setState(() {
          _previewImageBytes = imageBytes;
          _isGeneratingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPreview = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando vista previa: $e'),
            backgroundColor: _P.red,
          ),
        );
      }
    }
  }

  Future<void> _generateAndDownload() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      var status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
        if (!status.isGranted) throw Exception('Permiso denegado');
      }

      await _preloadMatchdayLogos();
      final imageBytes =
          _previewImageBytes ??
          (_isFullMatchday
              ? await _generateFullMatchdayImage()
              : await _generateSingleMatchImage());

      if (imageBytes != null) {
        await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: 'jornada_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imagen guardada en la galería',
                style: _ts(color: Colors.white, size: 13),
              ),
              backgroundColor: _P.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _P.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ─── Image Generation ──────────────────────────────────────────────────

  Future<Uint8List?> _generateFullMatchdayImage() async {
    final jornada = _selectedMatchday;
    final partidos = jornada.partidos;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(1080, 200 + (partidos.length * 140).toDouble());

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1e3a5f), Color(0xFF0d1f3d)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'JORNADA ${jornada.numero}',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(
      canvas,
      Offset((size.width - titlePainter.width) / 2, 40),
    );

    double yOffset = 140;
    for (final partido in partidos) {
      await _drawMatch(canvas, partido, yOffset, size.width);
      yOffset += 140;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<Uint8List?> _generateSingleMatchImage() async {
    final partido = _selectedMatchday.partidos[_selectedMatchIndex!];

    if (_useBackgroundImage && _selectedImage != null) {
      return _generateMatchWithBackground(partido);
    }
    return _generateMatchSimple(partido, _selectedMatchday.numero);
  }

  Future<Uint8List?> _generateMatchWithBackground(Partido partido) async {
    final bgImageBytes = await _selectedImage!.readAsBytes();
    final codec = await ui.instantiateImageCodec(bgImageBytes);
    final frame = await codec.getNextFrame();
    final bgImage = frame.image;

    final isVertical = bgImage.height > bgImage.width;
    final width = bgImage.width.toDouble();
    final height = bgImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(bgImage, Offset.zero, Paint());

    final goles1 = partido.golesEquipo1?.toString() ?? '0';
    final goles2 = partido.golesEquipo2?.toString() ?? '0';

    final team1Logo = await _getImage(partido.equipo1LogoUrl);
    final team2Logo = await _getImage(partido.equipo2LogoUrl);

    final scorers1 = _buildScorersList(partido.goleadoresEquipo1);
    final scorers2 = _buildScorersList(partido.goleadoresEquipo2);

    if (isVertical) {
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
          stops: const [0.3, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, width, height));
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), gradientPaint);

      final logoSize = width * 0.133;
      final scoreFontSize = width * 0.356;
      final leagueLogoSize = width * 0.124;
      final logoYOffset = height * 0.75;
      final scorersStartY = height * 0.88;
      final leagueLogoY = height * 0.03;
      final logoXSpacing = width * 0.15;
      final extraSpacingPerDigit = width * 0.044;

      try {
        final ByteData data = await rootBundle.load('assets/images/logo_p.png');
        final Uint8List bytes = data.buffer.asUint8List();
        final c = await ui.instantiateImageCodec(bytes);
        final f = await c.getNextFrame();
        _drawCircularLogo(
          canvas,
          f.image,
          Offset((width - leagueLogoSize) / 2, leagueLogoY),
          leagueLogoSize,
        );
      } catch (e) {
        debugPrint('Error cargando logo de la liga: $e');
      }

      final centerY = logoYOffset;
      final leftX = (width / 2) - logoXSpacing;
      final rightX = (width / 2) + logoXSpacing;

      final score1Painter = TextPainter(
        text: TextSpan(
          text: goles1,
          style: TextStyle(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamily: 'monospace',
            shadows: [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, height * 0.0015),
                blurRadius: height * 0.003,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      score1Painter.layout();

      final score2Painter = TextPainter(
        text: TextSpan(
          text: goles2,
          style: TextStyle(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamily: 'monospace',
            shadows: [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, height * 0.0015),
                blurRadius: height * 0.003,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      score2Painter.layout();

      final maxDigits = goles1.length > goles2.length
          ? goles1.length
          : goles2.length;
      final extraSpacing = maxDigits > 1
          ? (maxDigits - 1) * extraSpacingPerDigit
          : 0.0;
      final dividerClearance = maxDigits > 1 ? width * 0.036 : 0.0;

      final adjustedLeftX = leftX - extraSpacing - dividerClearance;
      final adjustedRightX = rightX + extraSpacing + dividerClearance;

      score1Painter.paint(
        canvas,
        Offset(
          adjustedLeftX - (score1Painter.width / 2),
          centerY - (score1Painter.height / 2),
        ),
      );
      score2Painter.paint(
        canvas,
        Offset(
          adjustedRightX - (score2Painter.width / 2),
          centerY - (score2Painter.height / 2),
        ),
      );

      final dividerPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.8),
                Colors.white.withOpacity(0.8),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ).createShader(
              Rect.fromLTWH(
                (width / 2) - (width * 0.0022),
                centerY - (scoreFontSize * 0.6),
                width * 0.0044,
                scoreFontSize * 1.2,
              ),
            )
        ..strokeWidth = width * 0.0036
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(width / 2, centerY - (scoreFontSize * 0.6)),
        Offset(width / 2, centerY + (scoreFontSize * 0.6)),
        dividerPaint,
      );

      final logoTopOffset = width * 0.2;
      if (team1Logo != null) {
        _drawCircularLogo(
          canvas,
          team1Logo,
          Offset(
            adjustedLeftX - (logoSize / 2),
            centerY - logoSize - logoTopOffset,
          ),
          logoSize,
        );
      }
      if (team2Logo != null) {
        _drawCircularLogo(
          canvas,
          team2Logo,
          Offset(
            adjustedRightX - (logoSize / 2),
            centerY - logoSize - logoTopOffset,
          ),
          logoSize,
        );
      }

      if (scorers1.isNotEmpty) {
        _drawScorersVertical(
          canvas,
          scorers1,
          adjustedLeftX,
          scorersStartY,
          true,
          width,
          height,
        );
      }
      if (scorers2.isNotEmpty) {
        _drawScorersVertical(
          canvas,
          scorers2,
          adjustedRightX,
          scorersStartY,
          false,
          width,
          height,
        );
      }
    } else {
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
          stops: const [0.20, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, width, height));
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), gradientPaint);

      final teamLogoSize = width * 0.15;
      final leagueLogoSize = width * 0.08;
      final scoreFontSize = width * 0.15;

      // Fila 1: equipo 1 — centrada verticalmente en height * 0.33
      // Fila 2: equipo 2 — centrada verticalmente en height * 0.67
      final row1CenterY = height * 0.33;
      final row2CenterY = height * 0.67;

      // X del centro del logo
      final logoX = width * 0.08;
      // X donde empieza el score (a la derecha del logo + margen)
      final scoreX = logoX + teamLogoSize + width * 0.03;

      // ── Gradientes azules por fila ─────────────────────────────────
      final gradientBoxWidth = width * 0.48;
      final gradientBoxHeight = height * 0.30;
      final gradientBoxRadius = width * 0.02;
      final gradientColor2 = const Color.fromARGB(
        255,
        58,
        125,
        219,
      ).withOpacity(0.4);

      void drawGradientBox(double centerY) {
        final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            0,
            centerY - gradientBoxHeight / 2,
            gradientBoxWidth,
            gradientBoxHeight,
          ),
          Radius.circular(gradientBoxRadius),
        );
        canvas.drawRRect(
          box,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [gradientColor2, Colors.transparent],
              stops: const [0.8, 1.0],
            ).createShader(box.outerRect),
        );
      }

      drawGradientBox(row1CenterY);
      drawGradientBox(row2CenterY);

      // ── Logo liga (derecha, centrado verticalmente) ────────────────
      final leagueLogoX = width * 0.95;
      final leagueLogoY = height * 0.50;

      final leagueBox = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          width - width * 0.10,
          leagueLogoY - height * 0.20 / 2,
          width * 0.10,
          height * 0.20,
        ),
        Radius.circular(width * 0.01),
      );
      canvas.drawRRect(
        leagueBox,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              const Color.fromARGB(255, 27, 94, 32).withOpacity(0.6),
            ],
            stops: const [0.0, 0.7],
          ).createShader(leagueBox.outerRect),
      );

      // ── Equipo 1 ───────────────────────────────────────────────────
      if (team1Logo != null) {
        _drawCircularLogo(
          canvas,
          team1Logo,
          Offset(logoX, row1CenterY - teamLogoSize / 2),
          teamLogoSize,
        );
      }

      // Score equipo 1 — alineado verticalmente con el logo
      _paintScore(canvas, goles1, scoreFontSize, scoreX, row1CenterY, height);

      // ── Equipo 2 ───────────────────────────────────────────────────
      if (team2Logo != null) {
        _drawCircularLogo(
          canvas,
          team2Logo,
          Offset(logoX, row2CenterY - teamLogoSize / 2),
          teamLogoSize,
        );
      }

      // Score equipo 2 — alineado verticalmente con el logo
      _paintScore(canvas, goles2, scoreFontSize, scoreX, row2CenterY, height);

      // ── Logo liga ──────────────────────────────────────────────────
      try {
        final ByteData data = await rootBundle.load('assets/images/logo_p.png');
        final Uint8List bytes = data.buffer.asUint8List();
        final c = await ui.instantiateImageCodec(bytes);
        final f = await c.getNextFrame();
        _drawCircularLogo(
          canvas,
          f.image,
          Offset(
            leagueLogoX - leagueLogoSize / 2,
            leagueLogoY - leagueLogoSize / 2,
          ),
          leagueLogoSize,
        );
      } catch (e) {
        debugPrint('Error cargando logo de la liga: $e');
      }
    }

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData?.buffer.asUint8List();
  }

  List<Map<String, dynamic>> _buildScorersList(List<Goleador> goleadores) {
    return goleadores.map((g) => {'name': g.nombre, 'goals': g.goles}).toList();
  }

  void _paintScore(
    Canvas canvas,
    String score,
    double fontSize,
    double x,
    double y,
    double imageHeight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: score,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontFamily: 'monospace',
          shadows: [
            Shadow(
              color: Colors.black87,
              offset: Offset(0, imageHeight * 0.004),
              blurRadius: imageHeight * 0.008,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset(x, y - (painter.height / 2)));
  }

  Future<Uint8List?> _generateMatchSimple(
    Partido partido,
    int matchdayNumber,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 1080.0;
    const height = 1080.0;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1e3a5f), Color(0xFF0d1f3d)],
      ).createShader(const Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'JORNADA $matchdayNumber',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, 80));

    final team1Logo = await _getImage(partido.equipo1LogoUrl);
    final team2Logo = await _getImage(partido.equipo2LogoUrl);

    const logoSize = 150.0;
    const centerY = 350.0;
    const team1XPercent = 0.25;
    const team2XPercent = 0.75;

    if (team1Logo != null) {
      _drawCircularLogo(
        canvas,
        team1Logo,
        const Offset((width * team1XPercent) - (logoSize / 2), centerY),
        logoSize,
      );
    }
    if (team2Logo != null) {
      _drawCircularLogo(
        canvas,
        team2Logo,
        const Offset((width * team2XPercent) - (logoSize / 2), centerY),
        logoSize,
      );
    }

    void paintTeamName(String name, double xPercent) {
      final p = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      p.layout(maxWidth: 300);
      p.paint(
        canvas,
        Offset((width * xPercent) - (p.width / 2), centerY + logoSize + 20),
      );
    }

    paintTeamName(partido.equipo1Nombre, team1XPercent);
    paintTeamName(partido.equipo2Nombre, team2XPercent);

    if (partido.tieneResultado) {
      final scorePainter = TextPainter(
        text: TextSpan(
          text: '${partido.golesEquipo1} - ${partido.golesEquipo2}',
          style: const TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w900,
            color: Color(0xFF00d9ff),
            fontFamily: 'monospace',
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      scorePainter.layout();
      scorePainter.paint(
        canvas,
        Offset((width - scorePainter.width) / 2, centerY + (logoSize / 2) - 48),
      );
    } else {
      _drawVsOrDate(canvas, partido, width, centerY + (logoSize / 2));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _drawVsOrDate(
    Canvas canvas,
    Partido partido,
    double width,
    double centerY,
  ) {
    if (partido.fecha != null) {
      try {
        final months = [
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
        final dateStr =
            '${partido.fecha!.day} ${months[partido.fecha!.month - 1]}';
        final timeStr = (partido.hora != null && partido.hora!.isNotEmpty)
            ? partido.hora!
            : '00:00';

        final datePainter = TextPainter(
          text: TextSpan(
            text: dateStr,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        datePainter.layout();
        datePainter.paint(
          canvas,
          Offset((width - datePainter.width) / 2, centerY - 60),
        );

        final timePainter = TextPainter(
          text: TextSpan(
            text: timeStr,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00d9ff),
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        timePainter.layout();
        timePainter.paint(
          canvas,
          Offset((width - timePainter.width) / 2, centerY - 5),
        );
        return;
      } catch (_) {}
    }

    final vsPainter = TextPainter(
      text: const TextSpan(
        text: 'VS',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w900,
          color: Colors.white70,
          letterSpacing: 8,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    vsPainter.layout();
    vsPainter.paint(
      canvas,
      Offset((width - vsPainter.width) / 2, centerY - 36),
    );
  }

  void _drawCircularLogo(
    Canvas canvas,
    ui.Image logo,
    Offset position,
    double size,
  ) {
    canvas.save();
    final path = Path()
      ..addOval(Rect.fromLTWH(position.dx, position.dy, size, size));
    canvas.clipPath(path);
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromLTWH(position.dx, position.dy, size, size),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(position.dx + size / 2, position.dy + size / 2),
      size / 2,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _drawSoccerBall(
    Canvas canvas,
    Offset position,
    double size,
    double imageWidth,
  ) {
    final radius = size / 2;
    final borderWidth = size * 0.075;
    final lineWidth = size * 0.075;
    const hexagonSize = 0.45;

    canvas.drawCircle(position, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      position,
      radius,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    final pentagonRadius = radius * hexagonSize;
    final pentagonPath = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi / 5) - (pi / 2);
      final x = position.dx + pentagonRadius * cos(angle);
      final y = position.dy + pentagonRadius * sin(angle);
      i == 0 ? pentagonPath.moveTo(x, y) : pentagonPath.lineTo(x, y);
    }
    pentagonPath.close();
    canvas.drawPath(pentagonPath, Paint()..color = Colors.black);

    final linePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi / 5) - (pi / 2);
      canvas.drawLine(
        Offset(
          position.dx + pentagonRadius * cos(angle),
          position.dy + pentagonRadius * sin(angle),
        ),
        Offset(
          position.dx + radius * 0.9 * cos(angle),
          position.dy + radius * 0.9 * sin(angle),
        ),
        linePaint,
      );
    }
  }

  double _drawScorersVertical(
    Canvas canvas,
    List<Map<String, dynamic>> scorers,
    double centerX,
    double startY,
    bool isLeftSide,
    double imageWidth,
    double imageHeight,
  ) {
    final ballSize = imageWidth * 0.0178;
    final spacing = imageWidth * 0.0053;
    final nameFontSize = imageWidth * 0.0222;
    final verticalSpacing = imageWidth * 0.0311;
    final horizontalPadding = imageWidth * 0.0133;
    final nameMinWidth = imageWidth * 0.20;

    double currentY = startY;

    for (var scorer in scorers) {
      final name = scorer['name'] as String;
      final goals = scorer['goals'] as int;

      final namePainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontSize: nameFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      namePainter.layout();

      double nameX;
      double ballX;

      if (isLeftSide) {
        nameX = centerX - nameMinWidth;
        namePainter.paint(canvas, Offset(nameX, currentY));
        ballX = centerX - nameMinWidth + nameMinWidth + horizontalPadding;
      } else {
        ballX =
            centerX -
            horizontalPadding -
            (goals * ballSize + (goals - 1) * spacing);
        nameX = centerX + horizontalPadding;
        namePainter.paint(canvas, Offset(nameX, currentY));
      }

      final nameCenterY = currentY + (namePainter.height / 2);
      final ballCenterY = nameCenterY - (ballSize / 2);

      for (int i = 0; i < goals; i++) {
        _drawSoccerBall(
          canvas,
          Offset(ballX + (ballSize / 2), ballCenterY + (ballSize / 2)),
          ballSize,
          imageWidth,
        );
        ballX += ballSize + spacing;
      }

      currentY += verticalSpacing;
    }

    return currentY;
  }

  Future<void> _drawMatch(
    Canvas canvas,
    Partido partido,
    double yOffset,
    double width,
  ) async {
    final team1Logo = await _getImage(partido.equipo1LogoUrl);
    final team2Logo = await _getImage(partido.equipo2LogoUrl);

    const logoSize = 60.0;
    const logoYOffset = 20.0;
    const nameXOffset = 20.0;
    const scoreYOffset = 32.0;
    const team1LogoX = 200.0;
    const team2LogoX = 140.0;
    const teamNameFontSize = 20.0;
    const scoreFontSize = 36.0;

    final centerX = width / 2;

    if (team1Logo != null) {
      _drawCircularLogo(
        canvas,
        team1Logo,
        Offset(centerX - team1LogoX, yOffset + logoYOffset),
        logoSize,
      );
    }

    final team1NamePainter = TextPainter(
      text: TextSpan(
        text: partido.equipo1Nombre,
        style: const TextStyle(
          fontSize: teamNameFontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    team1NamePainter.layout();
    team1NamePainter.paint(
      canvas,
      Offset(
        centerX - team1LogoX - team1NamePainter.width - nameXOffset,
        yOffset + logoYOffset + (logoSize / 2) - (team1NamePainter.height / 2),
      ),
    );

    if (partido.tieneResultado) {
      final scorePainter = TextPainter(
        text: TextSpan(
          text: '${partido.golesEquipo1} - ${partido.golesEquipo2}',
          style: const TextStyle(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.w900,
            color: Color(0xFF00d9ff),
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      scorePainter.layout();
      scorePainter.paint(
        canvas,
        Offset(centerX - (scorePainter.width / 2), yOffset + scoreYOffset),
      );
    } else {
      _drawVsOrDateCanvas(canvas, partido, centerX, yOffset + scoreYOffset);
    }

    if (team2Logo != null) {
      _drawCircularLogo(
        canvas,
        team2Logo,
        Offset(centerX + team2LogoX, yOffset + logoYOffset),
        logoSize,
      );
    }

    final team2NamePainter = TextPainter(
      text: TextSpan(
        text: partido.equipo2Nombre,
        style: const TextStyle(
          fontSize: teamNameFontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    team2NamePainter.layout();
    team2NamePainter.paint(
      canvas,
      Offset(
        centerX + team2LogoX + logoSize + nameXOffset,
        yOffset + logoYOffset + (logoSize / 2) - (team2NamePainter.height / 2),
      ),
    );
  }

  void _drawVsOrDateCanvas(
    Canvas canvas,
    Partido partido,
    double centerX,
    double y,
  ) {
    if (partido.fecha != null) {
      try {
        final months = [
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
        final dateStr =
            '${partido.fecha!.day} ${months[partido.fecha!.month - 1]}';
        final timeStr = (partido.hora != null && partido.hora!.isNotEmpty)
            ? partido.hora!
            : '00:00';

        final datePainter = TextPainter(
          text: TextSpan(
            text: dateStr,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        datePainter.layout();
        datePainter.paint(canvas, Offset(centerX - (datePainter.width / 2), y));

        final timePainter = TextPainter(
          text: TextSpan(
            text: timeStr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00d9ff),
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        timePainter.layout();
        timePainter.paint(
          canvas,
          Offset(centerX - (timePainter.width / 2), y + 25),
        );
        return;
      } catch (_) {}
    }

    final vsPainter = TextPainter(
      text: const TextSpan(
        text: 'VS',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.white70,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    vsPainter.layout();
    vsPainter.paint(canvas, Offset(centerX - (vsPainter.width / 2), y + 5));
  }

  // ─── DIALOG BUILD ──────────────────────────────────────────────────────

  bool get _canGeneratePreview =>
      _isFullMatchday ||
      (!_isFullMatchday &&
          _selectedMatchIndex != null &&
          (!_useBackgroundImage || _selectedImage != null));

  @override
  Widget build(BuildContext context) {
    final partidos = _selectedMatchday.partidos;

    return Dialog(
      backgroundColor: _P.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _P.border, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      Icons.download_rounded,
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
                          'Descargar',
                          style: _ts(size: 16, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exporta en imagen',
                          style: _ts(size: 11, color: _P.slate),
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
            ),

            Divider(
              height: 0,
              thickness: 0.5,
              color: _P.border,
              indent: 14,
              endIndent: 14,
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type selection
                  Text(
                    'Tipo',
                    style: _ts(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _P.slate,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeOption(
                          'Jornada completa',
                          _isFullMatchday,
                          () => setState(() {
                            _isFullMatchday = true;
                            _useBackgroundImage = false;
                            _selectedImage = null;
                            _previewImageBytes = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypeOption(
                          'Un partido',
                          !_isFullMatchday,
                          () => setState(() {
                            _isFullMatchday = false;
                            _previewImageBytes = null;
                          }),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Matchday selector
                  Text(
                    'Jornada',
                    style: _ts(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _P.slate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown<String>(
                    value: _selectedMatchdayId,
                    items: widget.matchdays
                        .map(
                          (j) => DropdownMenuItem(
                            value: j.id,
                            child: Text('Jornada ${j.numero}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedMatchdayId = value;
                      _selectedMatchIndex = null;
                      _previewImageBytes = null;
                    }),
                  ),

                  if (!_isFullMatchday) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Partido',
                      style: _ts(
                        size: 13,
                        weight: FontWeight.w600,
                        color: _P.slate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown<int>(
                      value: _selectedMatchIndex,
                      items: List.generate(partidos.length, (i) {
                        final p = partidos[i];
                        return DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${p.equipo1Nombre} vs ${p.equipo2Nombre}',
                          ),
                        );
                      }),
                      onChanged: (value) => setState(() {
                        _selectedMatchIndex = value;
                        _previewImageBytes = null;
                      }),
                    ),

                    const SizedBox(height: 18),

                    // Background toggle
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _useBackgroundImage,
                            onChanged: (value) => setState(() {
                              _useBackgroundImage = value!;
                              _previewImageBytes = null;
                            }),
                            fillColor: WidgetStateProperty.all(_P.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Usar fondo personalizado',
                          style: _ts(size: 13, weight: FontWeight.w500),
                        ),
                      ],
                    ),

                    if (_useBackgroundImage) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: _P.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _P.border, width: 0.5),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: _P.slate,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Selecciona una imagen',
                                        style: _ts(size: 12, color: _P.slate),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 18),

                  // Preview button
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _canGeneratePreview && !_isGeneratingPreview
                            ? _generatePreview
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _P.blueLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _P.blue.withOpacity(0.25),
                              width: 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _isGeneratingPreview
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color: _P.blue,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Vista previa',
                                  style: _ts(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: _P.blue,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // Preview image
                  if (_previewImageBytes != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: _P.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _P.border, width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _previewImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Divider(
              height: 0,
              thickness: 0.5,
              color: _P.border,
              indent: 14,
              endIndent: 14,
            ),

            // Footer buttons
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isGenerating
                            ? null
                            : () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                        onTap: _isGenerating || !_canGeneratePreview
                            ? null
                            : _generateAndDownload,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _P.blue,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _P.blue.withOpacity(0.25),
                              width: 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _isGenerating
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Descargar',
                                  style: _ts(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
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
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTypeOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _P.blueLight : _P.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _P.blue : _P.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: _ts(
            size: 12,
            weight: FontWeight.w600,
            color: selected ? _P.blue : _P.navy,
          ),
        ),
      ),
    );
  }
}
