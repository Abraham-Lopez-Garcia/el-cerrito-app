import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/liguilla_model.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:async';

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
  static const amber = Color(0xFFF39C12);
  static const amberLight = Color(0xFFFEF9ED);
  static const heroDark = Color(0xFF1E3050);
  static const heroMid = Color(0xFF1E3A5F);
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

// ─── CONNECTION MODEL ──────────────────────────────────────────────────────
class _Connection {
  final GlobalKey fromKey;
  final GlobalKey toKey;
  final bool isLeft;
  const _Connection({
    required this.fromKey,
    required this.toKey,
    required this.isLeft,
  });
}

// ─── SCREEN ────────────────────────────────────────────────────────────────
class LiguillaBracketScreen extends StatefulWidget {
  const LiguillaBracketScreen({super.key});

  static final GlobalKey<_LiguillaBracketScreenState> bracketKey =
      GlobalKey<_LiguillaBracketScreenState>();

  @override
  State<LiguillaBracketScreen> createState() => _LiguillaBracketScreenState();
}

class _LiguillaBracketScreenState extends State<LiguillaBracketScreen>
    with TickerProviderStateMixin {
  String _cruceKey(Cruce c) => c.cruceId ?? '${c.ronda}_${c.orden}';
  final FirestoreService _service = FirestoreService();
  List<Cruce> _cruces = [];
  // Agrega junto a las otras variables de estado
  bool _isDownloading = false;
  bool _isLoading = true;
  List<Cruce> _crucesB = [];
  bool _isLoadingB = false;
  late AnimationController _fadeBCtrl;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeBCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _service.liguillaActiva.addListener(_onLiguillaChanged);

    bool _isDownloading = false;

    // Carga únicamente la liguilla activa al entrar
    if (_service.liguillaActiva.value == 'B') {
      _loadDataB();
    } else {
      _loadData();
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
    super.dispose();
  }

  // ─── DESCARGA BRACKET ─────────────────────────────────────────────────
  Future<void> descargarBracket() async {
    final esA = _service.liguillaActiva.value == 'A';
    final cruces = esA ? _cruces : _crucesB;
    final label = esA ? 'LIGUILLA A' : 'LIGUILLA B';
    final headerColor = esA ? const Color(0xFF8B5CF6) : _P.amber;

    if (cruces.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
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
                        color: esA
                            ? const Color(0xFFF3EEFF)
                            : const Color(0xFFFEF9ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.download_rounded,
                        color: headerColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descargar bracket',
                            style: _ts(size: 15, weight: FontWeight.w700),
                          ),
                          Text(
                            'Exportar $label como imagen',
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
                  'Se guardará el bracket de $label con el estado actual en tu galería.',
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
                      child: _dialogBtn(
                        label: 'Cancelar',
                        filled: false,
                        color: headerColor,
                        onTap: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      // ── Botón con estado de carga ──
                      child: StatefulBuilder(
                        builder: (ctx, setButtonState) => Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isDownloading
                                ? null
                                : () async {
                                    setButtonState(() {});
                                    setDialogState(() {});
                                    if (mounted)
                                      setState(() => _isDownloading = true);

                                    try {
                                      final bytes = await _generarImagenBracket(
                                        cruces: cruces,
                                        label: label,
                                        headerColor: headerColor,
                                      );
                                      await ImageGallerySaverPlus.saveImage(
                                        bytes,
                                        quality: 100,
                                        name:
                                            'bracket_${label.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => _isDownloading = false);
                                        Navigator.pop(ctx, false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error: $e',
                                              style: _ts(
                                                color: Colors.white,
                                                size: 13,
                                              ),
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (mounted) {
                                      setState(() => _isDownloading = false);
                                      Navigator.pop(
                                        ctx,
                                        false,
                                      ); // cierra DESPUÉS de terminar
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Bracket guardado en la galería',
                                            style: _ts(
                                              color: Colors.white,
                                              size: 13,
                                            ),
                                          ),
                                          backgroundColor: _P.green,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: headerColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              // ── Alterna entre texto y spinner ──
                              child: _isDownloading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Descargar',
                                      style: _ts(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
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
      ),
    );
  }

  Widget _dialogBtn({
    required String label,
    required bool filled,
    required Color color,
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
            color: filled ? color : _P.bg,
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

  // ─── GENERADOR DE IMAGEN CANVAS ────────────────────────────────────────
  Future<Uint8List> _generarImagenBracket({
    required List<Cruce> cruces,
    required String label,
    required Color headerColor,
  }) async {
    final previos = cruces.where((c) => c.ronda == 'previo').toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final cuartos = cruces.where((c) => c.ronda == 'cuartos').toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final semis = cruces.where((c) => c.ronda == 'semis').toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final finalCruce = cruces.where((c) => c.ronda == 'final').firstOrNull;

    // ── Dimensiones ──────────────────
    const double scale = 3.0; // ← factor HiDPI (anti-blur)
    const double cardW = 280.0;
    const double cardH =
        380.0; // topMargin(10) + logo(120) + nombre(30) + estado(20) + pills(32) + padding(28)
    const double connW = 70.0;
    const double finalW = 300.0;
    const double rowGap = 32.0;
    const double topH = 160.0;
    const double padH = 48.0;
    const double padV = 60.0;

    final List<({String label, List<Cruce> cruces})> rondas = [
      if (previos.isNotEmpty) (label: 'OCTAVOS', cruces: previos),
      if (cuartos.isNotEmpty) (label: 'CUARTOS', cruces: cuartos),
      if (semis.isNotEmpty) (label: 'SEMIS', cruces: semis),
    ];

    final int n = rondas.length;

    // Max cruces por lado (primer ronda, lado izquierdo)
    int maxCrucesIzq = 0;
    int maxCrucesDir = 0;
    if (rondas.isNotEmpty) {
      maxCrucesIzq = rondas.first.cruces.where((c) => c.orden % 2 == 1).length;
      maxCrucesDir = rondas.first.cruces.where((c) => c.orden % 2 == 0).length;
    }
    final int maxRows = [
      maxCrucesIzq,
      maxCrucesDir,
      1,
    ].reduce((a, b) => a > b ? a : b);
    final double bracketH = maxRows * cardH + (maxRows - 1) * rowGap;

    // n columnas izq + n columnas der + conectores + final
    // El ancho ya era correcto estructuralmente, pero necesitamos
    // asegurarnos que el canvas sea lo suficientemente ancho
    // para ambos lados incluso si son asimétricos
    final double W = padH * 2 + cardW * (n * 2) + connW * (n * 2 + 1) + finalW;
    final double H = topH + bracketH + padV * 2;

    // ── Pre-carga de logos ──────────────────────────────────────────────
    Future<ui.Image?> _loadNetworkImage(String? url) async {
      if (url == null || url.isEmpty) return null;
      try {
        final completer = Completer<ui.Image?>();
        final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            completer.complete(info.image);
            stream.removeListener(listener);
          },
          onError: (_, __) {
            completer.complete(null);
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
        return await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      } catch (_) {
        return null;
      }
    }

    final allCruces = [...previos, ...cuartos, ...semis];
    if (finalCruce != null) allCruces.add(finalCruce);

    final logoUrls = <String>{};
    for (final c in allCruces) {
      if (c.equipo1LogoUrl.isNotEmpty) logoUrls.add(c.equipo1LogoUrl);
      if (c.equipo2LogoUrl.isNotEmpty) logoUrls.add(c.equipo2LogoUrl);
    }

    final Map<String, ui.Image?> logoCache = {};
    await Future.wait(
      logoUrls.map((url) async {
        logoCache[url] = await _loadNetworkImage(url);
      }),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale); // ← aplica escala ANTES de dibujar

    // ── Fondo ──────────────────────────────────────────────────────────
    _cvFillRect(canvas, 0, 0, W, H, _P.bg);

    // ── Header ─────────────────────────────────────────────────────────
    // Fondo degradado oscuro
    final headerPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF1E3A5F), const Color(0xFF1E3050)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, W, topH));
    canvas.drawRect(Rect.fromLTWH(0, 0, W, topH), headerPaint);

    // Acento de color arriba
    canvas.drawRect(Rect.fromLTWH(0, 0, W, 5), Paint()..color = headerColor);

    // Título
    _cvText(
      canvas,
      'BRACKET · $label',
      x: padH,
      y: 24,
      size: 36,
      weight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 2,
    );

    // Subtítulo — fase actual
    final fase = _faseActualTexto(cruces);
    _cvText(
      canvas,
      fase,
      x: padH,
      y: 72,
      size: 20,
      weight: FontWeight.w500,
      color: const Color(0xFF7AAECB),
    );

    // Fecha
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
    final fechaStr = '${now.day} ${meses[now.month - 1]} ${now.year}';
    _cvText(
      canvas,
      fechaStr,
      x: W - padH - 160,
      y: 24,
      size: 18,
      weight: FontWeight.w500,
      color: Colors.white.withOpacity(0.5),
    );

    // Progreso pills en header
    double pillX = padH;
    const double pillH = 28.0;
    for (final r in rondas) {
      final resueltos = r.cruces.where((c) => c.resuelto).length;
      final completo = resueltos == r.cruces.length;
      final pillColor = completo ? _P.green : const Color(0xFF4A7FA5);
      final pillW = 90.0;
      _cvRRect(
        canvas,
        pillX,
        100,
        pillW,
        pillH,
        8,
        color: pillColor.withOpacity(0.25),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pillX, 100, pillW, pillH),
          const Radius.circular(8),
        ),
        Paint()
          ..color = pillColor.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _cvTextCentered(
        canvas,
        '${r.label} $resueltos/${r.cruces.length}',
        x: pillX,
        y: 106,
        w: pillW,
        size: 13,
        weight: FontWeight.w700,
        color: completo ? _P.green : const Color(0xFF7AAECB),
      );
      pillX += pillW + 10;
    }
    // Final pill
    final finalResuelto = finalCruce?.resuelto ?? false;
    final finalPillColor = finalResuelto ? _P.amber : const Color(0xFF4A7FA5);
    _cvRRect(
      canvas,
      pillX,
      100,
      80,
      pillH,
      8,
      color: finalPillColor.withOpacity(0.25),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillX, 100, 80, pillH),
        const Radius.circular(8),
      ),
      Paint()
        ..color = finalPillColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _cvTextCentered(
      canvas,
      'FINAL ${finalResuelto ? '1/1' : '0/1'}',
      x: pillX,
      y: 106,
      w: 80,
      size: 13,
      weight: FontWeight.w700,
      color: finalResuelto ? _P.amber : const Color(0xFF7AAECB),
    );

    // ── Bracket ────────────────────────────────────────────────────────
    // Organiza cruces en izq/der igual que el widget
    final List<List<Cruce>> izqListas = [];
    final List<List<Cruce>> derListas = [];

    for (final r in rondas) {
      final todos = [...r.cruces]..sort((a, b) => a.orden.compareTo(b.orden));
      final izq = todos.where((c) => c.orden % 2 == 1).toList();
      final der = todos
          .where((c) => c.orden % 2 == 0)
          .toList()
          .reversed
          .toList();
      izqListas.add(izq);
      derListas.add(der);
    }

    // Posición X inicial del bracket (tras padding)
    double startX = padH;
    final double bracketY = topH + padV;

    // Calcula posiciones de cada cruce para dibujar líneas después
    // Map<cruceKey, Rect>
    final Map<String, Rect> cruceRects = {};

    for (int i = 0; i < n; i++) {
      final col = izqListas[i];
      final double x = startX + i * (cardW + connW);

      List<double>? posY;
      final bool esUltimaColumna =
          i == n - 1; // semis (la más cercana al centro)
      if (i == 0) {
        posY = null; // primera ronda: distribución uniforme
      } else if (esUltimaColumna) {
        // Semis izq: centradas respecto a la final
        final finalCenterY = bracketY + bracketH / 2;
        final colH = col.length * cardH + (col.length - 1) * rowGap;
        final topY = finalCenterY - colH / 2;
        posY = List.generate(col.length, (i) => topY + i * (cardH + rowGap));
      } else {
        posY = _calcularPosicionesDesdePrevia(
          cruces: col,
          prevCruces: izqListas[i - 1],
          cruceRects: cruceRects,
          cardH: cardH,
          startY: bracketY,
          totalBracketH: bracketH,
          rowGap: rowGap,
        );
      }

      _dibujarColumna(
        canvas,
        col,
        x,
        bracketY,
        cardW,
        cardH,
        rowGap,
        bracketH,
        cruceRects,
        logoCache: logoCache,
        posicionesY: posY,
      );
      _cvTextCentered(
        canvas,
        rondas[i].label,
        x: x,
        y: bracketY - 22,
        w: cardW,
        size: 13,
        weight: FontWeight.w700,
        color: _P.slate,
        letterSpacing: 1.0,
      );
    }

    // ── Final al centro ─────────────────────────────────────────────────
    final double finalX = startX + n * (cardW + connW);
    final double finalY = bracketY + bracketH / 2 - (cardH + 30) / 2;
    if (finalCruce != null) {
      _dibujarFinalCard(
        canvas,
        finalCruce,
        finalX,
        finalY,
        finalW,
        cardH,
        cruceRects,
        logoCache,
      );
    }
    _cvTextCentered(
      canvas,
      '· FINAL ·',
      x: finalX,
      y: bracketY - 22,
      w: finalW,
      size: 13,
      weight: FontWeight.w800,
      color: _P.blue,
      letterSpacing: 1.5,
    );

    // ── Columnas derecha ────────────────────────────────────────────────
    // derListas[0] = ronda más temprana (octavos), derListas[n-1] = semis
    // En canvas se dibujan: i = n-1 primero (semis, más cerca del centro)
    // hacia i = 0 (octavos, más afuera)
    //
    // Para que cada columna se posicione bien necesitamos:
    //   - La más alejada del centro (octavos, i=0) = centrado simple
    //   - Las siguientes hacia el centro = centradas según la columna
    //     exterior anterior (que ya fue dibujada)
    //
    // Así que dibujamos de AFUERA hacia ADENTRO para poder referenciar
    // la columna exterior al dibujar la interior.

    // Primero calculamos las X de cada columna der
    final List<double> derXs = [];
    for (int i = n - 1; i >= 0; i--) {
      derXs.add(finalX + finalW + connW + (n - 1 - i) * (cardW + connW));
    }
    // derXs[0] = x de semis (más cercana al centro)
    // derXs[n-1] = x de octavos (más alejada)

    // Dibujamos de AFUERA hacia ADENTRO: octavos primero, semis al final
    for (int di = n - 1; di >= 0; di--) {
      final int i = n - 1 - di;
      final col = derListas[i];
      final double x = derXs[di];

      List<double>? posY;
      final bool esUltimaColumna = di == 0; // semis (la más cercana al centro)
      if (di == n - 1) {
        posY = null; // primera ronda: distribución uniforme
      } else if (esUltimaColumna) {
        // Semis der: centradas respecto a la final (igual que izq)
        final finalCenterY = bracketY + bracketH / 2;
        final colH = col.length * cardH + (col.length - 1) * rowGap;
        final topY = finalCenterY - colH / 2;
        posY = List.generate(col.length, (i) => topY + i * (cardH + rowGap));
      } else {
        final prevCol = derListas[n - 1 - (di + 1)];
        posY = _calcularPosicionesDesdePrevia(
          cruces: col,
          prevCruces: prevCol,
          cruceRects: cruceRects,
          cardH: cardH,
          startY: bracketY,
          totalBracketH: bracketH,
          rowGap: rowGap,
        );
      }

      _dibujarColumna(
        canvas,
        col,
        x,
        bracketY,
        cardW,
        cardH,
        rowGap,
        bracketH,
        cruceRects,
        logoCache: logoCache,
        posicionesY: posY,
      );

      _cvTextCentered(
        canvas,
        rondas[i].label,
        x: x,
        y: bracketY - 22,
        w: cardW,
        size: 13,
        weight: FontWeight.w700,
        color: _P.slate,
        letterSpacing: 1.0,
      );
    }

    // ── Líneas conectoras ───────────────────────────────────────────────
    _dibujarLineas(
      canvas,
      cruces,
      cruceRects,
      finalCruce,
      rondas,
      izqListas,
      derListas,
      n,
      finalX,
      finalW,
    );

    // ── Leyenda ─────────────────────────────────────────────────────────
    final double leyY = H - 28;
    _cvRRect(
      canvas,
      padH,
      leyY - 4,
      280,
      22,
      6,
      color: Colors.black.withOpacity(0.08),
    );
    double lx = padH + 10;
    void _leyItem(Color c, String t) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lx, leyY, 12, 12),
          const Radius.circular(3),
        ),
        Paint()..color = c,
      );
      _cvText(
        canvas,
        t,
        x: lx + 17,
        y: leyY,
        size: 13,
        weight: FontWeight.w600,
        color: _P.slate,
      );
      lx += 90;
    }

    _leyItem(_P.blue, 'Resuelto');
    _leyItem(_P.amber, 'En curso');
    _leyItem(_P.border, 'Por jugar');

    final pic = recorder.endRecording();
    // El toImage usa dimensiones físicas (W*scale x H*scale)
    final img = await pic.toImage((W * scale).toInt(), (H * scale).toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  // ── REEMPLAZA _dibujarColumna COMPLETO ────────────────────────────────────
  void _dibujarColumna(
    Canvas canvas,
    List<Cruce> cruces,
    double x,
    double startY,
    double cardW,
    double cardH,
    double rowGap,
    double totalBracketH,
    Map<String, Rect> cruceRects, {
    bool dark = false,
    Map<String, ui.Image?> logoCache = const {},
    // Posiciones Y precomputadas (null = calcular centrado simple)
    List<double>? posicionesY,
  }) {
    if (cruces.isEmpty) return;

    List<double> ys;
    if (posicionesY != null && posicionesY.length == cruces.length) {
      ys = posicionesY;
    } else {
      // Primera ronda: distribuir uniformemente en todo el espacio disponible
      ys = [];
      if (cruces.length == 1) {
        ys.add(startY + (totalBracketH - cardH) / 2);
      } else {
        final slotH = totalBracketH / cruces.length;
        for (int i = 0; i < cruces.length; i++) {
          ys.add(startY + slotH * i + (slotH - cardH) / 2);
        }
      }
    }

    for (int i = 0; i < cruces.length; i++) {
      final c = cruces[i];
      final rect = Rect.fromLTWH(x, ys[i], cardW, cardH);
      final key = c.cruceId ?? '${c.ronda}_${c.orden}';
      cruceRects[key] = rect;
      _dibujarCruceCard(canvas, c, rect, logoCache);
    }
  }

  // ── AGREGA ESTE HELPER NUEVO ───────────────────────────────────────────────
  /// Calcula las posiciones Y de una columna basándose en los centros
  /// de los cruces de la columna anterior que alimentan a cada cruce.
  /// [cruces] = cruces de esta columna (ya ordenados)
  /// [prevCruces] = cruces de la columna anterior (ya ordenados)
  /// [cruceRects] = rects ya calculados (debe tener los de prevCruces)
  /// [ratio] = cuántos cruces prev alimentan a cada cruce de esta columna
  List<double> _calcularPosicionesDesdePrevia({
    required List<Cruce> cruces,
    required List<Cruce> prevCruces,
    required Map<String, Rect> cruceRects,
    required double cardH,
    required double startY,
    required double totalBracketH,
    required double rowGap,
  }) {
    if (cruces.isEmpty) return [];
    if (prevCruces.isEmpty) {
      // Sin referencia: centrado simple
      final colH = cruces.length * cardH + (cruces.length - 1) * rowGap;
      double y = startY + (totalBracketH - colH) / 2;
      return List.generate(cruces.length, (i) {
        final pos = y;
        y += cardH + rowGap;
        return pos;
      });
    }

    String ck(Cruce c) => c.cruceId ?? '${c.ronda}_${c.orden}';
    final ratio = prevCruces.length / cruces.length;

    return List.generate(cruces.length, (ni) {
      final start = (ni * ratio).floor();
      final end = ((ni + 1) * ratio).floor().clamp(
        start + 1,
        prevCruces.length,
      );

      // Recolectar centros de los padres que alimentan a este hijo
      final List<double> parentCenters = [];
      for (int ci = start; ci < end; ci++) {
        final r = cruceRects[ck(prevCruces[ci])];
        if (r != null) parentCenters.add(r.top + r.height / 2);
      }

      if (parentCenters.isEmpty) {
        // fallback
        final colH = cruces.length * cardH + (cruces.length - 1) * rowGap;
        return startY + (totalBracketH - colH) / 2 + ni * (cardH + rowGap);
      }

      // Con 2+ padres: promedio de centros (comportamiento original correcto)
      // Con 1 padre (bye): calculamos el slot que le corresponde dentro del
      // espacio total, usando el padre como referencia de qué mitad ocupar
      if (parentCenters.length >= 2) {
        final avg =
            parentCenters.reduce((a, b) => a + b) / parentCenters.length;
        return avg - cardH / 2;
      } else {
        // Bye: en vez de alinearse exactamente con el padre,
        // nos centramos en el slot proporcional que ocupa este hijo
        // dentro del rango total del bracket
        final slotH = totalBracketH / cruces.length;
        return startY + slotH * ni + (slotH - cardH) / 2;
      }
    });
  }

  // ── Card de cruce normal ──────────────────────────────────────────────
  // REEMPLAZA el método _dibujarCruceCard completo:
  void _dibujarCruceCard(
    Canvas canvas,
    Cruce c,
    Rect rect,
    Map<String, ui.Image?> logoCache,
  ) {
    final resuelto = c.resuelto;
    final enCurso = !resuelto && (c.idaJugada || c.vueltaJugada);
    final borderColor = resuelto
        ? _P.blue.withOpacity(0.5)
        : enCurso
        ? _P.amber.withOpacity(0.6)
        : _P.border;

    // Fondo + borde
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()..color = _P.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = resuelto || enCurso ? 2 : 1,
    );

    // Barra lateral estado
    if (resuelto || enCurso) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top + 14, 4, rect.height - 28),
          const Radius.circular(2),
        ),
        Paint()..color = resuelto ? _P.blue : _P.amber,
      );
    }

    final eq1gana = resuelto && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = resuelto && c.ganadorCruceId == c.equipo2Id;

    // ── Zonas fijas ──────────────────────────────────────────────────────
    // Pills en la parte de abajo, separadas del contenido
    const double pillH = 20.0;
    const double pillGap = 8.0;
    const double bottomPad = 12.0;
    final double pillsY = rect.bottom - bottomPad - pillH;

    // Estado (FT / IDA) centrado verticalmente entre las dos mitades
    const double statusH = 16.0;
    final double midY = rect.top + rect.height / 2;
    final double statusY = midY - statusH / 2;

    // Zonas de equipo: desde top hasta statusY, y desde statusY+statusH hasta pillsY
    final eq1Rect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      statusY - rect.top,
    );
    final eq2Rect = Rect.fromLTWH(
      rect.left,
      statusY + statusH,
      rect.width,
      pillsY - (statusY + statusH) - 4,
    );

    // ── Equipo 1 ──
    _dibujarEquipoCanvasV2(
      canvas,
      nombre: c.equipo1Nombre.isNotEmpty ? c.equipo1Nombre : '???',
      goles: (c.idaJugada || c.vueltaJugada) ? c.golesGlobalesEq1 : null,
      gana: eq1gana,
      pierde: resuelto && !eq1gana,
      logoImg: logoCache[c.equipo1LogoUrl],
      areaRect: eq1Rect,
      logoSize: 100.0, // ← logos grandes
    );

    // ── Divisor + estado central ──
    canvas.drawLine(
      Offset(rect.left + 16, midY),
      Offset(rect.right - 16, midY),
      Paint()
        ..color = _P.border
        ..strokeWidth = 0.5,
    );
    final estado = resuelto ? 'FT' : (c.idaJugada ? 'IDA' : 'I+V');
    _cvTextCentered(
      canvas,
      estado,
      x: rect.left,
      y: statusY + 1,
      w: rect.width,
      size: 11,
      weight: FontWeight.w800,
      color: resuelto ? _P.blue : _P.slate,
      letterSpacing: 0.5,
    );

    // ── Equipo 2 ──
    _dibujarEquipoCanvasV2(
      canvas,
      nombre: c.equipo2Nombre.isNotEmpty ? c.equipo2Nombre : '???',
      goles: (c.idaJugada || c.vueltaJugada) ? c.golesGlobalesEq2 : null,
      gana: eq2gana,
      pierde: resuelto && !eq2gana,
      logoImg: logoCache[c.equipo2LogoUrl],
      areaRect: eq2Rect,
      logoSize: 100.0, // ← logos grandes
    );

    // ── Pills I / V ──────────────────────────────────────────────────────
    const double pw = 32.0;
    final double totalPillsW = pw * 2 + pillGap;
    final double pillStartX = rect.left + (rect.width - totalPillsW) / 2;

    _dibujarPillCanvas(canvas, pillStartX, pillsY, 'I', c.idaJugada);
    _dibujarPillCanvas(
      canvas,
      pillStartX + pw + pillGap,
      pillsY,
      'V',
      c.vueltaJugada,
    );

    // PEN label
    if (c.vuelta?.penales == true && resuelto) {
      _cvTextCentered(
        canvas,
        'PEN',
        x: rect.right - 54,
        y: pillsY + 2,
        w: 48,
        size: 10,
        weight: FontWeight.w800,
        color: _P.amber,
        letterSpacing: 0.5,
      );
    }
  }

  // AGREGA este método nuevo (puedes eliminar el viejo _dibujarEquipoCanvas si ya no lo usas):

  void _dibujarEquipoCanvasV2(
    Canvas canvas, {
    required String nombre,
    required int? goles,
    required bool gana,
    required bool pierde,
    required ui.Image? logoImg,
    required Rect areaRect,
    required double logoSize,
    bool dark = false,
  }) {
    // ── Zona de logo: centrada horizontalmente, con margen top ──
    const double topMargin = 10.0;
    final double logoLeft = areaRect.left + (areaRect.width - logoSize) / 2;
    final double logoTop = areaRect.top + topMargin;
    final double logoCX = logoLeft + logoSize / 2;
    final double logoCY = logoTop + logoSize / 2;

    // Fondo circular
    canvas.drawCircle(
      Offset(logoCX, logoCY),
      logoSize / 2 + 3,
      Paint()..color = dark ? Colors.white.withOpacity(0.07) : _P.bg,
    );

    // Logo o placeholder
    if (logoImg != null) {
      final logoRect = Rect.fromLTWH(logoLeft, logoTop, logoSize, logoSize);
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(logoRect, Radius.circular(logoSize / 2)),
      );
      final paint = Paint();
      if (pierde) {
        paint.colorFilter = const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          0.35,
          0,
        ]);
      }
      canvas.drawImageRect(
        logoImg,
        Rect.fromLTWH(
          0,
          0,
          logoImg.width.toDouble(),
          logoImg.height.toDouble(),
        ),
        logoRect,
        paint,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(
        Offset(logoCX, logoCY),
        logoSize / 2,
        Paint()
          ..color = dark
              ? Colors.white.withOpacity(0.08)
              : _P.border.withOpacity(0.4),
      );
    }

    // ── Nombre: debajo del logo con margen fijo ──
    final double nameY = logoTop + logoSize + 8.0;
    final nameColor = dark
        ? (pierde
              ? Colors.white.withOpacity(0.2)
              : gana
              ? Colors.white
              : const Color(0xFF7AAECB))
        : (pierde
              ? _P.border
              : gana
              ? _P.navy
              : _P.slate);

    _cvTextCentered(
      canvas,
      nombre,
      x: areaRect.left + 4,
      y: nameY,
      w: areaRect.width - 8,
      size: 14,
      weight: gana ? FontWeight.w800 : FontWeight.w500,
      color: nameColor,
    );

    // ── Badge de goles: derecha del área, centrado verticalmente con el logo ──
    if (goles != null) {
      final golesColor = dark
          ? (gana ? _P.amber : Colors.white.withOpacity(0.4))
          : (gana ? _P.blue : _P.slate);
      final bgColor = dark
          ? (gana ? _P.amber.withOpacity(0.2) : Colors.white.withOpacity(0.08))
          : (gana ? _P.blueLight : _P.bg);

      const double bW = 36, bH = 28;
      // Alineado a la derecha del área con margen, centrado con el logo
      final double bX = areaRect.right - bW - 10;
      final double bY = logoCY - bH / 2; // ← centrado con el centro del logo

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bX, bY, bW, bH),
          const Radius.circular(7),
        ),
        Paint()..color = bgColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bX, bY, bW, bH),
          const Radius.circular(7),
        ),
        Paint()
          ..color = golesColor.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _cvTextCentered(
        canvas,
        '$goles',
        x: bX,
        y: bY + 4,
        w: bW,
        size: 16,
        weight: FontWeight.w800,
        color: golesColor,
      );
    }
  }

  // ── Card de la final ──────────────────────────────────────────────────
  void _dibujarFinalCard(
    Canvas canvas,
    Cruce c,
    double x,
    double y,
    double w,
    double h,
    Map<String, Rect> cruceRects,
    Map<String, ui.Image?> logoCache,
  ) {
    final rect = Rect.fromLTWH(x, y, w, h + 30);
    final key = c.cruceId ?? '${c.ronda}_${c.orden}';
    cruceRects[key] = rect;
    final hayGanador = c.ganadorCruceId != null;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E3A5F), Color(0xFF1E3050)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..color = hayGanador
            ? _P.amber.withOpacity(0.6)
            : _P.blue.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hayGanador ? 2 : 1.5,
    );

    _cvTextCentered(
      canvas,
      '🏆  GRAN FINAL',
      x: rect.left,
      y: rect.top + 10,
      w: rect.width,
      size: 13,
      weight: FontWeight.w800,
      color: hayGanador ? _P.amber : Colors.white.withOpacity(0.4),
      letterSpacing: 1.2,
    );

    canvas.drawLine(
      Offset(rect.left + 12, rect.top + 32),
      Offset(rect.right - 12, rect.top + 32),
      Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..strokeWidth = 0.5,
    );

    final eq1gana = hayGanador && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = hayGanador && c.ganadorCruceId == c.equipo2Id;

    _dibujarEquipoCanvasV2(
      canvas,
      nombre: c.equipo1Nombre.isNotEmpty ? c.equipo1Nombre : '???',
      goles: (c.idaJugada || c.vueltaJugada) ? c.golesGlobalesEq1 : null,
      gana: eq1gana,
      pierde: hayGanador && !eq1gana,
      logoImg: logoCache[c.equipo1LogoUrl],
      areaRect: Rect.fromLTWH(
        rect.left,
        rect.top + 32,
        rect.width,
        (rect.height - 32) / 2,
      ),
      logoSize: 100.0,
      dark: true,
    );

    final midY = rect.top + rect.height / 2 + 8;
    canvas.drawLine(
      Offset(rect.left + 12, midY),
      Offset(rect.right - 12, midY),
      Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..strokeWidth = 0.5,
    );

    final estado = c.resuelto ? 'FT' : (c.idaJugada ? 'IDA' : 'I+V');
    _cvTextCentered(
      canvas,
      estado,
      x: rect.left,
      y: midY - 9,
      w: rect.width,
      size: 11,
      weight: FontWeight.w800,
      color: c.resuelto
          ? const Color(0xFF7AAECB)
          : Colors.white.withOpacity(0.25),
      letterSpacing: 1,
    );

    _dibujarEquipoCanvasV2(
      canvas,
      nombre: c.equipo2Nombre.isNotEmpty ? c.equipo2Nombre : '???',
      goles: (c.idaJugada || c.vueltaJugada) ? c.golesGlobalesEq2 : null,
      gana: eq2gana,
      pierde: hayGanador && !eq2gana,
      logoImg: logoCache[c.equipo2LogoUrl],
      areaRect: Rect.fromLTWH(
        rect.left,
        midY,
        rect.width,
        (rect.height - 32) / 2,
      ),
      logoSize: 100.0,
      dark: true,
    );

    final pillY = rect.bottom - 26;
    _dibujarPillCanvas(
      canvas,
      rect.left + rect.width / 2 - 56,
      pillY,
      'IDA',
      c.idaJugada,
      wide: true,
    );
    _dibujarPillCanvas(
      canvas,
      rect.left + rect.width / 2 + 4,
      pillY,
      'VTA',
      c.vueltaJugada,
      wide: true,
    );

    if (hayGanador) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(rect.left, rect.bottom - 26, rect.width, 26),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
        Paint()..color = _P.amber.withOpacity(0.15),
      );
      _cvTextCentered(
        canvas,
        '🏆  CAMPEÓN',
        x: rect.left,
        y: rect.bottom - 20,
        w: rect.width,
        size: 11,
        weight: FontWeight.w800,
        color: _P.amber,
        letterSpacing: 2,
      );
    }
  }

  // ── Dibuja nombre + goles de un equipo ────────────────────────────────
  void _dibujarEquipoCanvas(
    Canvas canvas, {
    required String nombre,
    required int? goles,
    required bool gana,
    required bool pierde,
    required double x,
    required double y,
    required double maxW,
    bool dark = false,
  }) {
    final nameColor = dark
        ? (pierde
              ? Colors.white.withOpacity(0.2)
              : gana
              ? Colors.white
              : const Color(0xFF7AAECB))
        : (pierde
              ? _P.border
              : gana
              ? _P.navy
              : _P.slate);

    _cvText(
      canvas,
      nombre,
      x: x,
      y: y,
      size: 15,
      weight: gana ? FontWeight.w800 : FontWeight.w500,
      color: nameColor,
      maxWidth: maxW,
    );

    if (goles != null) {
      final golesColor = dark
          ? (gana ? _P.amber : Colors.white.withOpacity(0.3))
          : (gana ? _P.blue : _P.slate);
      final bgColor = dark
          ? (gana ? _P.amber.withOpacity(0.2) : Colors.white.withOpacity(0.06))
          : (gana ? _P.blueLight : _P.bg);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + maxW + 4, y - 2, 36, 22),
          const Radius.circular(6),
        ),
        Paint()..color = bgColor,
      );
      _cvTextCentered(
        canvas,
        '$goles',
        x: x + maxW + 4,
        y: y,
        w: 36,
        size: 15,
        weight: FontWeight.w800,
        color: golesColor,
      );
    }
  }

  // ── Pill ──────────────────────────────────────────────────────────────
  void _dibujarPillCanvas(
    Canvas canvas,
    double x,
    double y,
    String label,
    bool jugado, {
    bool wide = false,
  }) {
    final double pw = wide ? 50 : 26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, pw, 16),
        const Radius.circular(4),
      ),
      Paint()..color = jugado ? _P.blue.withOpacity(0.15) : _P.bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, pw, 16),
        const Radius.circular(4),
      ),
      Paint()
        ..color = jugado ? _P.blue.withOpacity(0.4) : _P.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    _cvTextCentered(
      canvas,
      label,
      x: x,
      y: y + 2,
      w: pw,
      size: 10,
      weight: FontWeight.w700,
      color: jugado ? _P.blue : _P.slate,
    );
  }

  // ── Líneas conectoras ─────────────────────────────────────────────────
  void _dibujarLineas(
    Canvas canvas,
    List<Cruce> cruces,
    Map<String, Rect> cruceRects,
    Cruce? finalCruce,
    List<({String label, List<Cruce> cruces})> rondas,
    List<List<Cruce>> izqListas,
    List<List<Cruce>> derListas,
    int n,
    double finalX,
    double finalW,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFD0D4E8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    String ck(Cruce c) => c.cruceId ?? '${c.ronda}_${c.orden}';

    void conectar(Rect from, Rect to, bool isLeft) {
      final fromCY = from.top + from.height / 2;
      final toCY = to.top + to.height / 2;
      final startX = isLeft ? from.right : from.left;
      final endX = isLeft ? to.left : to.right;
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

    final rondasLists = rondas.map((r) => r.cruces).toList();
    for (int ri = 0; ri < rondasLists.length; ri++) {
      final currentRonda = rondasLists[ri];
      final nextRonda = ri + 1 < rondasLists.length
          ? rondasLists[ri + 1]
          : (finalCruce != null ? [finalCruce] : <Cruce>[]);
      if (nextRonda.isEmpty) continue;

      final currentIzq = currentRonda.where((c) => c.orden % 2 == 1).toList();
      final currentDer = currentRonda.where((c) => c.orden % 2 == 0).toList();
      final nextEsFinal =
          nextRonda.length == 1 && nextRonda.first.ronda == 'final';
      final nextIzq = nextEsFinal
          ? nextRonda
          : nextRonda.where((c) => c.orden % 2 == 1).toList();
      final nextDer = nextEsFinal
          ? nextRonda
          : nextRonda.where((c) => c.orden % 2 == 0).toList();

      if (nextIzq.isNotEmpty) {
        final ratio = currentIzq.length / nextIzq.length;
        for (int ni = 0; ni < nextIzq.length; ni++) {
          final toRect = cruceRects[ck(nextIzq[ni])];
          if (toRect == null) continue;
          final start = (ni * ratio).floor();
          final end = ((ni + 1) * ratio).floor();
          for (int ci = start; ci < end && ci < currentIzq.length; ci++) {
            final fromRect = cruceRects[ck(currentIzq[ci])];
            if (fromRect == null) continue;
            conectar(fromRect, toRect, true);
          }
        }
      }
      if (nextDer.isNotEmpty) {
        final ratio = currentDer.length / nextDer.length;
        for (int ni = 0; ni < nextDer.length; ni++) {
          final toRect = cruceRects[ck(nextDer[ni])];
          if (toRect == null) continue;
          final start = (ni * ratio).floor();
          final end = ((ni + 1) * ratio).floor();
          for (int ci = start; ci < end && ci < currentDer.length; ci++) {
            final fromRect = cruceRects[ck(currentDer[ci])];
            if (fromRect == null) continue;
            conectar(fromRect, toRect, false);
          }
        }
      }
    }
  }

  // ── Fase actual texto ─────────────────────────────────────────────────
  String _faseActualTexto(List<Cruce> cruces) {
    final finalC = cruces.where((c) => c.ronda == 'final').firstOrNull;
    if (finalC?.resuelto == true)
      return 'Finalizado · Campeón: ${finalC!.ganadorNombre}';
    if (cruces.any((c) => c.ronda == 'semis' && c.resuelto))
      return 'Semifinales en curso';
    if (cruces.any((c) => c.ronda == 'cuartos' && c.resuelto))
      return 'Cuartos de final en curso';
    if (cruces.any((c) => c.ronda == 'previo' && c.resuelto))
      return 'Octavos de final en curso';
    return 'Fase de liguilla · Por iniciar';
  }

  // ── Canvas helpers ────────────────────────────────────────────────────
  void _cvFillRect(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    Color col,
  ) => c.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = col);

  void _cvRRect(
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

  void _cvText(
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

  void _cvTextCentered(
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

  // ─── LOAD DATA ────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    _fadeCtrl.reset();
    try {
      final partidos = await _service.getPartidosLiguilla();
      final cruces = _service.agruparEnCruces(partidos);
      if (mounted) {
        setState(() {
          _cruces = cruces;
          _isLoading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('❌ Bracket error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDataB() async {
    if (mounted) setState(() => _isLoadingB = true);
    _fadeBCtrl.reset();
    try {
      final partidos = await _service.getPartidosLiguillaB();
      final cruces = _service.agruparEnCruces(partidos);
      if (mounted) {
        setState(() {
          _crucesB = cruces;
          _isLoadingB = false;
        });
        _fadeBCtrl.forward();
      }
    } catch (e) {
      debugPrint('❌ Bracket B error: $e');
      if (mounted) setState(() => _isLoadingB = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
            if (_crucesB.isEmpty) _loadDataB();
          } else {
            if (_cruces.isEmpty) _loadData();
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

  Widget _buildContenidoA() {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: _P.blue, strokeWidth: 2.5),
      );
    if (_cruces.isEmpty) return _buildEmptyState('A');
    return RefreshIndicator(
      color: _P.blue,
      backgroundColor: _P.surface,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBracketHero(cruces: _cruces, label: 'LIGUILLA A'),
              const SizedBox(height: 20),
              _buildBracket(cruces: _cruces),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenidoB() {
    if (_isLoadingB)
      return const Center(
        child: CircularProgressIndicator(color: _P.amber, strokeWidth: 2.5),
      );
    if (_crucesB.isEmpty) return _buildEmptyState('B');
    return RefreshIndicator(
      color: _P.amber,
      backgroundColor: _P.surface,
      onRefresh: _loadDataB,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        child: FadeTransition(
          opacity: _fadeBCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBracketHero(cruces: _crucesB, label: 'LIGUILLA B'),
              const SizedBox(height: 20),
              _buildBracket(cruces: _crucesB),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String liga) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.border, width: 0.5),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: _P.slate,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Liguilla $liga aún no iniciada',
            style: _ts(size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            liga == 'A'
                ? 'El admin debe cerrar la liga\npara generar el bracket.'
                : 'El admin debe generar la Liguilla B\ndesde el panel de administrador.',
            textAlign: TextAlign.center,
            style: _ts(size: 13, color: _P.slate, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildBracketHero({
    required List<Cruce> cruces,
    required String label,
  }) {
    final finalCruce = cruces.where((c) => c.ronda == 'final').firstOrNull;
    final hayGanador = finalCruce?.ganadorCruceId != null;
    final ganadorNombre = hayGanador ? finalCruce!.ganadorNombre : null;
    final ganadorLogo = hayGanador ? finalCruce!.ganadorLogoUrl : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.heroMid, _P.heroDark],
        ),
        boxShadow: [
          BoxShadow(
            color: _P.blue.withOpacity(0.22),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    'FASE DE LIGUILLA',
                    style: _ts(
                      size: 10,
                      weight: FontWeight.w700,
                      color: const Color(0xFF7AAECB),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hayGanador ? '¡Campeón!' : 'En curso',
                  style: _ts(
                    size: 22,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hayGanador ? ganadorNombre! : '$label · Ida y vuelta',
                  style: _ts(
                    size: 13,
                    color: const Color(0xFF7AAECB),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                _bracketProgress(cruces: cruces),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (hayGanador && ganadorLogo != null && ganadorLogo.isNotEmpty)
            _logoCircle(ganadorLogo, size: 64)
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFF39C12),
                size: 32,
              ),
            ),
        ],
      ),
    );
  }

  Widget _bracketProgress({required List<Cruce> cruces}) {
    final previos = cruces.where((c) => c.ronda == 'previo').toList();
    final cuartos = cruces.where((c) => c.ronda == 'cuartos').toList();
    final semis = cruces.where((c) => c.ronda == 'semis').toList();
    final finalCruce = cruces.where((c) => c.ronda == 'final').firstOrNull;
    return Row(
      children: [
        if (previos.isNotEmpty) ...[
          _progressPill(
            'O',
            previos.where((c) => c.resuelto).length,
            previos.length,
          ),
          const SizedBox(width: 6),
        ],
        if (cuartos.isNotEmpty) ...[
          _progressPill(
            'C',
            cuartos.where((c) => c.resuelto).length,
            cuartos.length,
          ),
          const SizedBox(width: 6),
        ],
        if (semis.isNotEmpty) ...[
          _progressPill(
            'S',
            semis.where((c) => c.resuelto).length,
            semis.length,
          ),
          const SizedBox(width: 6),
        ],
        _progressPill('F', (finalCruce?.resuelto ?? false) ? 1 : 0, 1),
      ],
    );
  }

  Widget _progressPill(String label, int done, int total) {
    final complete = done == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: complete
            ? _P.green.withOpacity(0.2)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: complete
              ? _P.green.withOpacity(0.4)
              : Colors.white.withOpacity(0.12),
          width: 0.5,
        ),
      ),
      child: Text(
        '$label $done/$total',
        style: _ts(
          size: 10,
          weight: FontWeight.w700,
          color: complete ? _P.green : const Color(0xFF7AAECB),
        ),
      ),
    );
  }

  Widget _buildBracket({required List<Cruce> cruces}) {
    final previos = cruces.where((c) => c.ronda == 'previo').toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final cuartos = cruces.where((c) => c.ronda == 'cuartos').toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final semis = cruces.where((c) => c.ronda == 'semis').toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final final_ = cruces.where((c) => c.ronda == 'final').firstOrNull;

    final List<({String label, List<Cruce> cruces})> rondas = [
      if (previos.isNotEmpty) (label: 'OCTAVOS', cruces: previos),
      if (cuartos.isNotEmpty) (label: 'CUARTOS', cruces: cuartos),
      if (semis.isNotEmpty) (label: 'SEMIS', cruces: semis),
    ];

    const double cardW = 100.0, connW = 28.0, finalW = 108.0, hPad = 12.0;
    final int n = rondas.length;
    final double totalW = cardW * (n * 2) + connW * (n * 2) + finalW + hPad * 2;

    final Map<String, GlobalKey> keyMap = {};
    for (final r in rondas) {
      for (final c in r.cruces) {
        keyMap[_cruceKey(c)] = GlobalKey();
      }
    }
    if (final_ != null) keyMap[_cruceKey(final_!)] = GlobalKey();

    final List<_Connection> connections = [];
    final rondasLists = rondas.map((r) => r.cruces).toList();

    for (int ri = 0; ri < rondasLists.length; ri++) {
      final currentRonda = rondasLists[ri];
      final nextRonda = ri + 1 < rondasLists.length
          ? rondasLists[ri + 1]
          : (final_ != null ? [final_!] : <Cruce>[]);
      if (nextRonda.isEmpty) continue;

      final currentIzq = currentRonda.where((c) => c.orden % 2 == 1).toList();
      final currentDer = currentRonda.where((c) => c.orden % 2 == 0).toList();
      final nextIzq = nextRonda.where((c) => c.orden % 2 == 1).toList();
      final nextDer = nextRonda.where((c) => c.orden % 2 == 0).toList();
      final nextEsFinal =
          nextRonda.length == 1 && nextRonda.first.ronda == 'final';

      final destIzq = nextEsFinal ? nextRonda : nextIzq;
      if (destIzq.isNotEmpty) {
        final ratio = currentIzq.length / destIzq.length;
        for (int ni = 0; ni < destIzq.length; ni++) {
          final start = (ni * ratio).floor();
          final end = ((ni + 1) * ratio).floor();
          for (int ci = start; ci < end && ci < currentIzq.length; ci++) {
            final fk = keyMap[_cruceKey(currentIzq[ci])];
            final tk = keyMap[_cruceKey(destIzq[ni])];
            if (fk != null && tk != null)
              connections.add(
                _Connection(fromKey: fk, toKey: tk, isLeft: true),
              );
          }
        }
      }
      final destDer = nextEsFinal ? nextRonda : nextDer;
      if (destDer.isNotEmpty) {
        final ratio = currentDer.length / destDer.length;
        for (int ni = 0; ni < destDer.length; ni++) {
          final start = (ni * ratio).floor();
          final end = ((ni + 1) * ratio).floor();
          for (int ci = start; ci < end && ci < currentDer.length; ci++) {
            final fk = keyMap[_cruceKey(currentDer[ci])];
            final tk = keyMap[_cruceKey(destDer[ni])];
            if (fk != null && tk != null)
              connections.add(
                _Connection(fromKey: fk, toKey: tk, isLeft: false),
              );
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _P.blue,
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
                _phaseChip(cruces: cruces),
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
                width: totalW - hPad * 2,
                child: _buildBracketWithLines(
                  rondas: rondas,
                  final_: final_,
                  keyMap: keyMap,
                  connections: connections,
                  cardW: cardW,
                  connW: connW,
                  finalW: finalW,
                ),
              ),
            ),
          ),
          Divider(height: 0, thickness: 0.5, color: _P.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                _leyendaItem(color: _P.blue, label: 'Resuelto'),
                const SizedBox(width: 14),
                _leyendaItem(color: _P.amber, label: 'En curso'),
                const SizedBox(width: 14),
                _leyendaItem(color: _P.border, label: 'Por jugar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBracketWithLines({
    required List<({String label, List<Cruce> cruces})> rondas,
    required Cruce? final_,
    required Map<String, GlobalKey> keyMap,
    required List<_Connection> connections,
    required double cardW,
    required double connW,
    required double finalW,
  }) {
    final int n = rondas.length;
    final List<List<Cruce>> izq = [], der = [];
    for (final r in rondas) {
      final todos = [...r.cruces]..sort((a, b) => a.orden.compareTo(b.orden));
      izq.add(todos.where((c) => c.orden % 2 == 1).toList());
      der.add(todos.where((c) => c.orden % 2 == 0).toList().reversed.toList());
    }
    final labels = rondas.map((r) => r.label).toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (int i = 0; i < n; i++) ...[
                  SizedBox(
                    width: cardW,
                    child: _roundLabel(labels[i], active: false),
                  ),
                  SizedBox(width: connW),
                ],
                SizedBox(
                  width: finalW,
                  child: _roundLabel('FINAL', active: true),
                ),
                for (int i = n - 1; i >= 0; i--) ...[
                  SizedBox(width: connW),
                  SizedBox(
                    width: cardW,
                    child: _roundLabel(labels[i], active: false),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < n; i++) ...[
                    SizedBox(
                      width: cardW,
                      child: _columnaCrucesKeyed(izq[i], keyMap),
                    ),
                    SizedBox(width: connW),
                  ],
                  SizedBox(
                    width: finalW,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_finalCruceCardKeyed(final_, keyMap)],
                    ),
                  ),
                  for (int i = n - 1; i >= 0; i--) ...[
                    SizedBox(width: connW),
                    SizedBox(
                      width: cardW,
                      child: _columnaCrucesKeyed(der[i], keyMap),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: _BracketLinesOverlay(connections: connections),
          ),
        ),
      ],
    );
  }

  Widget _columnaCrucesKeyed(
    List<Cruce> cruces,
    Map<String, GlobalKey> keyMap,
  ) {
    if (cruces.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < cruces.length; i++) ...[
          _cruceCardKeyed(cruces[i], keyMap[_cruceKey(cruces[i])]),
          if (i < cruces.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _cruceCardKeyed(Cruce? c, GlobalKey? key) {
    if (c == null) return const SizedBox.shrink();
    final sinEq1 = c.equipo1Id == null && c.equipo1Nombre.isEmpty;
    final sinEq2 = c.equipo2Id == null && c.equipo2Nombre.isEmpty;
    if (sinEq1 && sinEq2) {
      return Container(
        key: key,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: _compactEmpty(),
      );
    }
    final resuelto = c.resuelto;
    final enCurso = !resuelto && (c.idaJugada || c.vueltaJugada);
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: resuelto
              ? _P.blue.withOpacity(0.35)
              : enCurso
              ? _P.amber.withOpacity(0.5)
              : _P.border,
          width: resuelto || enCurso ? 1 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: _cruceContentPartial(c),
    );
  }

  Widget _finalCruceCardKeyed(Cruce? c, Map<String, GlobalKey> keyMap) {
    final key = c != null ? keyMap[_cruceKey(c)] : null;
    return KeyedSubtree(key: key, child: _finalCruceCard(c));
  }

  Widget _phaseChip({required List<Cruce> cruces}) {
    final previos = cruces.where((c) => c.ronda == 'previo').toList();
    final cuartos = cruces.where((c) => c.ronda == 'cuartos').toList();
    final semis = cruces.where((c) => c.ronda == 'semis').toList();
    final finalCruce = cruces.where((c) => c.ronda == 'final').firstOrNull;
    String fase;
    Color color;
    if (finalCruce?.resuelto == true) {
      fase = 'Finalizado';
      color = _P.amber;
    } else if (semis.any((c) => c.resuelto)) {
      fase = 'Semifinales';
      color = _P.blue;
    } else if (cuartos.any((c) => c.resuelto)) {
      fase = 'Cuartos';
      color = _P.green;
    } else if (previos.any((c) => c.resuelto)) {
      fase = 'Octavos';
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

  Widget _roundLabel(String text, {required bool active}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (active) ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: _P.blue, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          textAlign: TextAlign.center,
          style: _ts(
            size: 9,
            weight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? _P.blue : _P.slate,
            letterSpacing: 1.0,
          ),
        ),
        if (active) ...[
          const SizedBox(width: 4),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: _P.blue, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }

  Widget _cruceContentPartial(Cruce c) {
    final eq1gana = c.resuelto && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = c.resuelto && c.ganadorCruceId == c.equipo2Id;
    final hayEq1 = c.equipo1Id != null || c.equipo1Nombre.isNotEmpty;
    final hayEq2 = c.equipo2Id != null || c.equipo2Nombre.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hayEq1
            ? _compactTeam(
                logoUrl: c.equipo1LogoUrl,
                nombre: c.equipo1Nombre,
                goles: (c.idaJugada || c.vueltaJugada)
                    ? c.golesGlobalesEq1
                    : null,
                gana: eq1gana,
                pierde: c.resuelto && !eq1gana,
              )
            : _emptyLogoSlot(),
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
        hayEq2
            ? _compactTeam(
                logoUrl: c.equipo2LogoUrl,
                nombre: c.equipo2Nombre,
                goles: (c.idaJugada || c.vueltaJugada)
                    ? c.golesGlobalesEq2
                    : null,
                gana: eq2gana,
                pierde: c.resuelto && !eq2gana,
              )
            : _emptyLogoSlot(),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _partidoPill(jugado: c.idaJugada, label: 'I'),
            const SizedBox(width: 3),
            _partidoPill(jugado: c.vueltaJugada, label: 'V'),
          ],
        ),
        if (c.vuelta?.penales == true && c.resuelto) ...[
          const SizedBox(height: 3),
          Text(
            'PEN',
            style: _ts(
              size: 7,
              weight: FontWeight.w800,
              color: _P.amber,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }

  Widget _partidoPill({required bool jugado, required String label}) {
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

  Widget _compactTeam({
    required String logoUrl,
    required String nombre,
    required int? goles,
    required bool gana,
    required bool pierde,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  _logoCircle(logoUrl, size: 34),
                  if (pierde)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _P.surface.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                nombre.isNotEmpty ? _abreviar(nombre) : '—',
                style: _ts(
                  size: 8,
                  weight: gana ? FontWeight.w700 : FontWeight.w400,
                  color: pierde
                      ? _P.border
                      : gana
                      ? _P.navy
                      : _P.slate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (goles != null) ...[
          const SizedBox(width: 4),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: gana ? _P.blueLight : _P.bg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: gana ? _P.blue.withOpacity(0.3) : _P.border,
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$goles',
              style: _ts(
                size: 10,
                weight: FontWeight.w800,
                color: gana ? _P.blue : _P.slate,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _emptyLogoSlot(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Divider(height: 0, thickness: 0.5, color: _P.border),
          ),
          _emptyLogoSlot(),
        ],
      ),
    );
  }

  Widget _emptyLogoSlot() {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _P.bg,
            shape: BoxShape.circle,
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Icon(Icons.shield_outlined, color: _P.border, size: 16),
        ),
        const SizedBox(height: 4),
        Text('???', style: _ts(size: 8, color: _P.border)),
      ],
    );
  }

  Widget _finalCruceCard(Cruce? c) {
    final hayGanador = c?.ganadorCruceId != null;
    final sinEq1 =
        c == null || (c.equipo1Id == null && c.equipo1Nombre.isEmpty);
    final sinEq2 =
        c == null || (c.equipo2Id == null && c.equipo2Nombre.isEmpty);
    final totalmenteVacio = sinEq1 && sinEq2;
    final eq1gana = c != null && hayGanador && c.ganadorCruceId == c.equipo1Id;
    final eq2gana = c != null && hayGanador && c.ganadorCruceId == c.equipo2Id;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.heroMid, _P.heroDark],
        ),
        border: Border.all(
          color: hayGanador
              ? _P.amber.withOpacity(0.5)
              : _P.blue.withOpacity(0.3),
          width: hayGanador ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hayGanador
                ? _P.amber.withOpacity(0.12)
                : _P.blue.withOpacity(0.10),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: hayGanador ? _P.amber : Colors.white.withOpacity(0.3),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  'GRAN FINAL',
                  style: _ts(
                    size: 7,
                    weight: FontWeight.w800,
                    color: hayGanador
                        ? _P.amber
                        : Colors.white.withOpacity(0.4),
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
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: totalmenteVacio
                ? Column(
                    children: [
                      _emptyLogoSlotDark(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          'VS',
                          style: _ts(
                            size: 7,
                            color: Colors.white.withOpacity(0.2),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      _emptyLogoSlotDark(),
                    ],
                  )
                : Column(
                    children: [
                      sinEq1
                          ? _emptyLogoSlotDark()
                          : _finalTeam(
                              logoUrl: c!.equipo1LogoUrl,
                              nombre: c.equipo1Nombre,
                              goles: (c.idaJugada || c.vueltaJugada)
                                  ? c.golesGlobalesEq1
                                  : null,
                              gana: eq1gana,
                              pierde: hayGanador && !eq1gana,
                            ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
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
                                horizontal: 6,
                              ),
                              child: Text(
                                c!.resuelto
                                    ? 'FT'
                                    : (c.idaJugada ? 'IDA' : 'I+V'),
                                style: _ts(
                                  size: 7,
                                  weight: FontWeight.w800,
                                  color: c.resuelto
                                      ? const Color(0xFF7AAECB)
                                      : Colors.white.withOpacity(0.3),
                                  letterSpacing: 1,
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
                      sinEq2
                          ? _emptyLogoSlotDark()
                          : _finalTeam(
                              logoUrl: c.equipo2LogoUrl,
                              nombre: c.equipo2Nombre,
                              goles: (c.idaJugada || c.vueltaJugada)
                                  ? c.golesGlobalesEq2
                                  : null,
                              gana: eq2gana,
                              pierde: hayGanador && !eq2gana,
                            ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _finalPartidoPill(jugado: c.idaJugada, label: 'IDA'),
                          const SizedBox(width: 4),
                          _finalPartidoPill(
                            jugado: c.vueltaJugada,
                            label: 'VUELTA',
                          ),
                        ],
                      ),
                      if (c.vuelta?.penales == true && c.resuelto) ...[
                        const SizedBox(height: 6),
                        Text(
                          'PENALES',
                          style: _ts(
                            size: 7,
                            weight: FontWeight.w800,
                            color: _P.amber,
                            letterSpacing: 1,
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
              color: _P.amber.withOpacity(0.25),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: _P.amber.withOpacity(0.10),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Text(
                '🏆  CAMPEÓN',
                textAlign: TextAlign.center,
                style: _ts(
                  size: 8,
                  weight: FontWeight.w800,
                  color: _P.amber,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _finalPartidoPill({required bool jugado, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: jugado
            ? _P.amber.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: jugado
              ? _P.amber.withOpacity(0.4)
              : Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: _ts(
          size: 7,
          weight: FontWeight.w700,
          color: jugado ? _P.amber : Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _finalTeam({
    required String logoUrl,
    required String nombre,
    required int? goles,
    required bool gana,
    required bool pierde,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  _logoCircle(logoUrl, size: 34, darkBg: true),
                  if (pierde)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _P.heroDark.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                nombre.isNotEmpty ? _abreviar(nombre) : '—',
                style: _ts(
                  size: 8,
                  weight: gana ? FontWeight.w700 : FontWeight.w400,
                  color: pierde
                      ? Colors.white.withOpacity(0.2)
                      : gana
                      ? Colors.white
                      : const Color(0xFF7AAECB),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (goles != null) ...[
          const SizedBox(width: 4),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: gana
                  ? _P.amber.withOpacity(0.20)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: gana
                    ? _P.amber.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$goles',
              style: _ts(
                size: 10,
                weight: FontWeight.w800,
                color: gana ? _P.amber : Colors.white.withOpacity(0.25),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyLogoSlotDark() {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
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
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text('???', style: _ts(size: 8, color: Colors.white.withOpacity(0.15))),
      ],
    );
  }

  Widget _leyendaItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: _ts(size: 9, color: _P.slate)),
      ],
    );
  }

  String _abreviar(String nombre) => nombre.trim().split(' ').first;

  Widget _logoCircle(String? url, {double size = 28, bool darkBg = false}) {
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: darkBg ? Colors.white.withOpacity(0.08) : _P.bg,
          shape: BoxShape.circle,
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
          decoration: BoxDecoration(
            color: darkBg ? Colors.white.withOpacity(0.08) : _P.bg,
            shape: BoxShape.circle,
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: darkBg ? Colors.white.withOpacity(0.08) : _P.bg,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shield_outlined, color: _P.slate, size: size * 0.5),
        ),
      ),
    );
  }
} // ← CIERRE DEL STATE

// ─── BRACKET LINES OVERLAY ────────────────────────────────────────────────
class _BracketLinesOverlay extends StatefulWidget {
  final List<_Connection> connections;
  const _BracketLinesOverlay({super.key, required this.connections});
  @override
  State<_BracketLinesOverlay> createState() => _BracketLinesOverlayState();
}

class _BracketLinesOverlayState extends State<_BracketLinesOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BracketLinesPainter(
      connections: widget.connections,
      overlayContext: context,
    ),
  );
}

// ─── BRACKET LINES PAINTER ────────────────────────────────────────────────
class _BracketLinesPainter extends CustomPainter {
  final List<_Connection> connections;
  final BuildContext overlayContext;
  const _BracketLinesPainter({
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
      final startX = conn.isLeft
          ? fromLocal.dx + fromBox.size.width
          : fromLocal.dx;
      final endX = conn.isLeft ? toLocal.dx : toLocal.dx + toBox.size.width;
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
  bool shouldRepaint(_BracketLinesPainter old) =>
      old.connections != connections;
}
