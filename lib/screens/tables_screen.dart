import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/equipo_model.dart';
import '../models/jugador_model.dart';
import '../models/jornada_model.dart';
import 'dart:typed_data';
import '../screens/liguilla_bracket_screen.dart';

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
  static const amber = Color(0xFFF39C12);
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

// ─── SCREEN ────────────────────────────────────────────────────────────────
class TablesScreen extends StatefulWidget {
  final bool showStandings;
  const TablesScreen({super.key, this.showStandings = true});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen>
    with SingleTickerProviderStateMixin {
  late bool _showStandings;
  List<Equipo> _teams = [];
  List<Jugador> _scorers = [];
  Map<String, List<String>> _lastResults = {};
  bool _isLoading = true;
  bool _isGeneratingImage = false;
  late AnimationController _fadeCtrl;

  // Un solo ScrollController horizontal — igual que el original
  final ScrollController _scrollController = ScrollController();

  final FirestoreService _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _showStandings = widget.showStandings;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _service.currentSeasonId.addListener(_onSeasonChanged);
    _loadData();
  }

  @override
  void dispose() {
    _service.currentSeasonId.removeListener(_onSeasonChanged);
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onSeasonChanged() => _loadData();

  Future<void> _loadData() async {
    if (_service.currentSeasonId.value == null) {
      setState(() {
        _teams = [];
        _scorers = [];
        _lastResults = {};
        _isLoading = false;
      });
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    _fadeCtrl.reset();
    if (_showStandings)
      await _loadStandings();
    else
      await _loadScorers();
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadStandings() async {
    try {
      final results = await Future.wait([
        _service.getEquipos(),
        _service.loadJornadasConPartidos(),
      ]);
      final teams = results[0] as List<Equipo>;
      final jornadas = results[1] as List<Jornada>;
      final Map<String, List<String>> last = {};
      for (final e in teams)
        last[e.id] = _service.getUltimos5(equipoId: e.id, jornadas: jornadas);
      if (mounted)
        setState(() {
          _teams = teams;
          _lastResults = last;
        });
    } catch (e) {
      debugPrint('❌ standings: $e');
    }
  }

  Future<void> _loadScorers() async {
    try {
      final s = await _service.getGoleadores();
      if (mounted) setState(() => _scorers = s);
    } catch (e) {
      debugPrint('❌ scorers: $e');
    }
  }

  void _switchTab(bool standings) {
    if (_showStandings == standings) return;
    setState(() => _showStandings = standings);
    _loadData();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _ts(color: Colors.white, size: 13)),
        backgroundColor: isError ? _P.red : _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── DOWNLOAD ──────────────────────────────────────────────────────────
  Future<void> _downloadTableImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _P.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _P.border, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
                          'Descargar tabla',
                          style: _ts(size: 15, weight: FontWeight.w700),
                        ),
                        Text(
                          'Exportar como imagen',
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
                    onTap: () => Navigator.pop(ctx, false),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'Se guardará la ${_showStandings ? "tabla de posiciones" : "tabla de goleadores"} completa en tu galería.',
                style: _ts(size: 13, color: _P.slate, height: 1.6),
              ),
            ),
            const SizedBox(height: 6),
            const Divider(height: 0, thickness: 0.5, color: _P.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: _footerBtn(
                      label: 'Cancelar',
                      filled: false,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _footerBtn(
                      label: 'Descargar',
                      filled: true,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _isGeneratingImage = true);
    try {
      var status = await Permission.photos.status;
      if (!status.isGranted) status = await Permission.photos.request();
      if (!status.isGranted) status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnack('Se requieren permisos de almacenamiento', isError: true);
        return;
      }

      final bytes = _showStandings
          ? await _generateStandingsImage()
          : await _generateScorersImage();
      await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'tabla_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) _showSnack('Imagen guardada en la galería');
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }

  // ─── IMAGE GENERATION: POSICIONES ──────────────────────────────────────
  Future<Uint8List> _generateStandingsImage() async {
    const double W = 1080, rowH = 72, headerH = 56, topH = 180;
    final double H = topH + headerH + (_teams.length * rowH) + 40;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _fillRect(canvas, 0, 0, W, H, _P.bg);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, W, 130),
      Paint()..color = _P.green,
    );
    _drawText(
      canvas,
      'TABLA DE POSICIONES',
      x: 56,
      y: 32,
      size: 42,
      weight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 2,
    );

    final now = DateTime.now();
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
    _drawText(
      canvas,
      '${now.day} ${meses[now.month - 1]} ${now.year}',
      x: 56,
      y: 84,
      size: 22,
      weight: FontWeight.w500,
      color: Colors.white.withOpacity(0.80),
    );
    _drawRRect(
      canvas,
      W - 220,
      38,
      164,
      50,
      12,
      color: Colors.white.withOpacity(0.18),
    );
    _drawText(
      canvas,
      '${_teams.length} equipos',
      x: W - 212,
      y: 54,
      size: 22,
      weight: FontWeight.w700,
      color: Colors.white,
    );

    final curvePath = Path()
      ..moveTo(0, 110)
      ..quadraticBezierTo(W / 2, 160, W, 110)
      ..lineTo(W, 130)
      ..lineTo(0, 130)
      ..close();
    canvas.drawPath(curvePath, Paint()..color = _P.bg);

    const double tableY = topH;
    _fillRect(canvas, 24, tableY, W - 48, headerH, _P.navy);

    const cols = [
      '#',
      'EQUIPO',
      'PTS',
      'PJ',
      'PG',
      'PE',
      'PP',
      'GF',
      'GC',
      'DG',
    ];
    final colW = [54.0, 340.0, 82.0, 72.0, 72.0, 72.0, 72.0, 72.0, 72.0, 72.0];
    double xc = 24;
    for (int i = 0; i < cols.length; i++) {
      _drawTextCentered(
        canvas,
        cols[i],
        x: xc,
        y: tableY + 17,
        w: colW[i],
        size: 15,
        weight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.8,
      );
      xc += colW[i];
    }
    for (int i = 0; i < _teams.length; i++) {
      final t = _teams[i];
      final double ry = tableY + headerH + (i * rowH);
      _fillRect(
        canvas,
        24,
        ry,
        W - 48,
        rowH,
        i % 2 == 0 ? _P.surface : const Color(0xFFF7F8FA),
      );
      canvas.drawLine(
        Offset(24, ry + rowH),
        Offset(W - 24, ry + rowH),
        Paint()
          ..color = _P.border
          ..strokeWidth = 0.5,
      );
      if (i < 3) {
        final c = i == 0
            ? _P.amber
            : i == 1
            ? const Color(0xFFAAAAAA)
            : const Color(0xFFCD7F32);
        _fillRect(canvas, 24, ry, 6, rowH, c);
      }
      xc = 24;
      _drawTextCentered(
        canvas,
        '${i + 1}',
        x: xc,
        y: ry + 22,
        w: colW[0],
        size: 18,
        weight: FontWeight.w800,
        color: i < 3 ? _P.navy : _P.slate,
      );
      xc += colW[0];
      _drawText(
        canvas,
        t.nombre,
        x: xc + 10,
        y: ry + 22,
        size: 18,
        weight: FontWeight.w700,
        color: _P.navy,
        maxWidth: colW[1] - 20,
      );
      xc += colW[1];
      final stats = [
        '${t.pts}',
        '${t.pj}',
        '${t.pg}',
        '${t.pe}',
        '${t.pp}',
        '${t.gf}',
        '${t.gc}',
        t.dg >= 0 ? '+${t.dg}' : '${t.dg}',
      ];
      for (int s = 0; s < stats.length; s++) {
        final isPts = s == 0;
        if (isPts)
          _drawRRect(
            canvas,
            xc + 16,
            ry + 16,
            colW[s + 2] - 32,
            40,
            8,
            color: _P.blueLight,
          );
        _drawTextCentered(
          canvas,
          stats[s],
          x: xc,
          y: ry + 22,
          w: colW[s + 2],
          size: isPts ? 18 : 16,
          weight: isPts ? FontWeight.w800 : FontWeight.w600,
          color: isPts ? _P.blue : _P.navy,
        );
        xc += colW[s + 2];
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, tableY, W - 48, headerH + (_teams.length * rowH)),
        const Radius.circular(12),
      ),
      Paint()
        ..color = _P.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final pic = recorder.endRecording();
    final img = await pic.toImage(W.toInt(), H.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  // ─── IMAGE GENERATION: GOLEADORES ──────────────────────────────────────
  Future<Uint8List> _generateScorersImage() async {
    const double W = 1080, cardH = 88, gap = 8, topH = 180;
    final display = _scorers.take(20).toList();
    final double H = topH + (display.length * (cardH + gap)) + 40;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _fillRect(canvas, 0, 0, W, H, _P.bg);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, W, 130),
      Paint()..color = _P.blue,
    );
    _drawText(
      canvas,
      'TABLA DE GOLEADORES',
      x: 56,
      y: 32,
      size: 42,
      weight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 2,
    );
    final now = DateTime.now();
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
    _drawText(
      canvas,
      '${now.day} ${meses[now.month - 1]} ${now.year}',
      x: 56,
      y: 84,
      size: 22,
      weight: FontWeight.w500,
      color: Colors.white.withOpacity(0.80),
    );
    _drawRRect(
      canvas,
      W - 220,
      38,
      164,
      50,
      12,
      color: Colors.white.withOpacity(0.18),
    );
    _drawText(
      canvas,
      'Top ${display.length}',
      x: W - 212,
      y: 54,
      size: 22,
      weight: FontWeight.w700,
      color: Colors.white,
    );
    final curvePath = Path()
      ..moveTo(0, 110)
      ..quadraticBezierTo(W / 2, 160, W, 110)
      ..lineTo(W, 130)
      ..lineTo(0, 130)
      ..close();
    canvas.drawPath(curvePath, Paint()..color = _P.bg);

    double y = topH;
    for (int i = 0; i < display.length; i++) {
      final sc = display[i];
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(24, y, W - 48, cardH),
        const Radius.circular(12),
      );
      canvas.drawRRect(rr, Paint()..color = _P.surface);
      canvas.drawRRect(
        rr,
        Paint()
          ..color = _P.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
      if (i < 3) {
        final c = i == 0
            ? _P.amber
            : i == 1
            ? const Color(0xFFAAAAAA)
            : const Color(0xFFCD7F32);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(24, y, 6, cardH),
            const Radius.circular(12),
          ),
          Paint()..color = c,
        );
      }
      final posColor = i == 0
          ? _P.amber
          : i == 1
          ? const Color(0xFF9E9E9E)
          : i == 2
          ? const Color(0xFFCD7F32)
          : _P.blueLight;
      _drawRRect(canvas, 42, y + 20, 48, 48, 10, color: posColor);
      _drawTextCentered(
        canvas,
        '${i + 1}',
        x: 42,
        y: y + 30,
        w: 48,
        size: 22,
        weight: FontWeight.w800,
        color: i < 3 ? Colors.white : _P.blue,
      );
      _drawText(
        canvas,
        sc.nombre,
        x: 106,
        y: y + 16,
        size: 22,
        weight: FontWeight.w700,
        color: _P.navy,
        maxWidth: W - 340,
      );
      _drawText(
        canvas,
        sc.equipoNombre.isNotEmpty ? sc.equipoNombre : '—',
        x: 106,
        y: y + 48,
        size: 17,
        weight: FontWeight.w500,
        color: _P.slate,
        maxWidth: W - 340,
      );
      _drawRRect(canvas, W - 200, y + 20, 152, 48, 24, color: _P.greenLight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(W - 200, y + 20, 152, 48),
          const Radius.circular(24),
        ),
        Paint()
          ..color = _P.green.withOpacity(0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _drawText(
        canvas,
        '⚽  ${sc.goles} goles',
        x: W - 188,
        y: y + 30,
        size: 20,
        weight: FontWeight.w700,
        color: _P.green,
      );
      y += cardH + gap;
    }
    final pic = recorder.endRecording();
    final img = await pic.toImage(W.toInt(), H.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  // ─── CANVAS HELPERS ────────────────────────────────────────────────────
  void _fillRect(Canvas c, double x, double y, double w, double h, Color col) =>
      c.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = col);

  void _drawRRect(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    double r, {
    required Color color,
  }) => c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
    Paint()..color = color,
  );

  void _drawText(
    Canvas c,
    String text, {
    required double x,
    required double y,
    required double size,
    required FontWeight weight,
    required Color color,
    double maxWidth = 9999,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.dmSans(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(c, Offset(x, y));
  }

  void _drawTextCentered(
    Canvas c,
    String text, {
    required double x,
    required double y,
    required double w,
    required double size,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.dmSans(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: w);
    tp.paint(c, Offset(x + (w - tp.width) / 2, y));
  }

  Widget _footerBtn({
    required String label,
    required bool filled,
    required VoidCallback onTap,
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
          child: Text(
            label,
            style: _ts(
              size: 13,
              weight: FontWeight.w700,
              color: filled ? Colors.white : _P.slate,
            ),
          ),
        ),
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: _P.bg,
        child: SafeArea(
          child: ValueListenableBuilder<String>(
            valueListenable: FirestoreService().faseVista,
            builder: (ctx, fase, _) {
              return Column(
                children: [
                  // Header cambia según la fase
                  fase == 'liguilla' ? _buildHeaderLiguilla() : _buildHeader(),

                  // Tab bar solo en liga
                  if (fase != 'liguilla') _buildTabBar(),

                  // Contenido
                  Expanded(
                    child: fase == 'liguilla'
                        ? LiguillaBracketScreen(
                            key: LiguillaBracketScreen.bracketKey,
                          )
                        : _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _P.blue,
                              strokeWidth: 2.5,
                            ),
                          )
                        : FadeTransition(
                            opacity: _fadeCtrl,
                            child: _showStandings
                                ? _buildStandingsTable()
                                : _buildScorersTable(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLiguilla() {
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
                  'BRACKET',
                  style: _ts(
                    size: 22,
                    weight: FontWeight.w800,
                    letterSpacing: 1.8,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Resultados de la liguilla',
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
            onTap: () => LiguillaBracketScreen.bracketKey.currentState
                ?.descargarBracket(),
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
                  'ESTADÍSTICAS',
                  style: _ts(
                    size: 22,
                    weight: FontWeight.w800,
                    letterSpacing: 1.8,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Posiciones y goleadores',
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
            onTap: _isGeneratingImage ? null : _downloadTableImage,
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
              child: _isGeneratingImage
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        color: _P.blue,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
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

  // ─── TAB BAR ───────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: _P.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: Row(
          children: [
            _tabOption('Posiciones', _showStandings, () => _switchTab(true)),
            _tabOption('Goleadores', !_showStandings, () => _switchTab(false)),
          ],
        ),
      ),
    );
  }

  Widget _tabOption(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? _P.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _ts(
              size: 13,
              weight: FontWeight.w700,
              color: active ? _P.navy : _P.slate,
            ),
          ),
        ),
      ),
    );
  }

  // ─── STANDINGS TABLE ───────────────────────────────────────────────────
  // ESTRUCTURA 100% IGUAL AL ORIGINAL:
  //   SingleChildScrollView  (scroll vertical)
  //   └─ Row
  //       ├─ Column fija  (# + logo + nombre)
  //       └─ Expanded
  //           └─ SingleChildScrollView  (scroll horizontal, _scrollController)
  //               └─ Column  (header stats + filas stats)
  Widget _buildStandingsTable() {
    if (_teams.isEmpty) return _emptyState('Sin equipos registrados');

    return RefreshIndicator(
      color: _P.blue,
      backgroundColor: _P.surface,
      onRefresh: () async {
        _service.invalidateJornadasCache?.call();
        await _loadData();
      },
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Columna FIJA izquierda ─────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header fijo
                Container(
                  width: 200,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _P.navy,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#',
                          style: _ts(
                            size: 11,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EQUIPO',
                        style: _ts(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Filas fijas
                ..._teams.asMap().entries.map((entry) {
                  final i = entry.key;
                  final team = entry.value;
                  final isTop3 = i < 3;
                  final accentColor = i == 0
                      ? _P.amber
                      : i == 1
                      ? const Color(0xFF9E9E9E)
                      : const Color(0xFFCD7F32);

                  return Container(
                    width: 200,
                    height: 56,
                    decoration: BoxDecoration(
                      color: i % 2 == 0 ? _P.surface : const Color(0xFFF7F8FA),
                      border: Border(
                        bottom: BorderSide(color: _P.border, width: 0.5),
                        left: BorderSide(
                          color: isTop3 ? accentColor : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${i + 1}',
                            style: _ts(
                              size: 13,
                              weight: FontWeight.w700,
                              color: isTop3 ? accentColor : _P.slate,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _teamLogo(team.logoUrl),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            team.nombre,
                            style: _ts(size: 13, weight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),

            // ── Columna SCROLLABLE horizontal ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header stats (hace scroll junto con los datos)
                    Container(
                      height: 44,
                      color: _P.navy,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          _statCell('PTS', 50, isHeader: true),
                          _statCell('PJ', 40, isHeader: true),
                          _statCell('PG', 40, isHeader: true),
                          _statCell('PE', 40, isHeader: true),
                          _statCell('PP', 40, isHeader: true),
                          _statCell('GF', 40, isHeader: true),
                          _statCell('GC', 40, isHeader: true),
                          _statCell('DG', 40, isHeader: true),
                          _statCell('Últimos 5', 140, isHeader: true),
                        ],
                      ),
                    ),
                    // Filas stats
                    ..._teams.asMap().entries.map((entry) {
                      final i = entry.key;
                      final team = entry.value;
                      final last = _lastResults[team.id] ?? [];

                      return Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: i % 2 == 0
                              ? _P.surface
                              : const Color(0xFFF7F8FA),
                          border: Border(
                            bottom: BorderSide(color: _P.border, width: 0.5),
                            right: BorderSide(color: _P.border, width: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            // PTS con badge azul
                            SizedBox(
                              width: 50,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _P.blueLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${team.pts}',
                                    style: _ts(
                                      size: 12,
                                      weight: FontWeight.w800,
                                      color: _P.blue,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            _statCell('${team.pj}', 40),
                            _statCell('${team.pg}', 40),
                            _statCell('${team.pe}', 40),
                            _statCell('${team.pp}', 40),
                            _statCell('${team.gf}', 40),
                            _statCell('${team.gc}', 40),
                            _statCell(
                              team.dg >= 0 ? '+${team.dg}' : '${team.dg}',
                              40,
                            ),
                            // Últimos 5 — igual que el original
                            SizedBox(
                              width: 140,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: last.reversed
                                    .map((r) => _resultDot(r))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Celda genérica de stat
  Widget _statCell(String text, double width, {bool isHeader = false}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: _ts(
            size: isHeader ? 10 : 12,
            weight: isHeader ? FontWeight.w700 : FontWeight.w600,
            color: isHeader ? Colors.white70 : _P.navy,
            letterSpacing: isHeader ? 0.5 : 0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ─── SCORERS TABLE ─────────────────────────────────────────────────────
  Widget _buildScorersTable() {
    if (_scorers.isEmpty) return _emptyState('Sin goleadores registrados');

    return RefreshIndicator(
      color: _P.blue,
      backgroundColor: _P.surface,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        itemCount: _scorers.length,
        itemBuilder: (_, i) => _scorerRow(_scorers[i], i),
      ),
    );
  }

  Widget _scorerRow(Jugador sc, int i) {
    final isTop3 = i < 3;
    final badgeColor = i == 0
        ? _P.amber
        : i == 1
        ? const Color(0xFF9E9E9E)
        : i == 2
        ? const Color(0xFFCD7F32)
        : _P.blueLight;
    final badgeTextColor = i < 3 ? Colors.white : _P.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 ? badgeColor.withOpacity(0.40) : _P.border,
          width: isTop3 ? 1 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: _ts(
                size: 14,
                weight: FontWeight.w800,
                color: badgeTextColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _playerPhoto(sc.fotoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sc.nombre,
                  style: _ts(size: 14, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sc.equipoNombre.isNotEmpty ? sc.equipoNombre : '—',
                  style: _ts(
                    size: 11,
                    color: _P.slate,
                    weight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _P.greenLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.green.withOpacity(0.30), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  size: 14,
                  color: _P.green,
                ),
                const SizedBox(width: 5),
                Text(
                  '${sc.goles}',
                  style: _ts(
                    size: 14,
                    weight: FontWeight.w800,
                    color: _P.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED WIDGETS ────────────────────────────────────────────────────
  Widget _teamLogo(String url) {
    if (url.isEmpty) {
      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        child: const Icon(Icons.shield_outlined, color: _P.slate, size: 16),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
          child: const Icon(Icons.shield_outlined, color: _P.slate, size: 16),
        ),
      ),
    );
  }

  Widget _playerPhoto(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        child: const Icon(Icons.person_rounded, color: _P.slate, size: 22),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
          child: const Icon(Icons.person_rounded, color: _P.slate, size: 22),
        ),
      ),
    );
  }

  Widget _resultDot(String r) {
    final color = r == 'W'
        ? _P.green
        : r == 'L'
        ? _P.red
        : _P.slate;
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          r == 'W'
              ? 'G'
              : r == 'L'
              ? 'P'
              : 'E',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String msg) {
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
              Icons.sports_soccer_outlined,
              color: _P.slate,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(msg, style: _ts(size: 15, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
