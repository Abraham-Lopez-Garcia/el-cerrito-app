import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/equipo_model.dart';
import '../models/equipo_base_model.dart';
import '../models/jugador_model.dart';
import '../models/jugador_base_model.dart';

// ─── PALETA ──────────────────────────────────────────────────────────────────
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
  static const amberLight = Color(0xFFFFF8E6);
  static const teal = Color(0xFF0F6E56);
  static const tealLight = Color(0xFFE1F5EE);
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

// ─── MANAGEMENT SCREEN ───────────────────────────────────────────────────────
class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  late AnimationController _fadeCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  int? _selectedSummaryIndex;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _service.currentSeasonId.addListener(_onSeasonChanged);
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _service.currentSeasonId.removeListener(_onSeasonChanged);
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onSeasonChanged() => setState(() {});

  // ─── Abre el selector: inscribir existente o crear nuevo ─────────────────
  void _openAddTeamOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Agregar equipo',
        subtitle: '¿Es un equipo que ya participó antes?',
        existingLabel: 'Inscribir equipo existente',
        existingSubtitle: 'Ya tiene logo y datos registrados',
        newLabel: 'Registrar equipo nuevo',
        newSubtitle: 'Primera vez en la liga',
        onExisting: () {
          Navigator.pop(context);
          _openInscribirEquipoSheet();
        },
        onNew: () {
          Navigator.pop(context);
          _openCrearEquipoSheet();
        },
      ),
    );
  }

  // POR ESTO:
  void _openInscribirEquipoSheet() {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InscribirEquipoSheet(
        onSuccess: () => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Equipo inscrito en la temporada',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        onError: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error: $msg',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // POR ESTO:
  void _openCrearEquipoSheet() {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CrearEquipoSheet(
        onSuccess: () => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Equipo registrado con éxito',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        onError: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error: $msg',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // POR ESTO:
  void _openEditTeamSheet(Equipo equipo) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditarEquipoSheet(
        equipo: equipo,
        onSuccess: () => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Equipo actualizado',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        onError: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error: $msg',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
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

  Future<void> _confirmDeleteTeam(Equipo equipo) async {
    final ok = await _showConfirmDialog(
      icon: Icons.delete_outline_rounded,
      iconBg: _P.redLight,
      iconColor: _P.red,
      title: 'Quitar equipo',
      body:
          'Se quitará "${equipo.nombre}" de esta temporada.\nEl equipo y su logo no se eliminarán.',
      confirmLabel: 'Quitar',
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      await _service.eliminarEquipoDeTemporada(equipo.id);
      if (mounted) _showSnack('Equipo quitado de la temporada');
    } catch (e) {
      if (mounted) _showSnack('Error al quitar: $e', isError: true);
    }
  }

  Future<bool?> _showConfirmDialog({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String body,
    required String confirmLabel,
    bool isDestructive = false,
  }) => showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: _P.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _P.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 14),
            Text(title, style: _ts(size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: _ts(size: 13, color: _P.slate, height: 1.6),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _dialogBtn(
                    'Cancelar',
                    false,
                    () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dialogBtn(
                    confirmLabel,
                    true,
                    () => Navigator.pop(ctx, true),
                    isDestructive: isDestructive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dialogBtn(
    String label,
    bool filled,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? (isDestructive ? _P.red : _P.blue) : _P.bg,
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

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ColoredBox(
      color: _P.bg,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildHeader() => Container(
    color: _P.surface,
    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EQUIPOS',
                style: _ts(
                  size: 22,
                  weight: FontWeight.w800,
                  letterSpacing: 1.8,
                  height: 1.1,
                ),
              ),
              Text(
                'Gestión de plantillas',
                style: _ts(size: 11, color: _P.slate, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _openAddTeamOptions,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _P.blueLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _P.blue.withOpacity(0.25), width: 0.5),
            ),
            child: const Icon(Icons.add_rounded, color: _P.blue, size: 20),
          ),
        ),
      ],
    ),
  );

  Widget _buildBody() {
    if (_service.currentSeasonId.value == null) {
      return _emptyState(
        icon: Icons.sports_soccer_outlined,
        title: 'Sin temporada activa',
        subtitle: 'Selecciona o crea una temporada\npara gestionar equipos.',
      );
    }
    return StreamBuilder<List<Equipo>>(
      stream: _service.getEquiposStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: _P.blue, strokeWidth: 2.5),
          );
        final all = snapshot.data!;
        if (all.isEmpty)
          return _emptyState(
            icon: Icons.groups_outlined,
            title: 'Sin equipos en esta temporada',
            subtitle: 'Toca "+" para inscribir o crear\nun equipo.',
          );

        final teams = _query.isEmpty
            ? all
            : all
                  .where((e) => e.nombre.toLowerCase().contains(_query))
                  .toList();

        return Column(
          children: [
            _buildSummaryRow(all),
            _buildSearchBar(),
            Expanded(
              child: teams.isEmpty
                  ? _emptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sin resultados',
                      subtitle: 'No se encontró ningún equipo\ncon ese nombre.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      itemCount: teams.length,
                      itemBuilder: (_, i) => _TeamTile(
                        equipo: teams[i],
                        index: i,
                        onDelete: () => _confirmDeleteTeam(teams[i]),
                        onEdit: () => _openEditTeamSheet(teams[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
    child: Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: _ts(size: 14),
        decoration: InputDecoration(
          hintText: 'Buscar equipo…',
          hintStyle: _ts(size: 14, color: _P.slate),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _P.slate,
            size: 20,
          ),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    color: _P.slate,
                    size: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    ),
  );

  Widget _buildSummaryRow(List<Equipo> teams) {
    final totalJugadores = teams.fold<int>(0, (s, e) => s + e.totalJugadores);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              index: 0,
              label: 'Equipos',
              value: '${teams.length}',
              color: _P.blue,
              bg: _P.blueLight,
              icon: Icons.shield_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              index: 1,
              label: 'Jugadores',
              value: '$totalJugadores',
              color: _P.green,
              bg: _P.greenLight,
              icon: Icons.people_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required int index,
    required String label,
    required String value,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    final isSelected = _selectedSummaryIndex == index;
    return GestureDetector(
      onTap: () => setState(
        () => _selectedSummaryIndex = _selectedSummaryIndex == index
            ? null
            : index,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, isSelected ? -6.0 : 0.0)
          ..scale(isSelected ? 1.03 : 1.0),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isSelected ? 0.25 : 0.05),
              blurRadius: isSelected ? 14 : 6,
              offset: Offset(0, isSelected ? 8 : 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(
                  size: 20,
                  weight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: _ts(size: 10, color: _P.slate, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Icon(icon, color: _P.slate, size: 30),
        ),
        const SizedBox(height: 16),
        Text(title, style: _ts(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: _ts(size: 13, color: _P.slate, height: 1.6),
        ),
      ],
    ),
  );
}

// ─── OPTION PICKER SHEET (reutilizable para equipos y jugadores) ─────────────
class _OptionPickerSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String existingLabel;
  final String existingSubtitle;
  final String newLabel;
  final String newSubtitle;
  final VoidCallback onExisting;
  final VoidCallback onNew;

  const _OptionPickerSheet({
    required this.title,
    required this.subtitle,
    required this.existingLabel,
    required this.existingSubtitle,
    required this.newLabel,
    required this.newSubtitle,
    required this.onExisting,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          Text(title, style: _ts(size: 18, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: _ts(size: 12, color: _P.slate)),
          const SizedBox(height: 20),

          // Opción: inscribir existente
          _OptionCard(
            icon: Icons.history_rounded,
            iconColor: _P.blue,
            iconBg: _P.blueLight,
            label: existingLabel,
            sublabel: existingSubtitle,
            onTap: onExisting,
          ),
          const SizedBox(height: 10),

          // Opción: crear nuevo
          _OptionCard(
            icon: Icons.add_circle_outline_rounded,
            iconColor: _P.teal,
            iconBg: _P.tealLight,
            label: newLabel,
            sublabel: newSubtitle,
            onTap: onNew,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _P.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _ts(size: 14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sublabel, style: _ts(size: 12, color: _P.slate)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _P.slate, size: 20),
          ],
        ),
      ),
    ),
  );
}

// ─── INSCRIBIR EQUIPO EXISTENTE ───────────────────────────────────────────────
class _InscribirEquipoSheet extends StatefulWidget {
  final VoidCallback? onSuccess;
  final void Function(String)? onError;
  const _InscribirEquipoSheet({this.onSuccess, this.onError});
  @override
  State<_InscribirEquipoSheet> createState() => _InscribirEquipoSheetState();
}

class _InscribirEquipoSheetState extends State<_InscribirEquipoSheet> {
  final _service = FirestoreService();
  final _searchCtrl = TextEditingController();
  List<EquipoBase> _todos = [];
  List<EquipoBase> _filtrados = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadEquipos();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEquipos() async {
    try {
      final equipos = await _service.getEquiposBase();
      if (mounted)
        setState(() {
          _todos = equipos;
          _filtrados = equipos;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? _todos
          : _todos.where((e) => e.nombre.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _inscribir(EquipoBase base) async {
    setState(() => _saving = true);
    try {
      await _service.inscribirEquipoExistente(base);
      widget.onSuccess?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError?.call(e.toString());
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _hexToColor(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return _P.slate;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          Text(
            'Inscribir equipo',
            style: _ts(size: 18, weight: FontWeight.w800),
          ),
          Text(
            'Selecciona un equipo existente',
            style: _ts(size: 12, color: _P.slate),
          ),
          const SizedBox(height: 16),

          // Buscador
          Container(
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _P.border, width: 0.5),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: _ts(size: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre…',
                hintStyle: _ts(size: 14, color: _P.slate),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _P.slate,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lista
          Flexible(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _P.blue,
                      strokeWidth: 2.5,
                    ),
                  )
                : _filtrados.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _todos.isEmpty
                            ? 'No hay equipos registrados aún'
                            : 'Sin resultados para esa búsqueda',
                        style: _ts(size: 13, color: _P.slate),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = _filtrados[i];
                      final tc = _hexToColor(e.color);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _saving ? null : () => _inscribir(e),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _P.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _P.border, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                // Franja color
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: tc,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Logo
                                ClipOval(
                                  child: e.logoUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: e.logoUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            width: 40,
                                            height: 40,
                                            decoration: const BoxDecoration(
                                              color: _P.border,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: const BoxDecoration(
                                                  color: _P.bg,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.shield_outlined,
                                                  color: _P.slate,
                                                  size: 20,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                            color: _P.bg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.shield_outlined,
                                            color: _P.slate,
                                            size: 20,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.nombre,
                                    style: _ts(
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: _P.blue,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── CREAR EQUIPO NUEVO ───────────────────────────────────────────────────────
class _CrearEquipoSheet extends StatefulWidget {
  final VoidCallback? onSuccess;
  final void Function(String)? onError;
  const _CrearEquipoSheet({this.onSuccess, this.onError});
  @override
  State<_CrearEquipoSheet> createState() => _CrearEquipoSheetState();
}

class _CrearEquipoSheetState extends State<_CrearEquipoSheet> {
  File? _image;
  Color _color = const Color(0xFF3A6FD8);
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _isSaving = false;
  final _service = FirestoreService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null && mounted) setState(() => _image = File(f.path));
  }

  Future<void> _save() async {
    print('>>> _save iniciado');
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Ingresa el nombre');
      return;
    }
    if (_image == null) {
      _snack('Selecciona un logo');
      return;
    }

    setState(() => _isSaving = true);
    try {
      print('>>> Subiendo imagen...');
      final ref = FirebaseStorage.instance.ref().child(
        'team_logos/${DateTime.now().millisecondsSinceEpoch}_${path.basename(_image!.path)}',
      );
      await ref.putFile(_image!);
      print('>>> Imagen subida, obteniendo URL...');
      final logoUrl = await ref.getDownloadURL();
      print('>>> URL obtenida: $logoUrl');

      final hex =
          '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      print('>>> Llamando crearEquipoNuevo...');
      await _service.crearEquipoNuevo(
        nombre: _nameCtrl.text.trim(),
        color: hex,
        logoUrl: logoUrl,
      );
      print('>>> crearEquipoNuevo exitoso');

      widget.onSuccess?.call();
      print('>>> mounted: $mounted');
      if (mounted) {
        print('>>> Ejecutando Navigator.pop...');
        Navigator.pop(context);
        print('>>> Pop ejecutado');
      }
    } catch (e, stack) {
      print('>>> ERROR en _save: $e');
      print('>>> Stack: $stack');
      widget.onError?.call(e.toString());
    } finally {
      print('>>> Finally ejecutado, mounted: $mounted');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: _ts(color: Colors.white, size: 13)),
      backgroundColor: _P.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            Text('Nuevo equipo', style: _ts(size: 18, weight: FontWeight.w800)),
            Text(
              'Se registrará en la liga y en esta temporada',
              style: _ts(size: 12, color: _P.slate),
            ),
            const SizedBox(height: 24),
            _ImagePickerWidget(
              image: _image,
              onTap: _pickImage,
              placeholder: 'Logo',
              icon: Icons.add_photo_alternate_outlined,
            ),
            const SizedBox(height: 22),
            Text(
              'Nombre del equipo',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 6),
            _buildField(_nameCtrl, 'Ej. Atlético FC'),
            const SizedBox(height: 20),
            Text(
              'Color del uniforme',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 10),
            _ColorSelectorWidget(
              color: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildSheetBtn(
                    'Cancelar',
                    false,
                    () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSheetBtn(
                    'Registrar',
                    true,
                    _isSaving ? null : _save,
                    loading: _isSaving,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EDITAR EQUIPO ────────────────────────────────────────────────────────────
class _EditarEquipoSheet extends StatefulWidget {
  final Equipo equipo;
  final VoidCallback? onSuccess;
  final void Function(String)? onError;
  const _EditarEquipoSheet({
    required this.equipo,
    this.onSuccess,
    this.onError,
  });
  @override
  State<_EditarEquipoSheet> createState() => _EditarEquipoSheetState();
}

class _EditarEquipoSheetState extends State<_EditarEquipoSheet> {
  File? _newImage;
  late Color _color;
  late TextEditingController _nameCtrl;
  final _picker = ImagePicker();
  bool _isSaving = false;
  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.equipo.nombre);
    _color = _hexToColor(widget.equipo.color);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return _P.blue;
  }

  Future<void> _pickImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null && mounted) setState(() => _newImage = File(f.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Ingresa el nombre');
      return;
    }
    setState(() => _isSaving = true);
    try {
      String logoUrl = widget.equipo.logoUrl;
      String? logoAnterior;
      if (_newImage != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'team_logos/${DateTime.now().millisecondsSinceEpoch}_${path.basename(_newImage!.path)}',
        );
        await ref.putFile(_newImage!);
        logoAnterior = widget.equipo.logoUrl;
        logoUrl = await ref.getDownloadURL();
      }
      final hex =
          '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      await _service.editarEquipoBase(
        equipoBaseId: widget.equipo.equipoBaseId,
        equipoSnapId: widget.equipo.id,
        nombre: _nameCtrl.text.trim(),
        color: hex,
        logoUrl: logoUrl,
        logoAnteriorUrl: logoAnterior,
      );
      widget.onSuccess?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: _ts(color: Colors.white, size: 13)),
      backgroundColor: _P.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            Text(
              'Editar equipo',
              style: _ts(size: 18, weight: FontWeight.w800),
            ),
            Text(
              'Los cambios se aplicarán en todas las temporadas',
              style: _ts(size: 12, color: _P.slate),
            ),
            const SizedBox(height: 24),
            _ImagePickerWidget(
              image: _newImage,
              networkUrl: _newImage == null ? widget.equipo.logoUrl : null,
              onTap: _pickImage,
              placeholder: 'Logo',
              icon: Icons.add_photo_alternate_outlined,
            ),
            const SizedBox(height: 22),
            Text(
              'Nombre del equipo',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 6),
            _buildField(_nameCtrl, 'Ej. Atlético FC'),
            const SizedBox(height: 20),
            Text(
              'Color del uniforme',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 10),
            _ColorSelectorWidget(
              color: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildSheetBtn(
                    'Cancelar',
                    false,
                    () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSheetBtn(
                    'Guardar',
                    true,
                    _isSaving ? null : _save,
                    loading: _isSaving,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TEAM TILE ────────────────────────────────────────────────────────────────
class _TeamTile extends StatefulWidget {
  final Equipo equipo;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _TeamTile({
    required this.equipo,
    required this.index,
    required this.onDelete,
    required this.onEdit,
  });
  @override
  State<_TeamTile> createState() => _TeamTileState();
}

class _TeamTileState extends State<_TeamTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 280 + widget.index * 50),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 55), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorFromHex(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return _P.slate;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.equipo;
    final tc = _colorFromHex(e.color);
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _P.border, width: 0.5),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, anim, __) => FadeTransition(
                    opacity: anim,
                    child: TeamDetailScreen(equipo: e),
                  ),
                  transitionDuration: const Duration(milliseconds: 250),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tc,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _logo(e.logoUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: _ts(size: 14, weight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          _pill(
                            '${e.totalJugadores} jugadores',
                            Icons.people_outline_rounded,
                            _P.blue,
                            _P.blueLight,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: _P.slate,
                      ),
                      onPressed: widget.onEdit,
                      splashRadius: 20,
                      tooltip: 'Editar equipo',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 18,
                        color: _P.slate,
                      ),
                      onPressed: widget.onDelete,
                      splashRadius: 20,
                      tooltip: 'Quitar de temporada',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(String url) {
    if (url.isEmpty)
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        child: const Icon(Icons.shield_outlined, color: _P.slate, size: 22),
      );
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: _P.bg, shape: BoxShape.circle),
          child: const Icon(Icons.shield_outlined, color: _P.slate, size: 22),
        ),
      ),
    );
  }

  Widget _pill(String label, IconData icon, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: _ts(size: 10, weight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
}

// ─── TEAM DETAIL SCREEN ───────────────────────────────────────────────────────
class TeamDetailScreen extends StatefulWidget {
  final Equipo equipo;
  const TeamDetailScreen({super.key, required this.equipo});
  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Color _colorFromHex(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    } catch (_) {}
    return _P.slate;
  }

  void _openAddPlayerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet(
        title: 'Añadir jugador',
        subtitle: '¿El jugador ya estuvo en la liga antes?',
        existingLabel: 'Inscribir jugador existente',
        existingSubtitle: 'Ya tiene foto y datos registrados',
        newLabel: 'Registrar jugador nuevo',
        newSubtitle: 'Primera vez en la liga',
        onExisting: () {
          Navigator.pop(context);
          _openInscribirJugadorSheet();
        },
        onNew: () {
          Navigator.pop(context);
          _openCrearJugadorSheet();
        },
      ),
    );
  }

  // POR ESTO:
  void _openInscribirJugadorSheet() {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InscribirJugadorSheet(
        equipo: widget.equipo,
        onSuccess: () => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Jugador inscrito en el equipo',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        onError: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error: $msg',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // POR ESTO:
  void _openCrearJugadorSheet() {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CrearJugadorSheet(
        equipo: widget.equipo,
        onSuccess: () => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Jugador registrado',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        onError: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error: $msg',
              style: _ts(color: Colors.white, size: 13),
            ),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: _ts(color: Colors.white, size: 13)),
          backgroundColor: isError ? _P.red : _P.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  Future<void> _confirmDeletePlayer(Jugador j) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _P.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _P.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _P.redLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_remove_outlined,
                  color: _P.red,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Quitar jugador',
                style: _ts(size: 16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${j.nombre} se quitará de esta temporada.\nSus datos no se eliminarán.',
                textAlign: TextAlign.center,
                style: _ts(size: 13, color: _P.slate, height: 1.6),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _dialogBtnStatic(
                      'Cancelar',
                      false,
                      () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dialogBtnStatic(
                      'Quitar',
                      true,
                      () => Navigator.pop(ctx, true),
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.eliminarJugadorDeTemporada(
        inscripcionId: j.id,
        equipoSnapId: widget.equipo.id,
        equipoBaseId: widget.equipo.equipoBaseId,
      );
      if (mounted) _showSnack('Jugador quitado de la temporada');
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.equipo;
    final tc = _colorFromHex(e.color);
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: Column(
            children: [
              _buildTopBar(e, tc),
              _buildStatsBar(e),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Row(
                  children: [
                    Text(
                      'Plantilla',
                      style: _ts(size: 16, weight: FontWeight.w700),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openAddPlayerOptions,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _P.blueLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _P.blue.withOpacity(0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_add_alt_1_outlined,
                              color: _P.blue,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Añadir',
                              style: _ts(
                                size: 12,
                                weight: FontWeight.w700,
                                color: _P.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildPlayersGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Equipo e, Color tc) => Container(
    color: _P.surface,
    padding: const EdgeInsets.fromLTRB(14, 12, 18, 14),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _P.border, width: 0.5),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _P.navy,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        e.logoUrl.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: e.logoUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tc.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_outlined, color: tc, size: 20),
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.nombre,
                style: _ts(size: 16, weight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tc,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${e.totalJugadores} jugadores',
                    style: _ts(size: 11, color: _P.slate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildStatsBar(Equipo e) => Container(
    margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: _P.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _P.border, width: 0.5),
    ),
    child: Row(
      children: [
        _si('${e.pts}', 'Puntos', _P.blue),
        _div(),
        _si('${e.pg}', 'Victorias', _P.green),
        _div(),
        _si('${e.pe}', 'Empates', _P.slate),
        _div(),
        _si('${e.pp}', 'Derrotas', _P.red),
        _div(),
        _si('${e.gf}/${e.gc}', 'GF/GC', _P.navy),
      ],
    ),
  );

  Widget _si(String v, String l, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: _ts(size: 16, weight: FontWeight.w800, color: c),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: _ts(size: 9, color: _P.slate, weight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _div() => Container(width: 0.5, height: 28, color: _P.border);

  Widget _buildPlayersGrid() => StreamBuilder<List<Jugador>>(
    stream: _service.getJugadoresStream(widget.equipo.id),
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Center(
          child: CircularProgressIndicator(color: _P.blue, strokeWidth: 2.5),
        );
      final players = snapshot.data!;
      if (players.isEmpty)
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _P.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _P.border, width: 0.5),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: _P.slate,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sin jugadores',
                style: _ts(size: 15, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Toca "Añadir" para registrar\nel primer jugador.',
                textAlign: TextAlign.center,
                style: _ts(size: 13, color: _P.slate, height: 1.6),
              ),
            ],
          ),
        );
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.82,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: players.length,
        // POR ESTO:
        itemBuilder: (_, i) {
          final messenger = ScaffoldMessenger.of(context);
          return _PlayerCard(
            jugador: players[i],
            index: i,
            onDelete: () => _confirmDeletePlayer(players[i]),
            onEdit: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _EditarJugadorSheet(
                jugador: players[i],
                equipo: widget.equipo,
                onSuccess: () => messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Jugador actualizado',
                      style: _ts(color: Colors.white, size: 13),
                    ),
                    backgroundColor: _P.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                onError: (msg) => messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error: $msg',
                      style: _ts(color: Colors.white, size: 13),
                    ),
                    backgroundColor: _P.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ─── INSCRIBIR JUGADOR EXISTENTE ──────────────────────────────────────────────
class _InscribirJugadorSheet extends StatefulWidget {
  final Equipo equipo;
  final VoidCallback? onSuccess;
  final void Function(String)? onError;
  const _InscribirJugadorSheet({
    required this.equipo,
    this.onSuccess,
    this.onError,
  });
  @override
  State<_InscribirJugadorSheet> createState() => _InscribirJugadorSheetState();
}

class _InscribirJugadorSheetState extends State<_InscribirJugadorSheet> {
  final _service = FirestoreService();
  final _searchCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  List<JugadorBase> _todos = [];
  List<JugadorBase> _filtrados = [];
  JugadorBase? _seleccionado;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadJugadores();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadJugadores() async {
    try {
      final jugadores = await _service.getJugadoresBaseDisponibles(
        widget.equipo.equipoBaseId,
      );
      if (mounted)
        setState(() {
          _todos = jugadores;
          _filtrados = jugadores;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? _todos
          : _todos.where((j) => j.nombre.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _inscribir() async {
    if (_seleccionado == null) return;
    if (_numCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ingresa el número de camiseta',
            style: _ts(color: Colors.white, size: 13),
          ),
          backgroundColor: _P.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.inscribirJugadorExistente(
        jugadorBase: _seleccionado!,
        equipoSnapId: widget.equipo.id,
        equipoBaseId: widget.equipo.equipoBaseId,
        numero: _numCtrl.text.trim(),
      );
      widget.onSuccess?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError?.call(e.toString());
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          Text(
            'Inscribir jugador',
            style: _ts(size: 18, weight: FontWeight.w800),
          ),
          Text(
            'Selecciona un jugador y asígnale número',
            style: _ts(size: 12, color: _P.slate),
          ),
          const SizedBox(height: 16),

          // Buscador
          Container(
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _P.border, width: 0.5),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: _ts(size: 14),
              decoration: InputDecoration(
                hintText: 'Buscar jugador…',
                hintStyle: _ts(size: 14, color: _P.slate),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _P.slate,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lista de jugadores
          Flexible(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _P.blue,
                      strokeWidth: 2.5,
                    ),
                  )
                : _filtrados.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _todos.isEmpty
                            ? 'No hay jugadores disponibles'
                            : 'Sin resultados',
                        style: _ts(size: 13, color: _P.slate),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final j = _filtrados[i];
                      final selected = _seleccionado?.id == j.id;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _seleccionado = selected ? null : j),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? _P.blueLight : _P.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? _P.blue : _P.border,
                              width: selected ? 1 : 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipOval(
                                child: j.fotoUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: j.fotoUrl,
                                        width: 38,
                                        height: 38,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(
                                          color: _P.border,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: _P.slate,
                                          size: 20,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  j.nombre,
                                  style: _ts(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: selected ? _P.blue : _P.navy,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: _P.blue,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Campo número — solo visible si hay selección
          if (_seleccionado != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _P.blueLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.blue.withOpacity(0.3), width: 0.5),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: _seleccionado!.fotoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _seleccionado!.fotoUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: _P.border,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: _P.slate,
                              size: 18,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _seleccionado!.nombre,
                      style: _ts(
                        size: 13,
                        weight: FontWeight.w700,
                        color: _P.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _numCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: _ts(size: 16, weight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '#',
                        hintStyle: _ts(size: 16, color: _P.slate),
                        filled: true,
                        fillColor: _P.surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _P.border,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _P.border,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _P.blue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSheetBtn(
                  'Cancelar',
                  false,
                  () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSheetBtn(
                  'Inscribir',
                  true,
                  (_seleccionado != null && !_saving) ? _inscribir : null,
                  loading: _saving,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── CREAR JUGADOR NUEVO ──────────────────────────────────────────────────────
class _CrearJugadorSheet extends StatefulWidget {
  final Equipo equipo;
  final VoidCallback? onSuccess;
  final void Function(String)? onError;
  const _CrearJugadorSheet({
    required this.equipo,
    this.onSuccess,
    this.onError,
  });
  @override
  State<_CrearJugadorSheet> createState() => _CrearJugadorSheetState();
}

class _CrearJugadorSheetState extends State<_CrearJugadorSheet> {
  File? _image;
  final _nameCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _isSaving = false;
  final _service = FirestoreService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null && mounted) setState(() => _image = File(f.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _numCtrl.text.trim().isEmpty) {
      _snack('Completa nombre y número');
      return;
    }
    if (_image == null) {
      _snack('Selecciona una foto');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final dir = await getTemporaryDirectory();
      final target =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(_image!.path)}';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        _image!.path,
        target,
        quality: 75,
      );
      if (compressed == null) throw Exception('Error al comprimir');
      final ref = FirebaseStorage.instance.ref().child(
        'player_photos/${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressed.path)}',
      );
      await ref.putFile(File(compressed.path));
      final fotoUrl = await ref.getDownloadURL();
      await _service.crearJugadorNuevo(
        equipoSnapId: widget.equipo.id,
        equipoBaseId: widget.equipo.equipoBaseId,
        nombre: _nameCtrl.text.trim(),
        numero: _numCtrl.text.trim(),
        fotoUrl: fotoUrl,
      );
      widget.onSuccess?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: _ts(color: Colors.white, size: 13)),
      backgroundColor: _P.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            Text(
              'Nuevo jugador',
              style: _ts(size: 18, weight: FontWeight.w800),
            ),
            Text(
              'Se registrará en la liga y en este equipo',
              style: _ts(size: 12, color: _P.slate),
            ),
            const SizedBox(height: 24),
            _ImagePickerWidget(
              image: _image,
              onTap: _pickImage,
              placeholder: 'Foto',
              icon: Icons.person_add_outlined,
            ),
            const SizedBox(height: 22),
            Text(
              'Nombre',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 6),
            _buildField(_nameCtrl, 'Ej. Juan García'),
            const SizedBox(height: 14),
            Text(
              'Número dorsal',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 6),
            _buildField(_numCtrl, 'Ej. 10', keyboardType: TextInputType.number),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildSheetBtn(
                    'Cancelar',
                    false,
                    () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSheetBtn(
                    'Registrar',
                    true,
                    _isSaving ? null : _save,
                    loading: _isSaving,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EDITAR JUGADOR ───────────────────────────────────────────────────────────
class _EditarJugadorSheet extends StatefulWidget {
  final Jugador jugador;
  final Equipo equipo;
  final VoidCallback? onSuccess;
  final void Function(String)? onError;
  const _EditarJugadorSheet({
    required this.jugador,
    required this.equipo,
    this.onSuccess,
    this.onError,
  });
  @override
  State<_EditarJugadorSheet> createState() => _EditarJugadorSheetState();
}

class _EditarJugadorSheetState extends State<_EditarJugadorSheet> {
  File? _newImage;
  late TextEditingController _nameCtrl;
  late TextEditingController _numCtrl;
  final _picker = ImagePicker();
  bool _isSaving = false;
  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.jugador.nombre);
    _numCtrl = TextEditingController(text: widget.jugador.numero);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null && mounted) setState(() => _newImage = File(f.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _numCtrl.text.trim().isEmpty) {
      _snack('Completa nombre y número');
      return;
    }
    setState(() => _isSaving = true);
    try {
      String fotoUrl = widget.jugador.fotoUrl;
      String? fotoAnterior;
      if (_newImage != null) {
        final dir = await getTemporaryDirectory();
        final target =
            '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(_newImage!.path)}';
        final compressed = await FlutterImageCompress.compressAndGetFile(
          _newImage!.path,
          target,
          quality: 75,
        );
        if (compressed == null) throw Exception('Error al comprimir');
        final ref = FirebaseStorage.instance.ref().child(
          'player_photos/${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressed.path)}',
        );
        await ref.putFile(File(compressed.path));
        fotoAnterior = widget.jugador.fotoUrl;
        fotoUrl = await ref.getDownloadURL();
      }
      await _service.editarJugador(
        jugadorBaseId: widget.jugador.jugadorBaseId,
        inscripcionId: widget.jugador.id,
        equipoSnapId: widget.equipo.id,
        equipoBaseId: widget.equipo.equipoBaseId,
        nombre: _nameCtrl.text.trim(),
        numero: _numCtrl.text.trim(),
        fotoUrl: fotoUrl,
        fotoAnteriorUrl: fotoAnterior,
      );
      widget.onSuccess?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: _ts(color: Colors.white, size: 13)),
      backgroundColor: _P.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            Text(
              'Editar jugador',
              style: _ts(size: 18, weight: FontWeight.w800),
            ),
            Text(
              'Los cambios de nombre y foto aplican a todas las temporadas',
              style: _ts(size: 12, color: _P.slate),
            ),
            const SizedBox(height: 24),
            _ImagePickerWidget(
              image: _newImage,
              networkUrl: _newImage == null ? widget.jugador.fotoUrl : null,
              onTap: _pickImage,
              placeholder: 'Foto',
              icon: Icons.person_add_outlined,
            ),
            const SizedBox(height: 22),
            Text(
              'Nombre',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 6),
            _buildField(_nameCtrl, 'Ej. Juan García'),
            const SizedBox(height: 14),
            Text(
              'Número dorsal (esta temporada)',
              style: _ts(size: 12, weight: FontWeight.w600, color: _P.slate),
            ),
            const SizedBox(height: 6),
            _buildField(_numCtrl, 'Ej. 10', keyboardType: TextInputType.number),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildSheetBtn(
                    'Cancelar',
                    false,
                    () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSheetBtn(
                    'Guardar',
                    true,
                    _isSaving ? null : _save,
                    loading: _isSaving,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PLAYER CARD ──────────────────────────────────────────────────────────────
class _PlayerCard extends StatefulWidget {
  final Jugador jugador;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _PlayerCard({
    required this.jugador,
    required this.index,
    required this.onDelete,
    required this.onEdit,
  });
  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false; // ← para el efecto tap

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 260 + widget.index * 40),
    );
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.jugador;
    return FadeTransition(
      opacity: _ctrl,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(0.0, _pressed ? -6.0 : 0.0)
              ..scale(_pressed ? 1.03 : 1.0),
            decoration: BoxDecoration(
              color: _P.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: _P.blue.withOpacity(_pressed ? 0.25 : 0.05),
                  blurRadius: _pressed ? 14 : 6,
                  offset: Offset(0, _pressed ? 8 : 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: j.fotoUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: _P.bg,
                              shape: BoxShape.circle,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: _P.bg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: _P.slate,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        j.nombre,
                        style: _ts(size: 13, weight: FontWeight.w700),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _badge('#${j.numero}', _P.blue, _P.blueLight),
                          const SizedBox(width: 6),
                          _badge(
                            '${j.goles}',
                            _P.green,
                            _P.greenLight,
                            icon: Icons.sports_soccer_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 2,
                  child: Row(
                    children: [
                      _iconBtn(Icons.edit_outlined, _P.slate, widget.onEdit),
                      _iconBtn(
                        Icons.remove_circle_outline_rounded,
                        _P.slate,
                        widget.onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, Color bg, {IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: _ts(size: 11, weight: FontWeight.w700, color: color),
            ),
          ],
        ),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

// ─── WIDGETS REUTILIZABLES ────────────────────────────────────────────────────

Widget _buildHandle() => Center(
  child: Container(
    margin: const EdgeInsets.only(top: 12, bottom: 20),
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: _P.border,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

Widget _buildField(
  TextEditingController ctrl,
  String hint, {
  TextInputType? keyboardType,
}) => TextField(
  controller: ctrl,
  keyboardType: keyboardType,
  style: GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF1A1A2E),
  ),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFFE8EAF0)),
    filled: true,
    fillColor: const Color(0xFFF0F2F5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE8EAF0), width: 0.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE8EAF0), width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3A6FD8), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  ),
);

Widget _buildSheetBtn(
  String label,
  bool filled,
  VoidCallback? onTap, {
  bool loading = false,
}) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF3A6FD8) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
        border: filled
            ? null
            : Border.all(color: const Color(0xFFE8EAF0), width: 0.5),
      ),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : const Color(0xFF9A9FBA),
              ),
            ),
    ),
  ),
);

Widget _dialogBtnStatic(
  String label,
  bool filled,
  VoidCallback onTap, {
  bool isDestructive = false,
}) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: filled
            ? (isDestructive
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF3A6FD8))
            : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(10),
        border: filled
            ? null
            : Border.all(color: const Color(0xFFE8EAF0), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : const Color(0xFF9A9FBA),
        ),
      ),
    ),
  ),
);

class _ImagePickerWidget extends StatelessWidget {
  final File? image;
  final String? networkUrl;
  final VoidCallback onTap;
  final String placeholder;
  final IconData icon;

  const _ImagePickerWidget({
    required this.onTap,
    required this.placeholder,
    required this.icon,
    this.image,
    this.networkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = image != null;
    final hasNetwork = networkUrl != null && networkUrl!.isNotEmpty;
    final hasImage = hasFile || hasNetwork;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _P.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasImage ? _P.blue.withOpacity(0.4) : _P.border,
                  width: hasImage ? 2 : 1,
                ),
                image: hasFile
                    ? DecorationImage(
                        image: FileImage(image!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasFile
                  ? null
                  : hasNetwork
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: networkUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: _P.bg),
                        errorWidget: (_, __, ___) => _placeholder(),
                      ),
                    )
                  : _placeholder(),
            ),
            if (hasImage)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: _P.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: _P.slate, size: 26),
      const SizedBox(height: 2),
      Text(
        placeholder,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          color: _P.slate,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _ColorSelectorWidget extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;
  const _ColorSelectorWidget({required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _P.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _P.border, width: 0.5),
        ),
        title: Text(
          'Elige un color',
          style: _ts(size: 16, weight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: onChanged,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Listo',
              style: _ts(color: _P.blue, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: _P.border, width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: _ts(size: 13, weight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _P.slate, size: 20),
        ],
      ),
    ),
  );
}
