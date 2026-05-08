import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionTab {
  final String label;
  final Color color;
  final Color bgColor;
  final GlobalKey sectionKey;

  const SectionTab({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.sectionKey,
  });
}

class LiguillaSectionTabs extends StatefulWidget {
  final ScrollController scrollController;
  final List<SectionTab> tabs;

  const LiguillaSectionTabs({
    super.key,
    required this.scrollController,
    required this.tabs,
  });

  @override
  State<LiguillaSectionTabs> createState() => _LiguillaSectionTabsState();
}

class _LiguillaSectionTabsState extends State<LiguillaSectionTabs> {
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isScrollingProgrammatically) return;
    final scrollOffset = widget.scrollController.offset;
    int newActive = 0;

    for (int i = 0; i < widget.tabs.length; i++) {
      final ctx = widget.tabs[i].sectionKey.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      // Si la sección ya pasó el 65% de la pantalla, actívala
      if (pos.dy < MediaQuery.of(context).size.height * 0.65) {
        newActive = i;
      }
    }

    if (newActive != _activeIndex) {
      setState(() => _activeIndex = newActive);
    }
  }

  bool _isScrollingProgrammatically = false;

  void _scrollToSection(int index) {
    final ctx = widget.tabs[index].sectionKey.currentContext;
    if (ctx == null) return;

    setState(() {
      _activeIndex = index;
      _isScrollingProgrammatically = true;
    });

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.05,
    ).then((_) {
      if (mounted) {
        setState(() => _isScrollingProgrammatically = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.tabs.length, (i) {
        final tab = widget.tabs[i];
        final isActive = i == _activeIndex;

        return GestureDetector(
          onTap: () => _scrollToSection(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            transform: Matrix4.translationValues(isActive ? 0 : 6, 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? tab.bgColor : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                bottomLeft: Radius.circular(7),
              ),
              border: Border.all(
                color: isActive
                    ? tab.color.withOpacity(0.35)
                    : const Color(0xFFE8EAF0),
                width: 0.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 6,
                        offset: const Offset(-2, 0),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barra indicadora izquierda
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 2.5,
                  height: isActive ? 28 : 0,
                  decoration: BoxDecoration(
                    color: tab.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (isActive) const SizedBox(width: 4),
                // Texto rotado (vertical)
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    tab.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isActive ? tab.color : const Color(0xFF9A9FBA),
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
