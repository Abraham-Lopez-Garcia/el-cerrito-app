import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';

class FaseSelector extends StatelessWidget {
  final FirestoreService service;

  const FaseSelector({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: service.faseVista,
      builder: (ctx, fase, _) {
        // Solo mostrar si la temporada tiene liguilla habilitada
        final temporada = service.currentSeason;
        final tieneL = temporada?.faseActual == 'liguilla';
        if (!tieneL) return const SizedBox.shrink();

        return Container(
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF3A6FD8).withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FasePill(
                label: 'Liga',
                active: fase == 'liga',
                onTap: () => service.faseVista.value = 'liga',
              ),
              const SizedBox(width: 2),
              _FasePill(
                label: 'Liguilla',
                active: fase == 'liguilla',
                onTap: () => service.faseVista.value = 'liguilla',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FasePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FasePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3A6FD8) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF3A6FD8),
          ),
        ),
      ),
    );
  }
}
