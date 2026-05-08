import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/matchdays_screen.dart';
import '../screens/tables_screen.dart';
import '../screens/management_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _showStandings = true;
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // ← NUEVO

  bool get _isAdmin => AuthService().isAdmin;

  static const int _idxHome = 0;
  static const int _idxJornadas = 1;
  static const int _idxTablas = 2;
  static const int _idxGestion = 3;
  static const int _idxAdmin = 4;

  List<Widget> _buildScreens() {
    return [
      // 0 — Home
      HomeScreen(
        onGoToMatchdays: () => setState(() => _currentIndex = _idxJornadas),
        onGoToTables: (showStandings) => setState(() {
          _currentIndex = _idxTablas;
          _showStandings = showStandings;
        }),
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(), // ← NUEVO
      ),

      // 1 — Jornadas
      const MatchdaysScreen(),

      // 2 — Tablas
      TablesScreen(showStandings: _showStandings),

      // 3 y 4 — Solo admin
      if (_isAdmin) const ManagementScreen(),
      if (_isAdmin)
        AdminPanelScreen(
          onGoToMatchdays: () => setState(() => _currentIndex = _idxJornadas),
          onGoToTeams: () => setState(() => _currentIndex = _idxGestion),
          onGoBack: () => setState(() => _currentIndex = _idxHome),
        ),
    ];
  }

  List<BottomNavigationBarItem> _buildItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Inicio',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today_outlined),
        activeIcon: Icon(Icons.calendar_today),
        label: 'Jornadas',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.table_chart_outlined),
        activeIcon: Icon(Icons.table_chart),
        label: 'Tablas',
      ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Gestión',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final items = _buildItems();

    if (_currentIndex >= screens.length) _currentIndex = 0;

    return Scaffold(
      key: _scaffoldKey, // ← NUEVO
      drawer: AppDrawer(
        onGoToAdmin: _isAdmin
            ? () => setState(() => _currentIndex = _idxAdmin)
            : null,
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: _currentIndex == _idxAdmin
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 0.5, color: const Color(0xFFE8EAF0)),
                BottomNavigationBar(
                  currentIndex: _currentIndex.clamp(0, items.length - 1),
                  onTap: (index) => setState(() {
                    _currentIndex = index;
                    if (index == _idxTablas) _showStandings = true;
                  }),
                  type: BottomNavigationBarType.fixed,
                  showSelectedLabels: true,
                  showUnselectedLabels: false,
                  iconSize: 26,
                  backgroundColor: const Color(0xFFFBFBFC),
                  elevation: 0,
                  selectedItemColor: const Color(0xFF3A6FD8),
                  unselectedItemColor: const Color(0xFF9A9FBA),
                  selectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  items: items,
                ),
              ],
            ),
    );
  }
}
