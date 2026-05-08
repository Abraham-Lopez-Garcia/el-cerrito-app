import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../models/partido_model.dart';

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

// ─── MAIN SCREEN ───────────────────────────────────────────────────────────
class AddMatchdayScreen extends StatefulWidget {
  const AddMatchdayScreen({super.key});

  @override
  State<AddMatchdayScreen> createState() => _AddMatchdayScreenState();
}

class _AddMatchdayScreenState extends State<AddMatchdayScreen> {
  final TextEditingController _matchdayNumberController =
      TextEditingController();
  final List<Partido> _matches = [];

  List<Map<String, dynamic>> _teams = [];
  bool _isLoadingTeams = true;
  bool _isPublishing = false;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _matchdayNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    try {
      final results = await Future.wait([
        _firestoreService.getEquiposResumen(),
        _firestoreService.getJornadas(),
      ]);

      final equipos = results[0] as List<Map<String, String>>;
      final jornadas = results[1] as List;

      final siguienteNumero = jornadas.isEmpty
          ? 1
          : (jornadas
                    .map((j) => j.numero as int)
                    .reduce((a, b) => a > b ? a : b)) +
                1;

      if (mounted) {
        setState(() {
          _teams = equipos;
          _isLoadingTeams = false;
        });
        // Solo prellenar si el usuario no ha tocado el campo
        if (_matchdayNumberController.text.isEmpty) {
          _matchdayNumberController.text = '$siguienteNumero';
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeams = false);
        _showSnack('Error al cargar equipos: $e', isError: true);
      }
    }
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

  // ─── EQUIPOS YA USADOS (para advertir duplicados) ──────────────────────
  Set<String> get _usedTeamIds =>
      _matches.expand((m) => [m.equipo1Id, m.equipo2Id]).toSet();

  // ─── DIALOG AÑADIR / EDITAR PARTIDO ────────────────────────────────────
  void _showAddMatchDialog({Partido? matchToEdit, int? editIndex}) {
    String? selectedTeam1Id = matchToEdit?.equipo1Id;
    String? selectedTeam2Id = matchToEdit?.equipo2Id;
    DateTime selectedDate = matchToEdit?.fecha ?? DateTime.now();
    TimeOfDay selectedTime = matchToEdit?.hora != null
        ? TimeOfDay(
            hour: int.parse(matchToEdit!.hora!.split(':')[0]),
            minute: int.parse(matchToEdit.hora!.split(':')[1]),
          )
        : TimeOfDay.now();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isEdit = matchToEdit != null;

          String _formatFecha(DateTime d) {
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
            return '${d.day} ${meses[d.month - 1]} ${d.year}';
          }

          String _formatHora(TimeOfDay t) =>
              '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}';

          return Dialog(
            backgroundColor: _P.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _P.border, width: 0.5),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ───────────────────────────────────────
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
                          child: Icon(
                            isEdit ? Icons.edit_rounded : Icons.add_rounded,
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
                                isEdit ? 'Editar partido' : 'Nuevo partido',
                                style: _ts(size: 15, weight: FontWeight.w700),
                              ),
                              Text(
                                'Selecciona equipos y horario',
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
                          onTap: () => Navigator.pop(context),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Equipos ───────────────────────────────
                        _dialogSectionLabel(Icons.shield_rounded, 'Equipos'),
                        const SizedBox(height: 10),

                        // Equipo 1
                        _buildTeamDropdown(
                          hint: 'Equipo local',
                          value: selectedTeam1Id,
                          excludeId: selectedTeam2Id,
                          onChanged: (v) =>
                              setDialogState(() => selectedTeam1Id = v),
                        ),
                        const SizedBox(height: 8),

                        // VS badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _P.bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _P.border, width: 0.5),
                            ),
                            child: Text(
                              'VS',
                              style: _ts(
                                size: 11,
                                weight: FontWeight.w800,
                                color: _P.slate,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Equipo 2
                        _buildTeamDropdown(
                          hint: 'Equipo visitante',
                          value: selectedTeam2Id,
                          excludeId: selectedTeam1Id,
                          onChanged: (v) =>
                              setDialogState(() => selectedTeam2Id = v),
                        ),

                        const SizedBox(height: 20),

                        // ── Fecha y hora ──────────────────────────
                        _dialogSectionLabel(
                          Icons.calendar_today_rounded,
                          'Fecha y hora',
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: _buildDateTimeButton(
                                icon: Icons.calendar_today_rounded,
                                label: _formatFecha(selectedDate),
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: _P.blue,
                                          onPrimary: Colors.white,
                                          surface: _P.surface,
                                          onSurface: _P.navy,
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (date != null) {
                                    setDialogState(() => selectedDate = date);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDateTimeButton(
                                icon: Icons.access_time_rounded,
                                label: _formatHora(selectedTime),
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime,
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: _P.blue,
                                          onPrimary: Colors.white,
                                          surface: _P.surface,
                                          onSurface: _P.navy,
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (time != null) {
                                    setDialogState(() => selectedTime = time);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  const Divider(height: 0, thickness: 0.5, color: _P.border),

                  // ── Footer ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _dialogButton(
                            label: 'Cancelar',
                            onTap: () => Navigator.pop(context),
                            filled: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dialogButton(
                            label: isEdit
                                ? 'Guardar cambios'
                                : 'Añadir partido',
                            onTap: () => _onConfirmMatch(
                              context,
                              selectedTeam1Id,
                              selectedTeam2Id,
                              selectedDate,
                              selectedTime,
                              matchToEdit,
                              editIndex,
                            ),
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── TEAM DROPDOWN ─────────────────────────────────────────────────────
  Widget _buildTeamDropdown({
    required String hint,
    required String? value,
    required String? excludeId,
    required ValueChanged<String?> onChanged,
  }) {
    final availableTeams = _teams.where((t) => t['id'] != excludeId).toList();

    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(hint, style: _ts(size: 13, color: _P.slate)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          borderRadius: BorderRadius.circular(10),
          items: availableTeams
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t['id'] as String,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(t['nombre'] as String, style: _ts(size: 13)),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dialogSectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _P.blue),
        const SizedBox(width: 6),
        Text(
          label,
          style: _ts(
            size: 11,
            weight: FontWeight.w700,
            color: _P.slate,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: _P.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: _ts(size: 12, weight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogButton({
    required String label,
    required VoidCallback onTap,
    required bool filled,
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

  void _onConfirmMatch(
    BuildContext dialogContext,
    String? team1Id,
    String? team2Id,
    DateTime date,
    TimeOfDay time,
    Partido? matchToEdit,
    int? editIndex,
  ) {
    if (team1Id == null || team2Id == null) {
      _showSnack('Debes seleccionar ambos equipos', isError: true);
      return;
    }
    if (team1Id == team2Id) {
      _showSnack('Los equipos deben ser diferentes', isError: true);
      return;
    }

    final team1 = _teams.firstWhere((t) => t['id'] == team1Id);
    final team2 = _teams.firstWhere((t) => t['id'] == team2Id);
    final horaStr =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    final partido = Partido(
      id: matchToEdit?.id ?? '',
      equipo1Id: team1Id,
      equipo1Nombre: team1['nombre'] as String,
      equipo1LogoUrl: team1['logoUrl'] as String?,
      equipo2Id: team2Id,
      equipo2Nombre: team2['nombre'] as String,
      equipo2LogoUrl: team2['logoUrl'] as String?,
      fecha: date,
      hora: horaStr,
    );

    setState(() {
      if (matchToEdit != null && editIndex != null) {
        _matches[editIndex] = partido;
      } else {
        _matches.add(partido);
      }
    });

    Navigator.pop(dialogContext);
  }

  Future<void> _publishMatchday() async {
    final numText = _matchdayNumberController.text.trim();
    if (numText.isEmpty) {
      _showSnack('Debes ingresar el número de jornada', isError: true);
      return;
    }
    if (_matches.isEmpty) {
      _showSnack('Agrega al menos un partido', isError: true);
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final numero = int.parse(numText);
      await _firestoreService.crearJornada(numero: numero, partidos: _matches);
      if (mounted) {
        _showSnack('Jornada publicada exitosamente');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Error al publicar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final matchdayNumber = _matchdayNumberController.text.trim();
    final canPublish =
        !_isPublishing && _matches.isNotEmpty && matchdayNumber.isNotEmpty;

    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoadingTeams)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: _P.blue,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Número de jornada ──────────────────────
                      _buildJornadaNumberCard(),
                      const SizedBox(height: 14),

                      // ── Partidos header ────────────────────────
                      _buildPartidosHeader(),
                      const SizedBox(height: 10),

                      // ── Lista de partidos ──────────────────────
                      if (_matches.isEmpty)
                        _buildEmptyMatchesState()
                      else
                        ..._matches.asMap().entries.map(
                          (e) => _buildMatchCard(e.value, e.key),
                        ),
                    ],
                  ),
                ),
              ),

            _buildFooter(canPublish),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(6, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _P.navy,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NUEVA JORNADA',
                  style: _ts(
                    size: 20,
                    weight: FontWeight.w800,
                    letterSpacing: 1.6,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Configura los partidos',
                  style: _ts(
                    size: 11,
                    color: _P.slate,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Counter badge
          if (_matches.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _P.blueLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _P.blue.withOpacity(0.25),
                  width: 0.5,
                ),
              ),
              child: Text(
                '${_matches.length} partido${_matches.length != 1 ? 's' : ''}',
                style: _ts(size: 11, weight: FontWeight.w600, color: _P.blue),
              ),
            ),
        ],
      ),
    );
  }

  // ─── JORNADA NUMBER CARD ───────────────────────────────────────────────
  Widget _buildJornadaNumberCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _P.blueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.tag_rounded, color: _P.blue, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Número de jornada',
                  style: _ts(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _P.slate,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Identifica esta jornada',
                  style: _ts(size: 11, color: _P.slate),
                ),
              ],
            ),
          ),
          // Number input
          SizedBox(
            width: 72,
            child: TextField(
              controller: _matchdayNumberController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: _ts(size: 22, weight: FontWeight.w800),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: _ts(
                  size: 22,
                  weight: FontWeight.w800,
                  color: _P.border,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _P.border, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _P.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _P.blue, width: 1.5),
                ),
                filled: true,
                fillColor: _P.bg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PARTIDOS HEADER ───────────────────────────────────────────────────
  Widget _buildPartidosHeader() {
    return Row(
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
        Expanded(
          child: Text(
            'Partidos',
            style: _ts(size: 15, weight: FontWeight.w700),
          ),
        ),
        // Botón añadir
        GestureDetector(
          onTap: _isLoadingTeams ? null : _showAddMatchDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _P.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 5),
                Text(
                  'Añadir',
                  style: _ts(
                    size: 12,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────
  Widget _buildEmptyMatchesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _P.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _P.border, width: 0.5),
            ),
            child: const Icon(
              Icons.sports_soccer_outlined,
              color: _P.slate,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin partidos aún',
            style: _ts(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca "Añadir" para registrar\nlos partidos de esta jornada.',
            textAlign: TextAlign.center,
            style: _ts(size: 12, color: _P.slate, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ─── MATCH CARD ────────────────────────────────────────────────────────
  Widget _buildMatchCard(Partido partido, int index) {
    final meses = [
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
    final fechaStr = partido.fecha != null
        ? '${partido.fecha!.day} ${meses[partido.fecha!.month - 1]}'
        : '';
    final horaStr = partido.hora ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            // Número de partido
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _P.blueLight,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: _ts(size: 13, weight: FontWeight.w700, color: _P.blue),
              ),
            ),
            const SizedBox(width: 12),

            // Info partido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${partido.equipo1Nombre} vs ${partido.equipo2Nombre}',
                    style: _ts(size: 13, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fechaStr.isNotEmpty || horaStr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: _P.slate,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          [
                            fechaStr,
                            horaStr,
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: _ts(size: 11, color: _P.slate),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Acciones
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconAction(
                  icon: Icons.edit_rounded,
                  color: _P.blue,
                  bgColor: _P.blueLight,
                  onTap: () => _showAddMatchDialog(
                    matchToEdit: partido,
                    editIndex: index,
                  ),
                ),
                const SizedBox(width: 6),
                _iconAction(
                  icon: Icons.delete_outline_rounded,
                  color: _P.red,
                  bgColor: _P.redLight,
                  onTap: () => setState(() => _matches.removeAt(index)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  // ─── FOOTER ────────────────────────────────────────────────────────────
  Widget _buildFooter(bool canPublish) {
    return Container(
      color: _P.surface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _P.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _P.border, width: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancelar',
                    style: _ts(
                      size: 14,
                      weight: FontWeight.w600,
                      color: _P.slate,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canPublish ? _publishMatchday : null,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: canPublish ? _P.green : _P.border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _isPublishing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.publish_rounded,
                              color: canPublish ? Colors.white : _P.slate,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Publicar jornada',
                              style: _ts(
                                size: 14,
                                weight: FontWeight.w700,
                                color: canPublish ? Colors.white : _P.slate,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
