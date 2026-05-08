import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

// ─── PALETA ────────────────────────────────────────────────────────────────────
class _P {
  static const bg = Color(0xFFF0F2F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8EAF0);
  static const slate = Color(0xFF9A9FBA);
  static const navy = Color(0xFF1A1A2E);
  static const blue = Color(0xFF3A6FD8);
  static const blueLight = Color(0xFFEAF1FF);
  static const red = Color(0xFFE74C3C);
  static const redLight = Color(0xFFFEF0ED);
  static const green = Color(0xFF27AE60);
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
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isRegister = false;

  // Controllers — login
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Controllers — registro
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _equipoCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regPass2Ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _obscurePass = true;
  bool _obscureRegPass = true;
  bool _obscureRegPass2 = true;
  bool _isLoading = false;
  String? _errorMsg;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scrollCtrl.dispose();
    for (final c in [
      _emailCtrl,
      _passCtrl,
      _nombreCtrl,
      _apellidoCtrl,
      _telefonoCtrl,
      _equipoCtrl,
      _regEmailCtrl,
      _regPassCtrl,
      _regPass2Ctrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleMode() {
    _animCtrl.reset();
    setState(() {
      _isRegister = !_isRegister;
      _errorMsg = null;
    });
    _animCtrl.forward();

    // Regresa al top del formulario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Lógica de autenticación (original intacta) ─────────────────────────────

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Completa todos los campos.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await AuthService().signIn(_emailCtrl.text.trim(), _passCtrl.text);
      await AuthService().updateLastLogin();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on Exception catch (e) {
      setState(() => _errorMsg = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (_nombreCtrl.text.trim().isEmpty ||
        _apellidoCtrl.text.trim().isEmpty ||
        _telefonoCtrl.text.trim().isEmpty ||
        _regEmailCtrl.text.trim().isEmpty ||
        _regPassCtrl.text.isEmpty ||
        _regPass2Ctrl.text.isEmpty) {
      setState(() => _errorMsg = 'Completa todos los campos obligatorios.');
      return;
    }
    if (_regPassCtrl.text != _regPass2Ctrl.text) {
      setState(() => _errorMsg = 'Las contraseñas no coinciden.');
      return;
    }
    if (_regPassCtrl.text.length < 6) {
      setState(
        () => _errorMsg = 'La contraseña debe tener al menos 6 caracteres.',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await AuthService().signUp(
        email: _regEmailCtrl.text.trim(),
        password: _regPassCtrl.text,
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        equipo: _equipoCtrl.text.trim(),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on Exception catch (e) {
      setState(() => _errorMsg = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential'))
      return 'Correo o contraseña incorrectos.';
    if (raw.contains('email-already-in-use'))
      return 'Este correo ya está registrado.';
    if (raw.contains('invalid-email'))
      return 'El formato del correo no es válido.';
    if (raw.contains('weak-password')) return 'La contraseña es muy débil.';
    if (raw.contains('too-many-requests'))
      return 'Demasiados intentos. Intenta más tarde.';
    if (raw.contains('network-request-failed'))
      return 'Sin conexión a internet.';
    return 'Ocurrió un error. Intenta de nuevo.';
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        Positioned.fill(child: _buildBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: isLandscape
                ? _buildLandscapeLayout()
                : _buildPortraitLayout(),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHeroHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: _buildFormCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Panel izquierdo — logo
        Expanded(flex: 4, child: Center(child: _buildHeroHeaderCompact())),
        // Panel derecho — formulario
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 24, 12),
            child: _buildFormCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        physics: const ClampingScrollPhysics(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                    child: _isRegister
                        ? _buildRegisterForm()
                        : _buildLoginForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeaderCompact() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo_p.png',
          width: 100,
          height: 100,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        Text(
          'CERRITO',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2.5,
            height: 1.1,
          ),
        ),
        Text(
          'Liga de fútbol',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ─── FONDO ─────────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Stack(
      children: [
        // Imagen de fondo
        Positioned.fill(
          child: Image.asset(
            'assets/images/fondo_cancha.png',
            fit: BoxFit.cover,
          ),
        ),
        // Overlay oscuro para que el contenido sea legible
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.35)),
        ),
      ],
    );
  }

  Widget _dotGrid() {
    return SizedBox(
      width: 72,
      height: 72,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: 16,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.11),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ─── HERO HEADER ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_p.png',
              width: 152,
              height: 152,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 14),
            Text(
              'CERRITO',
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 2.5,
                height: 1.1,
              ),
            ),
            Text(
              'Liga de fútbol',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FORMULARIO LOGIN ──────────────────────────────────────────────────────

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            'Bienvenido',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _P.navy,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 18),

        _buildField(
          controller: _emailCtrl,
          hint: 'Correo',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 16),

        _buildField(
          controller: _passCtrl,
          hint: 'Contraseña',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePass,
          suffix: _eyeBtn(
            _obscurePass,
            () => setState(() => _obscurePass = !_obscurePass),
          ),
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 10),

        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Text(
              '¿Olvidaste tu contraseña?',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.blue),
            ),
          ),
        ),
        const SizedBox(height: 28),

        _buildErrorBanner(),
        _buildPrimaryBtn(label: 'Iniciar sesión', onTap: _login),
        const SizedBox(height: 5),

        Row(
          children: [
            Expanded(child: Container(height: 0.5, color: _P.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('o', style: _ts(size: 12, color: _P.slate)),
            ),
            Expanded(child: Container(height: 0.5, color: _P.border)),
          ],
        ),
        const SizedBox(height: 5),

        _buildSecondaryBtn(label: 'Crear cuenta nueva', onTap: _toggleMode),
      ],
    );
  }

  // ─── FORMULARIO REGISTRO ───────────────────────────────────────────────────

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            'Crea tu cuenta',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _P.navy,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 28),

        _buildSectionTag('Datos personales', Icons.person_outline_rounded),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('NOMBRE *'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _nombreCtrl,
                    hint: '',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('APELLIDO *'),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _apellidoCtrl,
                    hint: '',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildLabel('TELÉFONO *'),
        const SizedBox(height: 8),
        _buildField(
          controller: _telefonoCtrl,
          hint: '',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        _buildLabel('EQUIPO FAVORITO'),
        const SizedBox(height: 8),
        _buildField(
          controller: _equipoCtrl,
          hint: '(opcional)',
          icon: Icons.sports_soccer_outlined,
        ),
        const SizedBox(height: 24),

        _buildSectionTag('Datos de acceso', Icons.lock_outline_rounded),
        const SizedBox(height: 16),

        _buildLabel('CORREO ELECTRÓNICO *'),
        const SizedBox(height: 8),
        _buildField(
          controller: _regEmailCtrl,
          hint: '',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        _buildLabel('CONTRASEÑA *'),
        const SizedBox(height: 8),
        _buildField(
          controller: _regPassCtrl,
          hint: '',
          icon: Icons.lock_outline_rounded,
          obscure: _obscureRegPass,
          suffix: _eyeBtn(
            _obscureRegPass,
            () => setState(() => _obscureRegPass = !_obscureRegPass),
          ),
        ),
        const SizedBox(height: 14),

        _buildLabel('CONFIRMAR CONTRASEÑA *'),
        const SizedBox(height: 8),
        _buildField(
          controller: _regPass2Ctrl,
          hint: '',
          icon: Icons.lock_outline_rounded,
          obscure: _obscureRegPass2,
          suffix: _eyeBtn(
            _obscureRegPass2,
            () => setState(() => _obscureRegPass2 = !_obscureRegPass2),
          ),
          onSubmitted: (_) => _register(),
        ),
        const SizedBox(height: 32),

        _buildErrorBanner(),
        _buildPrimaryBtn(label: 'Crear cuenta', onTap: _register),
        const SizedBox(height: 14),
        _buildSecondaryBtn(
          label: '← Volver a iniciar sesión',
          onTap: _toggleMode,
        ),
      ],
    );
  }

  // ─── COMPONENTES UI ────────────────────────────────────────────────────────

  Widget _buildLabel(String text) => Text(
    text,
    style: _ts(
      size: 11,
      weight: FontWeight.w600,
      color: _P.slate,
      letterSpacing: 0.4,
    ),
  );

  Widget _buildSectionTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _P.blue),
          const SizedBox(width: 7),
          Text(
            label,
            style: _ts(
              size: 12,
              weight: FontWeight.w700,
              color: _P.blue,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: _ts(size: 14),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _ts(size: 14, color: _P.navy.withOpacity(0.65)),
        prefixIcon: Icon(icon, color: _P.navy, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: _P.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _P.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _P.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _P.blue, width: 1.5),
        ),
      ),
    );
  }

  Widget _eyeBtn(bool obscure, VoidCallback onTap) => IconButton(
    icon: Icon(
      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: _P.slate,
      size: 18,
    ),
    onPressed: onTap,
  );

  Widget _buildErrorBanner() {
    if (_errorMsg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _P.redLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.red.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: _P.red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMsg!,
                style: _ts(size: 13, color: _P.red, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Botón principal — navy sólido, texto blanco (idéntico al mockup)
  Widget _buildPrimaryBtn({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color: _isLoading ? _P.navy.withOpacity(0.55) : _P.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: _ts(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Botón secundario — fondo gris claro con borde (idéntico al mockup)
  Widget _buildSecondaryBtn({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.border, width: 0.5),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: _ts(size: 14, weight: FontWeight.w600, color: _P.navy),
            ),
          ),
        ),
      ),
    );
  }
}
