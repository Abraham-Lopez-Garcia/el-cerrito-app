import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _logoCtrl;
  late AnimationController _brandCtrl;
  late AnimationController _dividerCtrl;
  late AnimationController _sloganCtrl;
  late AnimationController _loaderCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _exitCtrl;
  late AnimationController _spinCtrl;

  // Animaciones de entrada
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  late Animation<double> _brandOpacity;
  late Animation<Offset> _brandSlide;

  late Animation<double> _dividerWidth;
  late Animation<double> _dividerOpacity;

  late Animation<double> _sloganOpacity;
  late Animation<Offset> _sloganSlide;

  late Animation<double> _loaderOpacity;
  late Animation<double> _progressValue;

  // Animaciones de salida
  late Animation<double> _exitOpacity;
  late Animation<Offset> _exitLogoSlide;
  late Animation<Offset> _exitBrandSlide;

  // Ring decorativo
  late Animation<double> _spinAngle;

  bool _showProgress = false;

  @override
  void initState() {
    super.initState();

    // --- Logo: escala con bounce + fade ---
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
    ]).animate(_logoCtrl);
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _logoSlide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));

    // --- Nombre del equipo ---
    _brandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _brandOpacity = CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOut);
    _brandSlide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOut));

    // --- Divisor ---
    _dividerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dividerWidth = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _dividerCtrl, curve: Curves.easeInOut));
    _dividerOpacity = Tween(
      begin: 0.0,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _dividerCtrl, curve: Curves.easeOut));

    // --- Slogan ---
    _sloganCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sloganOpacity = CurvedAnimation(
      parent: _sloganCtrl,
      curve: Curves.easeOut,
    );
    _sloganSlide = Tween(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sloganCtrl, curve: Curves.easeOut));

    // --- Loader + progreso ---
    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loaderOpacity = CurvedAnimation(
      parent: _loaderCtrl,
      curve: Curves.easeOut,
    );
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _progressValue = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOut,
    );

    // --- Salida ---
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitOpacity = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut));
    _exitLogoSlide = Tween(
      begin: Offset.zero,
      end: const Offset(0, -0.15),
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
    _exitBrandSlide = Tween(
      begin: Offset.zero,
      end: const Offset(0, -0.08),
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    // --- Spin ring ---
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _spinAngle = Tween(begin: 0.0, end: 2 * 3.1415926).animate(_spinCtrl);

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _brandCtrl.forward();
    await _dividerCtrl.forward();
    _sloganCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _showProgress = true);
    _loaderCtrl.forward();
    _progressCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2400));
    await _exitCtrl.forward();
    if (!mounted) return;
    final user = AuthService().currentUser.value;
    Navigator.pushReplacementNamed(context, user != null ? '/home' : '/login');
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _brandCtrl.dispose();
    _dividerCtrl.dispose();
    _sloganCtrl.dispose();
    _loaderCtrl.dispose();
    _progressCtrl.dispose();
    _exitCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Stack(
        children: [
          // Fondo con gradiente radial
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.10),
                    const Color(0xFF0A0F1E),
                  ],
                ),
              ),
            ),
          ),
          // Gradiente inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.9,
                  colors: [
                    const Color(0xFF06B6D4).withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Contenido principal
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: Listenable.merge([_logoCtrl, _exitCtrl]),
                  builder: (context, _) {
                    return Opacity(
                      opacity: (_logoOpacity.value * (1 - _exitCtrl.value))
                          .clamp(0, 1),
                      child: SlideTransition(
                        position: _exitCtrl.isAnimating || _exitCtrl.isCompleted
                            ? _exitLogoSlide
                            : _logoSlide,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: _buildLogo(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Nombre
                AnimatedBuilder(
                  animation: Listenable.merge([_brandCtrl, _exitCtrl]),
                  builder: (context, _) => Opacity(
                    opacity: (_brandOpacity.value * (1 - _exitCtrl.value))
                        .clamp(0, 1),
                    child: SlideTransition(
                      position: _exitCtrl.isAnimating || _exitCtrl.isCompleted
                          ? _exitBrandSlide
                          : _brandSlide,
                      child: _buildBrand(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Divisor
                AnimatedBuilder(
                  animation: Listenable.merge([_dividerCtrl, _exitCtrl]),
                  builder: (context, _) => Opacity(
                    opacity: (_dividerOpacity.value * (1 - _exitCtrl.value))
                        .clamp(0, 1),
                    child: Container(
                      width: 120 * _dividerWidth.value,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF10B981).withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Slogan
                AnimatedBuilder(
                  animation: Listenable.merge([_sloganCtrl, _exitCtrl]),
                  builder: (context, _) => Opacity(
                    opacity: (_sloganOpacity.value * (1 - _exitCtrl.value))
                        .clamp(0, 1),
                    child: SlideTransition(
                      position: _sloganSlide,
                      child: _buildSlogan(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar + loader abajo
          if (_showProgress)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: Listenable.merge([_loaderCtrl, _exitCtrl]),
                builder: (context, _) => Opacity(
                  opacity: (_loaderOpacity.value * (1 - _exitCtrl.value)).clamp(
                    0,
                    1,
                  ),
                  child: _buildLoader(),
                ),
              ),
            ),

          // Overlay de salida (fade a negro)
          AnimatedBuilder(
            animation: _exitCtrl,
            builder: (context, _) => Opacity(
              opacity: _exitOpacity.value,
              child: Container(color: const Color(0xFF0A0F1E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _spinAngle,
      builder: (context, child) {
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Anillo exterior giratorio con puntos
              Transform.rotate(
                angle: _spinAngle.value,
                child: CustomPaint(
                  size: const Size(160, 160),
                  painter: _DashedCirclePainter(
                    color: const Color(0xFF10B981).withOpacity(0.18),
                    radius: 79,
                    dashCount: 24,
                  ),
                ),
              ),
              // Anillo interior estático
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.10),
                    width: 1,
                  ),
                ),
              ),
              // Caja del logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.12),
                      Colors.white.withOpacity(0.03),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Image.asset(
                    'assets/images/logo_p.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Text(
          'CERRITO',
          style: GoogleFonts.dmSans(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'LIGA DE FÚTBOL',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.35),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildSlogan() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.55),
            height: 1.7,
            letterSpacing: 0.3,
          ),
          children: [
            const TextSpan(
              text: 'Estadísticas, resultados y tabla de posiciones.\n',
            ),
            TextSpan(
              text: 'Todo lo que necesitas',
              style: TextStyle(color: const Color(0xFF10B981).withOpacity(0.9)),
            ),
            const TextSpan(text: ' para seguir la liga.'),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      children: [
        // Barra de progreso
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: AnimatedBuilder(
            animation: _progressValue,
            builder: (context, _) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progressValue.value,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(
                    const Color(0xFF10B981),
                    const Color(0xFF06B6D4),
                    _progressValue.value,
                  )!.withOpacity(0.7),
                ),
                minHeight: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Painter para el anillo con guiones
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double radius;
  final int dashCount;

  const _DashedCirclePainter({
    required this.color,
    required this.radius,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const pi2 = 2 * 3.1415926535;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dashArc = pi2 / dashCount;
    final gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashArc;
      final sweepAngle = dashArc * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color || old.radius != radius;
}
