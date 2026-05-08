import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

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

class AppDrawer extends StatelessWidget {
  final VoidCallback? onGoToAdmin;
  const AppDrawer({super.key, this.onGoToAdmin});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final isAdmin = auth.isAdmin;
    final email = auth.currentUser.value?.email ?? '';

    return Drawer(
      backgroundColor: _P.surface,
      width: MediaQuery.of(context).size.width * 0.78,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _buildHeader(isAdmin, email),

            const SizedBox(height: 8),

            // ── Items ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildSectionLabel('General'),
                  _buildItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Acerca de la liga',
                    onTap: () {
                      Navigator.pop(context);
                      _showInfoDialog(context);
                    },
                  ),
                  _buildItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'Temporadas',
                    onTap: () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 8),
                  _buildSectionLabel('Legal'),
                  _buildItem(
                    icon: Icons.gavel_rounded,
                    label: 'Términos y condiciones',
                    onTap: () {
                      Navigator.pop(context);
                      _showLegalSheet(
                        context,
                        title: 'Términos y condiciones',
                        content: _terminosContent,
                      );
                    },
                  ),
                  _buildItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Política de privacidad',
                    onTap: () {
                      Navigator.pop(context);
                      _showLegalSheet(
                        context,
                        title: 'Política de privacidad',
                        content: _privacidadContent,
                      );
                    },
                  ),

                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    _buildSectionLabel('Administración'),
                    _buildItem(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Panel de administrador',
                      color: _P.blue,
                      onTap: () {
                        Navigator.pop(context); // cierra el drawer
                        onGoToAdmin?.call(); // navega al panel
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── Footer: cerrar sesión ────────────────────────────────
            _buildSignOutButton(context),
          ],
        ),
      ),
    );
  }

  // ── Header con avatar, email y badge de rol ──────────────────────────────

  Widget _buildHeader(bool isAdmin, String email) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),

          // Email
          Text(
            email,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Badge de rol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin
                  ? _P.blue.withOpacity(0.25)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAdmin
                    ? _P.blue.withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAdmin ? Icons.shield_rounded : Icons.person_outline_rounded,
                  size: 11,
                  color: isAdmin ? const Color(0xFF7AAECB) : Colors.white54,
                ),
                const SizedBox(width: 5),
                Text(
                  isAdmin ? 'Administrador' : 'Usuario',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isAdmin ? const Color(0xFF7AAECB) : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Label de sección ────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
      child: Text(
        label.toUpperCase(),
        style: _ts(
          size: 10,
          weight: FontWeight.w700,
          color: _P.slate,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── Item individual ─────────────────────────────────────────────────────────

  Widget _buildItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _P.navy,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _P.blue.withOpacity(0.08),
        highlightColor: _P.blue.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color == _P.navy ? _P.slate : color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: _ts(size: 14, weight: FontWeight.w500, color: color),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: _P.border),
            ],
          ),
        ),
      ),
    );
  }

  // ── Botón cerrar sesión ─────────────────────────────────────────────────────

  Widget _buildSignOutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _P.border, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            Navigator.pop(context); // cierra el drawer primero
            await Future.delayed(const Duration(milliseconds: 200));
            await AuthService().signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: _P.red.withOpacity(0.1),
          child: Ink(
            decoration: BoxDecoration(
              color: _P.redLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _P.red.withOpacity(0.2), width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, size: 17, color: _P.red),
                  const SizedBox(width: 8),
                  Text(
                    'Cerrar sesión',
                    style: _ts(
                      size: 14,
                      weight: FontWeight.w600,
                      color: _P.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Dialogs y sheets ────────────────────────────────────────────────────────

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _P.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _P.border, width: 0.5),
        ),
        title: Text(
          'Cerrito Liga de Fútbol',
          style: _ts(size: 16, weight: FontWeight.w700),
        ),
        content: Text(
          'Aplicación oficial para seguimiento de resultados, tablas y estadísticas de la liga.\n\nVersión 1.0.0',
          style: _ts(size: 13, color: _P.slate, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext), // ← usa dialogContext
            child: Text('Cerrar', style: _ts(color: _P.blue)),
          ),
        ],
      ),
    );
  }

  void _showLegalSheet(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.93,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _P.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: _ts(size: 17, weight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _P.slate,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, thickness: 0.5, color: _P.border),
              // Contenido
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    Text(
                      content,
                      style: _ts(size: 13, color: _P.slate, height: 1.7),
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

  // ── Textos legales (personaliza según tu liga) ───────────────────────────────

  static const _terminosContent = '''
1. Uso de la aplicación
Esta aplicación es de uso exclusivo para seguimiento de la liga de fútbol Cerrito. El acceso está restringido a usuarios registrados por el administrador.

2. Responsabilidad
Los resultados y estadísticas son registrados por los administradores de la liga. Cualquier discrepancia debe reportarse directamente al organizador.

3. Conducta
El uso de la app debe ser respetuoso. Está prohibido el uso con fines distintos al seguimiento deportivo de la liga.

4. Modificaciones
El administrador se reserva el derecho de modificar estos términos en cualquier momento.

5. Contacto
Para cualquier consulta, comunícate con el administrador de la liga.
''';

  static const _privacidadContent = '''
1. Datos recopilados
Recopilamos únicamente el correo electrónico utilizado para iniciar sesión y el historial de actividad dentro de la app.

2. Uso de los datos
Los datos se usan exclusivamente para la autenticación y personalización de la experiencia dentro de la liga.

3. Almacenamiento
Los datos se almacenan en Firebase (Google) con las medidas de seguridad estándar de la plataforma.

4. Compartición
No compartimos ningún dato personal con terceros.

5. Derechos
Puedes solicitar la eliminación de tu cuenta contactando al administrador de la liga.
''';
}
