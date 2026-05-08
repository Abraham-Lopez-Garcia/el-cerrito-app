// lib/widgets/liguilla_download_dialog.dart
//
// Uso:
//   import '../widgets/liguilla_download_dialog.dart';
//
//   showDialog(
//     context: context,
//     builder: (_) => LiguillaDownloadDialog(
//       cruces: _cruces,          // List<Cruce> de la liguilla activa
//       liguillaLabel: 'A',       // o 'B'
//     ),
//   );

import 'dart:io';
import 'dart:math' show cos, sin, pi;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/liguilla_model.dart';

// ─── PALETA (igual a la del proyecto) ─────────────────────────────────────────
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

// ─── Opciones de ronda ────────────────────────────────────────────────────────
enum _RondaOpcion { todos, previo, cuartos, semis, final_ }

extension _RondaOpcionExt on _RondaOpcion {
  String get label {
    switch (this) {
      case _RondaOpcion.todos:
        return 'Todos los cruces';
      case _RondaOpcion.previo:
        return 'Ronda previa (Octavos)';
      case _RondaOpcion.cuartos:
        return 'Cuartos de final';
      case _RondaOpcion.semis:
        return 'Semifinales';
      case _RondaOpcion.final_:
        return 'Gran Final';
    }
  }

  String get firestoreKey {
    switch (this) {
      case _RondaOpcion.todos:
        return '';
      case _RondaOpcion.previo:
        return 'previo';
      case _RondaOpcion.cuartos:
        return 'cuartos';
      case _RondaOpcion.semis:
        return 'semis';
      case _RondaOpcion.final_:
        return 'final';
    }
  }

  String get badgeLabel {
    switch (this) {
      case _RondaOpcion.todos:
        return 'LIGUILLA';
      case _RondaOpcion.previo:
        return 'OCTAVOS';
      case _RondaOpcion.cuartos:
        return 'CUARTOS';
      case _RondaOpcion.semis:
        return 'SEMIFINAL';
      case _RondaOpcion.final_:
        return 'GRAN FINAL';
    }
  }

  Color get color {
    switch (this) {
      case _RondaOpcion.todos:
        return const Color(0xFF8B5CF6);
      case _RondaOpcion.previo:
        return const Color(0xFF8B5CF6);
      case _RondaOpcion.cuartos:
        return _P.blue;
      case _RondaOpcion.semis:
        return _P.green;
      case _RondaOpcion.final_:
        return _P.amber;
    }
  }
}

// ─── DIALOG PRINCIPAL ─────────────────────────────────────────────────────────
class LiguillaDownloadDialog extends StatefulWidget {
  final List<Cruce> cruces;
  final String liguillaLabel; // 'A' o 'B'

  const LiguillaDownloadDialog({
    super.key,
    required this.cruces,
    required this.liguillaLabel,
  });

  @override
  State<LiguillaDownloadDialog> createState() => _LiguillaDownloadDialogState();
}

class _LiguillaDownloadDialogState extends State<LiguillaDownloadDialog> {
  // ── Modo ──────────────────────────────────────────────────────────────────
  bool _isRondaCompleta =
      true; // true = ronda/todos, false = partido específico

  // ── Selección ronda ───────────────────────────────────────────────────────
  _RondaOpcion _rondaSeleccionada = _RondaOpcion.todos;

  // ── Selección partido específico ──────────────────────────────────────────
  _RondaOpcion _rondaPartido = _RondaOpcion.cuartos;
  int? _cruceIndex; // índice dentro de la ronda seleccionada
  int _partidoNumero = 1; // 1 = Ida, 2 = Vuelta

  // ── Fondo ─────────────────────────────────────────────────────────────────
  bool _usarFondo = false;
  File? _imagenFondo;

  // ── Estado generación ─────────────────────────────────────────────────────
  bool _isGenerating = false;
  bool _isGeneratingPreview = false;
  Uint8List? _previewBytes;

  // ── Pool de imágenes cargadas ─────────────────────────────────────────────
  final Map<String, ui.Image> _imagePool = {};

  // ─── Helpers de datos ──────────────────────────────────────────────────────
  List<Cruce> get _crucesDeRonda {
    final key = _rondaPartido.firestoreKey;
    if (key.isEmpty) return widget.cruces;
    return widget.cruces.where((c) => c.ronda == key).toList();
  }

  List<Cruce> get _crucesParaImagen {
    final key = _rondaSeleccionada.firestoreKey;
    if (key.isEmpty) return widget.cruces;
    return widget.cruces.where((c) => c.ronda == key).toList();
  }

  Cruce? get _cruceSeleccionado {
    final lista = _crucesDeRonda;
    if (_cruceIndex == null || _cruceIndex! >= lista.length) return null;
    return lista[_cruceIndex!];
  }

  bool get _puedeGenerar {
    if (_isRondaCompleta) {
      return _crucesParaImagen.isNotEmpty;
    }
    return _cruceSeleccionado != null && (!_usarFondo || _imagenFondo != null);
  }

  // ─── Carga de imágenes ────────────────────────────────────────────────────
  Future<ui.Image?> _getImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (_imagePool.containsKey(url)) return _imagePool[url];
    try {
      final req = await HttpClient().getUrl(Uri.parse(url));
      final res = await req.close();
      final bytes = await res.toList().then(
        (chunks) => Uint8List.fromList(chunks.expand((x) => x).toList()),
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _imagePool[url] = frame.image;
      return frame.image;
    } catch (e) {
      debugPrint('Error cargando logo: $url — $e');
      return null;
    }
  }

  Future<void> _preloadLogos(List<Cruce> cruces) async {
    final urls = cruces
        .expand((c) => [c.equipo1LogoUrl, c.equipo2LogoUrl])
        .where((url) => url.isNotEmpty && !_imagePool.containsKey(url))
        .toSet();
    await Future.wait(urls.map(_getImage));
  }

  // ─── Selección de fondo ───────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _imagenFondo = File(file.path);
        _previewBytes = null;
      });
    }
  }

  // ─── Vista previa ─────────────────────────────────────────────────────────
  Future<void> _generatePreview() async {
    if (_isGeneratingPreview) return;
    setState(() {
      _isGeneratingPreview = true;
      _previewBytes = null;
    });
    try {
      final bytes = await _buildImage();
      if (mounted) setState(() => _previewBytes = bytes);
    } catch (e) {
      if (mounted) _showSnack('Error generando vista previa: $e', error: true);
    } finally {
      if (mounted) setState(() => _isGeneratingPreview = false);
    }
  }

  // ─── Descarga ─────────────────────────────────────────────────────────────
  Future<void> _download() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      var status = await Permission.photos.status;
      if (!status.isGranted) status = await Permission.photos.request();
      if (!status.isGranted) throw Exception('Permiso denegado');

      final bytes = _previewBytes ?? await _buildImage();
      if (bytes != null) {
        await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name: 'liguilla_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) {
          Navigator.pop(context);
          _showSnack('Imagen guardada en la galería');
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ─── Dispatcher de generación ─────────────────────────────────────────────
  Future<Uint8List?> _buildImage() async {
    if (_isRondaCompleta) {
      final cruces = _crucesParaImagen;
      await _preloadLogos(cruces);
      return _generateRondaImage(cruces, _rondaSeleccionada);
    } else {
      final cruce = _cruceSeleccionado!;
      await _preloadLogos([cruce]);
      if (_usarFondo && _imagenFondo != null) {
        return _generatePartidoConFondo(cruce, _partidoNumero);
      }
      return _generatePartidoSimple(cruce, _partidoNumero);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN: RONDA COMPLETA
  // ══════════════════════════════════════════════════════════════════════════
  Future<Uint8List?> _generateRondaImage(
    List<Cruce> cruces,
    _RondaOpcion ronda,
  ) async {
    const w = 1080.0;
    final headerH = 260.0;
    final cruceH = 300.0;
    final footerH = 40.0;
    final h = headerH + cruces.length * cruceH + footerH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawBackground(canvas, w, h);
    await _drawLeagueLogoWatermark(canvas, w, h, centerVertical: true);

    // ── Header ──────────────────────────────────────────────────────────────
    _drawTextCentered(
      canvas,
      'LIGUILLA ${widget.liguillaLabel}',
      const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF7AAECB),
        letterSpacing: 4,
      ),
      w,
      44,
    );
    _drawTextCentered(
      canvas,
      ronda == _RondaOpcion.todos ? 'TODOS LOS CRUCES' : ronda.badgeLabel,
      TextStyle(
        fontSize: ronda == _RondaOpcion.todos ? 68 : 80,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 2,
        shadows: const [
          Shadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 8),
        ],
      ),
      w,
      78,
    );

    // Línea decorativa bajo el header
    final sep = Paint()
      ..color = ronda.color.withOpacity(0.7)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(w * 0.20, 200), Offset(w * 0.80, 200), sep);

    // ── Cruces ───────────────────────────────────────────────────────────────
    double y = headerH;
    for (int i = 0; i < cruces.length; i++) {
      await _drawCruceRowV2(canvas, cruces[i], y, w, cruceH, i);
      y += cruceH;
      if (i < cruces.length - 1) {
        final divPaint = Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(60, y - 8), Offset(w - 60, y - 8), divPaint);
      }
    }

    return _finalize(recorder, w, h);
  }

  Future<void> _drawCruceRowV2(
    Canvas canvas,
    Cruce c,
    double y,
    double w,
    double rowH,
    int index,
  ) async {
    final centerX = w / 2;
    final logoSize = w * 0.10; // proporcional como en vertical con fondo
    final logoXSpacing = w * 0.22; // distancia del centro a cada logo
    final rowCenterY = y + rowH / 2;

    // Número de cruce — esquina izquierda
    _drawText(
      canvas,
      'Cruce ${index + 1}',
      const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7AAECB),
        letterSpacing: 1,
      ),
      Offset(48, y + 16),
    );

    if (!c.tieneEquipos) {
      _drawTextCentered(
        canvas,
        'EN ESPERA',
        const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A5568),
          letterSpacing: 3,
        ),
        w,
        rowCenterY - 16,
      );
      return;
    }

    // ── Logos ────────────────────────────────────────────────────────────────
    final logo1 = await _getImage(c.equipo1LogoUrl);
    final logo2 = await _getImage(c.equipo2LogoUrl);

    final logo1X = centerX - logoXSpacing - logoSize / 2;
    final logo2X = centerX + logoXSpacing - logoSize / 2;
    final logoY = rowCenterY - logoSize - w * 0.018;

    if (logo1 != null) {
      _drawCircularLogo(canvas, logo1, Offset(logo1X, logoY), logoSize);
    } else {
      _drawLogoFallback(
        canvas,
        c.equipo1Nombre,
        Offset(logo1X, logoY),
        logoSize,
      );
    }
    if (logo2 != null) {
      _drawCircularLogo(canvas, logo2, Offset(logo2X, logoY), logoSize);
    } else {
      _drawLogoFallback(
        canvas,
        c.equipo2Nombre,
        Offset(logo2X, logoY),
        logoSize,
      );
    }

    // ── Nombres ──────────────────────────────────────────────────────────────
    final nameY = logoY + logoSize + 10;
    _drawTextAt(
      canvas,
      c.equipo1Nombre,
      const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      centerX - logoXSpacing,
      nameY,
      maxWidth: w * 0.30,
      centered: true,
    );
    _drawTextAt(
      canvas,
      c.equipo2Nombre,
      const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      centerX + logoXSpacing,
      nameY,
      maxWidth: w * 0.30,
      centered: true,
    );

    // ── Marcador o VS ─────────────────────────────────────────────────────────
    final scoreCenterY = logoY + logoSize / 2; // ← centrado con los logos

    if (c.idaJugada || c.vueltaJugada) {
      final g1 = c.golesGlobalesEq1.toString();
      final g2 = c.golesGlobalesEq2.toString();
      final scoreFontSize = w * 0.095;

      final p1 = TextPainter(
        text: TextSpan(
          text: g1,
          style: TextStyle(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamily: 'monospace',
            shadows: const [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p2 = TextPainter(
        text: TextSpan(
          text: g2,
          style: TextStyle(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamily: 'monospace',
            shadows: const [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      p1.paint(
        canvas,
        Offset(centerX - w * 0.025 - p1.width, scoreCenterY - p1.height / 2),
      );
      p2.paint(
        canvas,
        Offset(centerX + w * 0.025, scoreCenterY - p2.height / 2),
      );

      // Divisor entre scores
      final divPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.6),
                Colors.white.withOpacity(0.6),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ).createShader(
              Rect.fromLTWH(
                centerX - w * 0.002,
                scoreCenterY - scoreFontSize * 0.55,
                w * 0.004,
                scoreFontSize * 1.1,
              ),
            )
        ..strokeWidth = w * 0.003
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(centerX, scoreCenterY - scoreFontSize * 0.55),
        Offset(centerX, scoreCenterY + scoreFontSize * 0.55),
        divPaint,
      );

      // Label GLOBAL — encima del marcador
      _drawTextCentered(
        canvas,
        'GLOBAL',
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7AAECB),
          letterSpacing: 2,
        ),
        w,
        logoY - 22,
      );

      // Fecha de vuelta (si la ida ya jugó pero la vuelta aún no)
      if (c.idaJugada &&
          !c.vueltaJugada &&
          c.vuelta != null &&
          c.vuelta!.fecha != null) {
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
        final vuelta = c.vuelta!;
        final dateStr =
            'Vuelta: ${vuelta.fecha!.day} ${meses[vuelta.fecha!.month - 1]}';
        final horaStr = vuelta.hora != null && vuelta.hora!.isNotEmpty
            ? '  ${vuelta.hora!}'
            : '';
        _drawTextCentered(
          canvas,
          '$dateStr$horaStr',
          TextStyle(
            fontSize: w * 0.022,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF00D9FF),
            letterSpacing: 0.5,
          ),
          w,
          nameY + 28,
        );
      }

      // Ganador
      if (c.resuelto) {
        _drawTextCentered(
          canvas,
          '🏆 ${c.ganadorNombre} avanza',
          const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF27AE60),
            letterSpacing: 0.5,
          ),
          w,
          nameY + 28,
        );
      }
    } else {
      // Sin resultado — mostrar fecha/hora si existe, si no VS
      final partido = c.ida; // la ida siempre existe
      if (partido.fecha != null) {
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
        final dateStr =
            '${partido.fecha!.day} ${meses[partido.fecha!.month - 1]}';
        _drawTextCentered(
          canvas,
          dateStr,
          TextStyle(
            fontSize: w * 0.042,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
          w,
          scoreCenterY - w * 0.030,
        );
        if (partido.hora != null && partido.hora!.isNotEmpty) {
          _drawTextCentered(
            canvas,
            partido.hora!,
            TextStyle(
              fontSize: w * 0.028,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF00D9FF),
              fontFamily: 'monospace',
            ),
            w,
            scoreCenterY + w * 0.018,
          );
        }
      } else {
        _drawTextCentered(
          canvas,
          'VS',
          TextStyle(
            fontSize: w * 0.055,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4A5568),
            letterSpacing: 6,
          ),
          w,
          scoreCenterY - w * 0.025,
        );
      }
    }
  }

  void _drawBackground(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E3A5F), Color(0xFF0D1F3D)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // Líneas decorativas sutiles
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < w; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), linePaint);
    }
  }

  void _drawRondaHeader(
    Canvas canvas,
    double w,
    _RondaOpcion ronda,
    String liga,
  ) {
    // Badge de liga
    _drawTextCentered(
      canvas,
      'LIGUILLA $liga',
      const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF7AAECB),
        letterSpacing: 3,
      ),
      w,
      42,
    );

    // Título de ronda
    _drawTextCentered(
      canvas,
      ronda == _RondaOpcion.todos ? 'TODOS LOS CRUCES' : ronda.badgeLabel,
      TextStyle(
        fontSize: ronda == _RondaOpcion.todos ? 52 : 60,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 2,
        shadows: const [
          Shadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 8),
        ],
      ),
      w,
      80,
    );

    // Línea separadora
    final sep = Paint()
      ..color = ronda.color.withOpacity(0.6)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(w * 0.25, 160), Offset(w * 0.75, 160), sep);
  }

  Future<void> _drawCruceRow(
    Canvas canvas,
    Cruce c,
    double y,
    double w,
    int index,
  ) async {
    final centerX = w / 2;
    final logoSize = 80.0;
    final logoPad = 180.0; // distancia del centro al logo
    final scoreY = y + 80;
    final logoY = y + 50;
    final nameY = logoY + logoSize + 10;

    // Número de cruce
    _drawText(
      canvas,
      'Cruce ${index + 1}',
      const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7AAECB),
        letterSpacing: 1,
      ),
      Offset(60, y + 20),
    );

    if (!c.tieneEquipos) {
      // En espera
      _drawTextCentered(
        canvas,
        'EN ESPERA',
        const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A5568),
          letterSpacing: 2,
        ),
        w,
        y + 100,
      );
      return;
    }

    // Logos
    final logo1 = await _getImage(c.equipo1LogoUrl);
    final logo2 = await _getImage(c.equipo2LogoUrl);

    if (logo1 != null) {
      _drawCircularLogo(
        canvas,
        logo1,
        Offset(centerX - logoPad - logoSize, logoY),
        logoSize,
      );
    } else {
      _drawLogoFallback(
        canvas,
        c.equipo1Nombre,
        Offset(centerX - logoPad - logoSize, logoY),
        logoSize,
      );
    }
    if (logo2 != null) {
      _drawCircularLogo(
        canvas,
        logo2,
        Offset(centerX + logoPad, logoY),
        logoSize,
      );
    } else {
      _drawLogoFallback(
        canvas,
        c.equipo2Nombre,
        Offset(centerX + logoPad, logoY),
        logoSize,
      );
    }

    // Nombres
    _drawTextAt(
      canvas,
      c.equipo1Nombre,
      const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      centerX - logoPad - logoSize + logoSize / 2,
      nameY,
      maxWidth: 230,
      centered: true,
    );
    _drawTextAt(
      canvas,
      c.equipo2Nombre,
      const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      centerX + logoPad + logoSize / 2,
      nameY,
      maxWidth: 230,
      centered: true,
    );

    // Marcador global o VS
    if (c.idaJugada || c.vueltaJugada) {
      // Marcador global
      _drawTextCentered(
        canvas,
        '${c.golesGlobalesEq1}  –  ${c.golesGlobalesEq2}',
        const TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          color: Color(0xFF00D9FF),
          fontFamily: 'monospace',
          shadows: [
            Shadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 10),
          ],
        ),
        w,
        scoreY,
      );
      _drawTextCentered(
        canvas,
        'GLOBAL',
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7AAECB),
          letterSpacing: 2,
        ),
        w,
        scoreY + 55,
      );
    } else {
      _drawTextCentered(
        canvas,
        'VS',
        const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4A5568),
          letterSpacing: 6,
        ),
        w,
        scoreY + 8,
      );
    }

    // Tag ganador
    if (c.resuelto) {
      _drawTextCentered(
        canvas,
        '🏆 ${c.ganadorNombre} avanza',
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF27AE60),
          letterSpacing: 0.5,
        ),
        w,
        y + 220,
      );
    }
  }

  void _drawDivider(Canvas canvas, double w, double y) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(60, y), Offset(w - 60, y), paint);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN: PARTIDO INDIVIDUAL (SIN FONDO)
  // ══════════════════════════════════════════════════════════════════════════
  Future<Uint8List?> _generatePartidoSimple(Cruce c, int partidoNum) async {
    const w = 1080.0;
    const h = 1550.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _drawBackground(canvas, w, h);
    await _drawLeagueLogoWatermark(canvas, w, h, centerVertical: true);

    final partido = partidoNum == 1 ? c.ida : (c.vuelta ?? c.ida);
    final ronda = _rondaFromString(c.ronda);

    // ── Header ────────────────────────────────────────────────────────────────
    _drawTextCentered(
      canvas,
      ronda.badgeLabel,
      TextStyle(
        fontSize: w * 0.13,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: w * 0.008,
        shadows: const [
          Shadow(color: Colors.black, offset: Offset(0, 4), blurRadius: 14),
          Shadow(color: Colors.black54, offset: Offset(0, 8), blurRadius: 24),
        ],
      ),
      w,
      h * 0.03,
    );
    _drawTextCentered(
      canvas,
      partidoNum == 1 ? 'IDA' : 'VUELTA',
      TextStyle(
        fontSize: w * 0.09,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: w * 0.012,
        shadows: [
          Shadow(
            color: ronda.color.withOpacity(0.8),
            offset: const Offset(0, 3),
            blurRadius: 16,
          ),
          const Shadow(
            color: Colors.black87,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      w,
      h * 0.115,
    );

    // Línea separadora
    final sep = Paint()
      ..color = ronda.color.withOpacity(0.7)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(w * 0.20, h * 0.215),
      Offset(w * 0.80, h * 0.215),
      sep,
    );

    // ── Posiciones — bloque centrado en la mitad absoluta de la imagen ────────
    final logoSize = w * 0.18;
    final logoXSpacing = w * 0.28;
    final scoreFontSize = w * 0.16;

    // Altura total del bloque
    final blockH = 50 + logoSize + 20 + 50 + 60;

    // Centro absoluto de la imagen, el bloque arranca la mitad menos la mitad del bloque
    final blockTop = h / 2 - blockH / 2;

    final globalY = blockTop;
    final logoY = globalY + 50;
    final scoreCenterY = logoY + logoSize / 2;
    final nameY = logoY + logoSize + 20;
    final extraY = nameY + 60;

    // ── Logos (en vuelta se invierten) ────────────────────────────────────────
    final logo1 = await _getImage(c.equipo1LogoUrl);
    final logo2 = await _getImage(c.equipo2LogoUrl);
    final logo1X = w / 2 - logoXSpacing - logoSize / 2;
    final logo2X = w / 2 + logoXSpacing - logoSize / 2;

    // En vuelta: equipo2 de la ida juega de local → va a la izquierda
    final logoIzq = partidoNum == 2 ? logo2 : logo1;
    final logoDer = partidoNum == 2 ? logo1 : logo2;
    final nombreIzq = partidoNum == 2 ? c.equipo2Nombre : c.equipo1Nombre;
    final nombreDer = partidoNum == 2 ? c.equipo1Nombre : c.equipo2Nombre;

    if (logoIzq != null) {
      _drawCircularLogo(canvas, logoIzq, Offset(logo1X, logoY), logoSize);
    } else {
      _drawLogoFallback(canvas, nombreIzq, Offset(logo1X, logoY), logoSize);
    }
    if (logoDer != null) {
      _drawCircularLogo(canvas, logoDer, Offset(logo2X, logoY), logoSize);
    } else {
      _drawLogoFallback(canvas, nombreDer, Offset(logo2X, logoY), logoSize);
    }

    // ── Nombres ───────────────────────────────────────────────────────────────
    _drawTextAt(
      canvas,
      nombreIzq,
      TextStyle(
        fontSize: w * 0.040,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      w / 2 - logoXSpacing,
      nameY,
      maxWidth: w * 0.32,
      centered: true,
    );
    _drawTextAt(
      canvas,
      nombreDer,
      TextStyle(
        fontSize: w * 0.040,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      w / 2 + logoXSpacing,
      nameY,
      maxWidth: w * 0.32,
      centered: true,
    );

    // ── Marcador, fecha o VS ──────────────────────────────────────────────────
    if (partido.tieneResultado) {
      final g1 = partido.golesEquipo1.toString();
      final g2 = partido.golesEquipo2.toString();

      final p1 = TextPainter(
        text: TextSpan(
          text: g1,
          style: TextStyle(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamily: 'monospace',
            shadows: const [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p2 = TextPainter(
        text: TextSpan(
          text: g2,
          style: TextStyle(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamily: 'monospace',
            shadows: const [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      p1.paint(
        canvas,
        Offset(w / 2 - w * 0.025 - p1.width, scoreCenterY - p1.height / 2),
      );
      p2.paint(canvas, Offset(w / 2 + w * 0.025, scoreCenterY - p2.height / 2));

      // Divisor
      final divPaint = Paint()
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
                w / 2 - w * 0.002,
                scoreCenterY - scoreFontSize * 0.55,
                w * 0.004,
                scoreFontSize * 1.1,
              ),
            )
        ..strokeWidth = w * 0.003
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(w / 2, scoreCenterY - scoreFontSize * 0.55),
        Offset(w / 2, scoreCenterY + scoreFontSize * 0.55),
        divPaint,
      );

      if (partido.penales) {
        _drawTextCentered(
          canvas,
          'DEFINIDO EN PENALES',
          const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF39C12),
            letterSpacing: 2,
          ),
          w,
          scoreCenterY + scoreFontSize * 0.65,
        );
      }
    } else {
      // Sin resultado — fecha/hora o VS centrado con los logos
      if (partido.fecha != null) {
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
        final dateStr =
            '${partido.fecha!.day} ${meses[partido.fecha!.month - 1]}';
        _drawTextCentered(
          canvas,
          dateStr,
          TextStyle(
            fontSize: w * 0.075,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
            shadows: const [
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          w,
          scoreCenterY - w * 0.050,
        );
        if (partido.hora != null && partido.hora!.isNotEmpty) {
          _drawTextCentered(
            canvas,
            partido.hora!,
            TextStyle(
              fontSize: w * 0.048,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF00D9FF),
              fontFamily: 'monospace',
            ),
            w,
            scoreCenterY + w * 0.022,
          );
        }
      } else {
        _drawTextCentered(
          canvas,
          'VS',
          TextStyle(
            fontSize: w * 0.09,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4A5568),
            letterSpacing: 6,
          ),
          w,
          scoreCenterY - w * 0.045,
        );
      }
    }

    // ── GLOBAL encima de los logos (solo si la ida ya jugó) ───────────────────
    if (c.idaJugada) {
      _drawTextCentered(
        canvas,
        'GLOBAL',
        const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7AAECB),
          letterSpacing: 2,
        ),
        w,
        globalY,
      );
      final globalIzq = partidoNum == 2
          ? c.golesGlobalesEq2
          : c.golesGlobalesEq1;
      final globalDer = partidoNum == 2
          ? c.golesGlobalesEq1
          : c.golesGlobalesEq2;
      _drawTextCentered(
        canvas,
        '$globalIzq  –  $globalDer',
        TextStyle(
          fontSize: w * 0.025,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontFamily: 'monospace',
          shadows: const [
            Shadow(color: Colors.black87, offset: Offset(0, 3), blurRadius: 8),
          ],
        ),
        w,
        globalY + 28,
      );
    }

    // ── Fecha de vuelta (si ida jugó pero vuelta aún no) ──────────────────────
    if (c.idaJugada &&
        !c.vueltaJugada &&
        c.vuelta != null &&
        c.vuelta!.fecha != null) {
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
      final vuelta = c.vuelta!;
      final dateStr =
          'Vuelta: ${vuelta.fecha!.day} ${meses[vuelta.fecha!.month - 1]}';
      final horaStr = vuelta.hora != null && vuelta.hora!.isNotEmpty
          ? '  ${vuelta.hora!}'
          : '';
      _drawTextCentered(
        canvas,
        '$dateStr$horaStr',
        TextStyle(
          fontSize: w * 0.030,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF00D9FF),
          letterSpacing: 0.5,
        ),
        w,
        extraY,
      );
    }

    // ── Ganador ───────────────────────────────────────────────────────────────
    if (c.resuelto) {
      _drawTextCentered(
        canvas,
        '🏆 ${c.ganadorNombre} avanza',
        TextStyle(
          fontSize: w * 0.032,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF27AE60),
          letterSpacing: 0.5,
        ),
        w,
        extraY,
      );
    }

    return _finalize(recorder, w, h);
  }

  void _drawPartidoHeader(
    Canvas canvas,
    double w,
    _RondaOpcion ronda,
    int partidoNum,
    Cruce c,
  ) {
    // Ronda badge
    _drawTextCentered(
      canvas,
      ronda.badgeLabel,
      TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: ronda.color,
        letterSpacing: 3,
      ),
      w,
      120,
    );

    // Ida / Vuelta
    final idaVuelta = partidoNum == 1 ? 'IDA' : 'VUELTA';
    _drawTextCentered(
      canvas,
      idaVuelta,
      const TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 4,
        shadows: [
          Shadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 8),
        ],
      ),
      w,
      156,
    );
  }

  void _drawPartidoScore(Canvas canvas, double w, PartidoLiguilla p) {
    _drawTextCentered(
      canvas,
      '${p.golesEquipo1}  –  ${p.golesEquipo2}',
      const TextStyle(
        fontSize: 100,
        fontWeight: FontWeight.w900,
        color: Color(0xFF00D9FF),
        fontFamily: 'monospace',
        shadows: [
          Shadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 12),
        ],
      ),
      w,
      540,
    );
    if (p.penales) {
      _drawTextCentered(
        canvas,
        'DEFINIDO EN PENALES',
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF39C12),
          letterSpacing: 2,
        ),
        w,
        640,
      );
    }
  }

  void _drawVsBlock(
    Canvas canvas,
    PartidoLiguilla p,
    double w,
    double centerY,
  ) {
    if (p.fecha != null) {
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
      final dateStr = '${p.fecha!.day} ${meses[p.fecha!.month - 1]}';
      _drawTextCentered(
        canvas,
        dateStr,
        const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 2,
        ),
        w,
        centerY - 40,
      );
      if (p.hora != null && p.hora!.isNotEmpty) {
        _drawTextCentered(
          canvas,
          p.hora!,
          const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Color(0xFF00D9FF),
            fontFamily: 'monospace',
          ),
          w,
          centerY + 28,
        );
      }
    } else {
      _drawTextCentered(
        canvas,
        'VS',
        const TextStyle(
          fontSize: 88,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4A5568),
          letterSpacing: 8,
        ),
        w,
        centerY,
      );
    }
  }

  void _drawGlobalScore(Canvas canvas, Cruce c, double w, double y) {
    // Fondo pill
    final pillPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, y - 10, w * 0.6, 80),
      const Radius.circular(16),
    );
    canvas.drawRRect(pillRect, pillPaint);

    _drawTextCentered(
      canvas,
      'GLOBAL',
      const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF7AAECB),
        letterSpacing: 2,
      ),
      w,
      y + 4,
    );
    _drawTextCentered(
      canvas,
      '${c.golesGlobalesEq1}  –  ${c.golesGlobalesEq2}',
      const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w900,
        color: Colors.white70,
        fontFamily: 'monospace',
      ),
      w,
      y + 24,
    );
  }

  void _drawGlobalScoreSimple(
    Canvas canvas,
    Cruce c,
    double w,
    double y, {
    bool invertir = false,
  }) {
    final g1 = invertir ? c.golesGlobalesEq2 : c.golesGlobalesEq1;
    final g2 = invertir ? c.golesGlobalesEq1 : c.golesGlobalesEq2;
    _drawTextCentered(
      canvas,
      'GLOBAL',
      TextStyle(
        fontSize: w * 0.018,
        fontWeight: FontWeight.w700,
        color: Colors.white70,
        letterSpacing: w * 0.003,
      ),
      w,
      y,
    );
    _drawTextCentered(
      canvas,
      '$g1  –  $g2',
      TextStyle(
        fontSize: w * 0.030,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFamily: 'monospace',
        shadows: [
          Shadow(
            color: Colors.black87,
            offset: Offset(0, w * 0.002),
            blurRadius: w * 0.006,
          ),
        ],
      ),
      w,
      y + w * 0.022,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN: PARTIDO CON FONDO PERSONALIZADO
  // ══════════════════════════════════════════════════════════════════════════
  Future<Uint8List?> _generatePartidoConFondo(Cruce c, int partidoNum) async {
    final bgBytes = await _imagenFondo!.readAsBytes();
    final codec = await ui.instantiateImageCodec(bgBytes);
    final frame = await codec.getNextFrame();
    final bgImage = frame.image;

    final w = bgImage.width.toDouble();
    final h = bgImage.height.toDouble();
    final isVertical = h > w;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fondo
    canvas.drawImage(bgImage, Offset.zero, Paint());

    // Gradiente inferior oscurecedor
    final gradBot = Paint()
      ..shader = LinearGradient(
        begin: isVertical ? Alignment.topCenter : Alignment.centerRight,
        end: isVertical ? Alignment.bottomCenter : Alignment.centerLeft,
        colors: [Colors.transparent, Colors.black.withOpacity(0.92)],
        stops: const [0.25, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), gradBot);

    // Degradado superior (para resaltar texto de fase)
    final gradTop = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withOpacity(0.70), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, isVertical ? h * 0.28 : h * 0.35));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, isVertical ? h * 0.28 : h * 0.35),
      gradTop,
    );

    final partido = partidoNum == 1 ? c.ida : (c.vuelta ?? c.ida);
    final ronda = _rondaFromString(c.ronda);

    if (isVertical) {
      await _drawConFondoVertical(canvas, c, partido, ronda, partidoNum, w, h);
    } else {
      await _drawConFondoHorizontal(
        canvas,
        c,
        partido,
        ronda,
        partidoNum,
        w,
        h,
      );
    }

    return _finalize(recorder, w.toInt(), h.toInt());
  }

  Future<void> _drawConFondoVertical(
    Canvas canvas,
    Cruce c,
    PartidoLiguilla partido,
    _RondaOpcion ronda,
    int partidoNum,
    double w,
    double h,
  ) async {
    final logoSize = w * 0.13;
    final scoreFontSize = w * 0.356;
    final centerY = h * 0.72;
    final logoGap = w * 0.18;

    // Logo de la liga — grande, semitransparente, como parte del fondo
    await _drawLeagueLogoWatermark(canvas, w, h);

    // Encabezado principal — ronda grande arriba
    _drawTextCentered(
      canvas,
      ronda.badgeLabel,
      TextStyle(
        fontSize: w * 0.13,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: w * 0.008,
        shadows: const [
          Shadow(color: Colors.black, offset: Offset(0, 4), blurRadius: 14),
          Shadow(color: Colors.black54, offset: Offset(0, 8), blurRadius: 24),
        ],
      ),
      w,
      h * 0.02,
    );

    // Calcular posición del segundo texto en base al primero
    final badgePainter = TextPainter(
      text: TextSpan(
        text: ronda.badgeLabel,
        style: TextStyle(fontSize: w * 0.13, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.9);
    final idaVueltaY = h * 0.02 + (w * 0.13) * 0.95;

    _drawTextCentered(
      canvas,
      partidoNum == 1 ? 'IDA' : 'VUELTA',
      TextStyle(
        fontSize: w * 0.09,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: w * 0.012,
        shadows: [
          Shadow(
            color: ronda.color.withOpacity(0.8),
            offset: Offset(0, 3),
            blurRadius: 16,
          ),
          const Shadow(
            color: Colors.black87,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      w,
      idaVueltaY,
    );

    // ── Misma lógica que matchdays_screen ────────────────────────────────
    final goles1 = partido.tieneResultado
        ? partido.golesEquipo1.toString()
        : '';
    final goles2 = partido.tieneResultado
        ? partido.golesEquipo2.toString()
        : '';

    final logoXSpacing = w * 0.15;
    final extraSpacingPerDigit = w * 0.044;
    final leftX = (w / 2) - logoXSpacing;
    final rightX = (w / 2) + logoXSpacing;

    int maxDigits = 1;
    if (partido.tieneResultado) {
      maxDigits = goles1.length > goles2.length ? goles1.length : goles2.length;
    }
    final extraSpacing = maxDigits > 1
        ? (maxDigits - 1) * extraSpacingPerDigit
        : 0.0;
    final dividerClearance = maxDigits > 1 ? w * 0.036 : 0.0;
    final adjustedLeftX = leftX - extraSpacing - dividerClearance;
    final adjustedRightX = rightX + extraSpacing + dividerClearance;

    final logoTopOffset = w * 0.2;
    final logo1 = await _getImage(c.equipo1LogoUrl);
    final logo2 = await _getImage(c.equipo2LogoUrl);

    // En vuelta: equipo2 de la ida juega de local → va a la izquierda
    final logoIzq = partidoNum == 2 ? logo2 : logo1;
    final logoDer = partidoNum == 2 ? logo1 : logo2;
    final nombreIzq = partidoNum == 2 ? c.equipo2Nombre : c.equipo1Nombre;
    final nombreDer = partidoNum == 2 ? c.equipo1Nombre : c.equipo2Nombre;

    if (logoIzq != null) {
      _drawCircularLogo(
        canvas,
        logoIzq,
        Offset(
          adjustedLeftX - logoSize / 2,
          centerY - logoSize - logoTopOffset,
        ),
        logoSize,
      );
    }
    if (logoDer != null) {
      _drawCircularLogo(
        canvas,
        logoDer,
        Offset(
          adjustedRightX - logoSize / 2,
          centerY - logoSize - logoTopOffset,
        ),
        logoSize,
      );
    }

    // Marcador o VS
    if (partido.tieneResultado) {
      // Scores — mismo estilo que matchdays_screen
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
                offset: Offset(0, h * 0.0015),
                blurRadius: h * 0.003,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

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
                offset: Offset(0, h * 0.0015),
                blurRadius: h * 0.003,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

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

      // Divisor difuminado — idéntico a matchdays_screen
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
                (w / 2) - (w * 0.0022),
                centerY - (scoreFontSize * 0.6),
                w * 0.0044,
                scoreFontSize * 1.2,
              ),
            )
        ..strokeWidth = w * 0.0036
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(w / 2, centerY - (scoreFontSize * 0.6)),
        Offset(w / 2, centerY + (scoreFontSize * 0.6)),
        dividerPaint,
      );
    } else {
      _drawVsBlock(canvas, partido, w, centerY);
    }

    // Nombres — centrados bajo cada logo (invertidos en vuelta)
    final nameY = centerY + scoreFontSize * 0.6 + w * 0.02;
    _drawTextAt(
      canvas,
      nombreIzq,
      TextStyle(
        fontSize: w * 0.038,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      adjustedLeftX,
      nameY,
      maxWidth: w * 0.38,
      centered: true,
    );
    _drawTextAt(
      canvas,
      nombreDer,
      TextStyle(
        fontSize: w * 0.038,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      adjustedRightX,
      nameY,
      maxWidth: w * 0.38,
      centered: true,
    );

    // Global si aplica — justo bajo los logos
    if (c.idaJugada) {
      _drawGlobalScoreSimple(
        canvas,
        c,
        w,
        centerY - logoSize - logoTopOffset + logoSize - w * 0.03,
        invertir: partidoNum == 2,
      );
    }
  }

  Future<void> _drawConFondoHorizontal(
    Canvas canvas,
    Cruce c,
    PartidoLiguilla partido,
    _RondaOpcion ronda,
    int partidoNum,
    double w,
    double h,
  ) async {
    final logoSize = w * 0.15;
    final scoreFontSize = w * 0.15;

    // ── Encabezado — arriba a la derecha, grande y llamativo ──────────────
    final headerText =
        '${ronda.badgeLabel}  ·  ${partidoNum == 1 ? "IDA" : "VUELTA"}';
    final headerPainter = TextPainter(
      text: TextSpan(
        text: headerText,
        style: TextStyle(
          fontSize: w * 0.058,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: w * 0.004,
          shadows: [
            Shadow(
              color: ronda.color.withOpacity(0.9),
              offset: Offset(0, 3),
              blurRadius: 18,
            ),
            const Shadow(
              color: Colors.black87,
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.60);
    headerPainter.paint(
      canvas,
      Offset(w - headerPainter.width - w * 0.04, h * 0.05),
    );

    // Línea decorativa bajo el encabezado
    final linePaint = Paint()
      ..color = ronda.color.withOpacity(0.7)
      ..strokeWidth = w * 0.003
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(
        w - headerPainter.width - w * 0.04,
        h * 0.05 + headerPainter.height + h * 0.015,
      ),
      Offset(w - w * 0.04, h * 0.05 + headerPainter.height + h * 0.015),
      linePaint,
    );

    // ── Filas: equipo1 arriba (h*0.33), equipo2 abajo (h*0.67) ───────────
    final row1CenterY = h * 0.33;
    final row2CenterY = h * 0.67;
    final logoX = w * 0.04;
    final scoreX = logoX + logoSize + w * 0.03;

    // ── Gradientes azules por fila ─────────────────────────────────────────
    final gradientBoxWidth = w * 0.45;
    final gradientBoxHeight = h * 0.30;
    final gradientColor = const Color.fromARGB(
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
        Radius.circular(w * 0.02),
      );
      canvas.drawRRect(
        box,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [gradientColor, Colors.transparent],
            stops: const [0.8, 1.0],
          ).createShader(box.outerRect),
      );
    }

    drawGradientBox(row1CenterY);
    drawGradientBox(row2CenterY);

    final leagueLogoSize = w * 0.06;

    final leagueBox = RRect.fromRectAndRadius(
      Rect.fromLTWH(w - w * 0.10, h / 2 - h * 0.10, w * 0.10, h * 0.20),
      Radius.circular(w * 0.01),
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

    await _drawLeagueLogo(
      canvas,
      Offset(w - leagueLogoSize - w * 0.01, h / 2 - leagueLogoSize / 2),
      leagueLogoSize,
    );

    // ── Equipo 1 ───────────────────────────────────────────────────────────
    final logo1 = await _getImage(c.equipo1LogoUrl);
    if (logo1 != null) {
      _drawCircularLogo(
        canvas,
        logo1,
        Offset(logoX, row1CenterY - logoSize / 2),
        logoSize,
      );
    } else {
      _drawLogoFallback(
        canvas,
        c.equipo1Nombre,
        Offset(logoX, row1CenterY - logoSize / 2),
        logoSize,
      );
    }
    _paintScore(
      canvas,
      partido.tieneResultado ? partido.golesEquipo1.toString() : '?',
      scoreFontSize,
      scoreX,
      row1CenterY,
      h,
    );

    // ── Equipo 2 ───────────────────────────────────────────────────────────
    final logo2 = await _getImage(c.equipo2LogoUrl);
    if (logo2 != null) {
      _drawCircularLogo(
        canvas,
        logo2,
        Offset(logoX, row2CenterY - logoSize / 2),
        logoSize,
      );
    } else {
      _drawLogoFallback(
        canvas,
        c.equipo2Nombre,
        Offset(logoX, row2CenterY - logoSize / 2),
        logoSize,
      );
    }
    _paintScore(
      canvas,
      partido.tieneResultado ? partido.golesEquipo2.toString() : '?',
      scoreFontSize,
      scoreX,
      row2CenterY,
      h,
    );
  }

  void _drawScoreVertical(
    Canvas canvas,
    String g1,
    String g2,
    double fontSize,
    double w,
    double centerY,
  ) {
    final p1 = TextPainter(
      text: TextSpan(
        text: g1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontFamily: 'monospace',
          shadows: const [
            Shadow(color: Colors.black87, offset: Offset(0, 3), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final p2 = TextPainter(
      text: TextSpan(
        text: g2,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontFamily: 'monospace',
          shadows: const [
            Shadow(color: Colors.black87, offset: Offset(0, 3), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final gap = w * 0.06;
    p1.paint(canvas, Offset(w / 2 - gap - p1.width, centerY - p1.height / 2));
    p2.paint(canvas, Offset(w / 2 + gap, centerY - p2.height / 2));

    // Divisor
    final divider = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = w * 0.004
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w / 2, centerY - fontSize * 0.55),
      Offset(w / 2, centerY + fontSize * 0.55),
      divider,
    );
  }

  void _paintScore(
    Canvas canvas,
    String score,
    double fontSize,
    double x,
    double y,
    double imageH,
  ) {
    final p = TextPainter(
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
              offset: Offset(0, imageH * 0.004),
              blurRadius: imageH * 0.008,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, Offset(x, y - p.height / 2));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS CANVAS
  // ══════════════════════════════════════════════════════════════════════════

  void _drawTextCentered(
    Canvas canvas,
    String text,
    TextStyle style,
    double w,
    double y,
  ) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: w * 0.9);
    p.paint(canvas, Offset((w - p.width) / 2, y));
  }

  void _drawText(Canvas canvas, String text, TextStyle style, Offset offset) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, offset);
  }

  /// Pinta texto centrado en [cx], con tope [maxWidth].
  void _drawTextAt(
    Canvas canvas,
    String text,
    TextStyle style,
    double cx,
    double y, {
    double maxWidth = 300,
    bool centered = true,
  }) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: centered ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: maxWidth);
    final dx = centered ? cx - p.width / 2 : cx;
    p.paint(canvas, Offset(dx, y));
  }

  void _drawCircularLogo(
    Canvas canvas,
    ui.Image logo,
    Offset pos,
    double size,
  ) {
    canvas.save();
    final path = Path()..addOval(Rect.fromLTWH(pos.dx, pos.dy, size, size));
    canvas.clipPath(path);
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromLTWH(pos.dx, pos.dy, size, size),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(pos.dx + size / 2, pos.dy + size / 2),
      size / 2,
      Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.035,
    );
  }

  void _drawLogoFallback(
    Canvas canvas,
    String nombre,
    Offset pos,
    double size,
  ) {
    canvas.drawCircle(
      Offset(pos.dx + size / 2, pos.dy + size / 2),
      size / 2,
      Paint()..color = const Color(0xFF1E3A5F),
    );
    canvas.drawCircle(
      Offset(pos.dx + size / 2, pos.dy + size / 2),
      size / 2,
      Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    _drawTextAt(
      canvas,
      initial,
      TextStyle(
        fontSize: size * 0.45,
        fontWeight: FontWeight.w800,
        color: Colors.white70,
      ),
      pos.dx + size / 2,
      pos.dy + size / 2 - size * 0.28,
      centered: true,
    );
  }

  Future<void> _drawLeagueLogoWatermark(
    Canvas canvas,
    double w,
    double h, {
    bool centerVertical = false, // ← agrega esto
  }) async {
    try {
      final data = await rootBundle.load('assets/images/logo_p.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final logo = frame.image;

      final double logoSize = w * 0.90;
      final double offsetX = w / 2 - logoSize / 2;
      final double offsetY = centerVertical
          ? h / 2 -
                logoSize /
                    2 // ← centrado real en Y
          : -h * 0.09; // ← comportamiento original del vertical
      const double opacity = 0.06;

      canvas.saveLayer(
        Rect.fromLTWH(offsetX, offsetY, logoSize, logoSize),
        Paint()..color = Colors.white.withOpacity(opacity),
      );
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, logoSize, logoSize),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    } catch (_) {}
  }

  Future<void> _drawLeagueLogo(Canvas canvas, Offset pos, double size) async {
    try {
      final data = await rootBundle.load('assets/images/logo_p.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final logo = frame.image;

      final logoW = size;
      final logoH = size;

      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromLTWH(pos.dx, pos.dy, logoW, logoH),
        Paint()..filterQuality = FilterQuality.high,
      );
    } catch (_) {}
  }

  Future<Uint8List?> _finalize(
    ui.PictureRecorder recorder,
    num w,
    num h,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  _RondaOpcion _rondaFromString(String s) {
    switch (s) {
      case 'previo':
        return _RondaOpcion.previo;
      case 'cuartos':
        return _RondaOpcion.cuartos;
      case 'semis':
        return _RondaOpcion.semis;
      case 'final':
        return _RondaOpcion.final_;
      default:
        return _RondaOpcion.cuartos;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
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
            _buildHeader(),
            const Divider(height: 0, thickness: 0.5, color: _P.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeToggle(),
                  const SizedBox(height: 18),
                  _isRondaCompleta
                      ? _buildRondaSection()
                      : _buildPartidoSection(),
                  const SizedBox(height: 18),
                  _buildPreviewBtn(),
                  if (_previewBytes != null) _buildPreviewImage(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const Divider(height: 0, thickness: 0.5, color: _P.border),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
            child: const Icon(Icons.download_rounded, color: _P.blue, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descargar imagen',
                  style: _ts(size: 15, weight: FontWeight.w700),
                ),
                Text(
                  'Liguilla ${widget.liguillaLabel}',
                  style: _ts(size: 11, color: _P.slate),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, color: _P.slate, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo',
          style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _typeOption(
                'Ronda completa',
                _isRondaCompleta,
                () => setState(() {
                  _isRondaCompleta = true;
                  _previewBytes = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _typeOption(
                'Un partido',
                !_isRondaCompleta,
                () => setState(() {
                  _isRondaCompleta = false;
                  _previewBytes = null;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRondaSection() {
    // Qué rondas tienen cruces
    final disponibles = <_RondaOpcion>[];
    if (widget.cruces.isNotEmpty) disponibles.add(_RondaOpcion.todos);
    if (widget.cruces.any((c) => c.ronda == 'previo')) {
      disponibles.add(_RondaOpcion.previo);
    }
    if (widget.cruces.any((c) => c.ronda == 'cuartos')) {
      disponibles.add(_RondaOpcion.cuartos);
    }
    if (widget.cruces.any((c) => c.ronda == 'semis')) {
      disponibles.add(_RondaOpcion.semis);
    }
    if (widget.cruces.any((c) => c.ronda == 'final')) {
      disponibles.add(_RondaOpcion.final_);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ronda',
          style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
        ),
        const SizedBox(height: 8),
        ...disponibles.map((r) => _rondaOption(r)),
      ],
    );
  }

  Widget _rondaOption(_RondaOpcion r) {
    final selected = _rondaSeleccionada == r;
    return GestureDetector(
      onTap: () => setState(() {
        _rondaSeleccionada = r;
        _previewBytes = null;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? r.color.withOpacity(0.12) : _P.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? r.color : _P.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? r.color : _P.slate,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              r.label,
              style: _ts(
                size: 13,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? r.color : _P.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartidoSection() {
    final rondasDisponibles = <_RondaOpcion>[];
    if (widget.cruces.any((c) => c.ronda == 'previo')) {
      rondasDisponibles.add(_RondaOpcion.previo);
    }
    if (widget.cruces.any((c) => c.ronda == 'cuartos')) {
      rondasDisponibles.add(_RondaOpcion.cuartos);
    }
    if (widget.cruces.any((c) => c.ronda == 'semis')) {
      rondasDisponibles.add(_RondaOpcion.semis);
    }
    if (widget.cruces.any((c) => c.ronda == 'final')) {
      rondasDisponibles.add(_RondaOpcion.final_);
    }

    final crucesRonda = _crucesDeRonda;
    final cruce = _cruceSeleccionado;
    final tieneVuelta = cruce?.vuelta != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ronda
        Text(
          'Ronda',
          style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
        ),
        const SizedBox(height: 8),
        _buildDropdown<_RondaOpcion>(
          value: rondasDisponibles.contains(_rondaPartido)
              ? _rondaPartido
              : (rondasDisponibles.isNotEmpty ? rondasDisponibles.first : null),
          items: rondasDisponibles
              .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
              .toList(),
          onChanged: (v) => setState(() {
            if (v != null) _rondaPartido = v;
            _cruceIndex = null;
            _previewBytes = null;
          }),
        ),

        const SizedBox(height: 14),

        // Cruce
        Text(
          'Cruce',
          style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
        ),
        const SizedBox(height: 8),
        _buildDropdown<int>(
          value: _cruceIndex,
          items: List.generate(crucesRonda.length, (i) {
            final c = crucesRonda[i];
            final label = c.tieneEquipos
                ? '${c.equipo1Nombre} vs ${c.equipo2Nombre}'
                : 'Cruce ${i + 1} (en espera)';
            return DropdownMenuItem(value: i, child: Text(label));
          }),
          onChanged: (v) => setState(() {
            _cruceIndex = v;
            _partidoNumero = 1;
            _previewBytes = null;
          }),
          hint: 'Seleccionar cruce',
        ),

        if (_cruceIndex != null) ...[
          const SizedBox(height: 14),

          // Ida / Vuelta
          Text(
            'Partido',
            style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _typeOption(
                  'Ida',
                  _partidoNumero == 1,
                  () => setState(() {
                    _partidoNumero = 1;
                    _previewBytes = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _typeOption(
                  'Vuelta',
                  _partidoNumero == 2,
                  tieneVuelta
                      ? () => setState(() {
                          _partidoNumero = 2;
                          _previewBytes = null;
                        })
                      : null,
                  disabled: !tieneVuelta,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Fondo personalizado
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _usarFondo,
                  onChanged: (v) => setState(() {
                    _usarFondo = v!;
                    _previewBytes = null;
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

          if (_usarFondo) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: _P.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _P.border, width: 0.5),
                ),
                child: _imagenFondo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imagenFondo!, fit: BoxFit.cover),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: _P.slate,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
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
      ],
    );
  }

  Widget _buildPreviewBtn() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _puedeGenerar && !_isGeneratingPreview
              ? _generatePreview
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _P.blueLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _P.blue.withOpacity(0.25), width: 0.5),
            ),
            alignment: Alignment.center,
            child: _isGeneratingPreview
                ? const SizedBox(
                    width: 16,
                    height: 16,
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
    );
  }

  Widget _buildPreviewImage() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(_previewBytes!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _dialogBtn(
              label: 'Cancelar',
              filled: false,
              loading: false,
              onTap: _isGenerating ? null : () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dialogBtn(
              label: 'Descargar',
              filled: true,
              loading: _isGenerating,
              onTap: _isGenerating || !_puedeGenerar ? null : _download,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widgets reutilizables ────────────────────────────────────────────────
  Widget _typeOption(
    String label,
    bool selected,
    VoidCallback? onTap, {
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: disabled
              ? _P.bg
              : selected
              ? _P.blueLight
              : _P.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled
                ? _P.border
                : selected
                ? _P.blue
                : _P.border,
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: _ts(
            size: 12,
            weight: FontWeight.w600,
            color: disabled
                ? _P.slate
                : selected
                ? _P.blue
                : _P.navy,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          hint: hint != null
              ? Text(hint, style: _ts(size: 13, color: _P.slate))
              : null,
          items: items,
          onChanged: onChanged,
          style: _ts(size: 13),
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

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _ts(color: Colors.white, size: 13)),
        backgroundColor: error ? _P.red : _P.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
