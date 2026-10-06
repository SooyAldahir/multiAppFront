import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/repositories.dart';
import '../activity/activity_screen.dart';
import '../apps/apps_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import 'quick_create_sheet.dart';

/// Estructura principal: 4 pestañas + botón central de "Crear rápido" (como en el mockup).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  DataRefresh? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNotifications());
  }

  Future<void> _startNotifications() async {
    if (!mounted) return;
    final profile = context.read<ProfileRepository>();
    final events = context.read<EventsRepository>();
    final todos = context.read<TodosRepository>();
    _refresh = context.read<DataRefresh>()..addListener(_onDataChanged);

    await NotificationService.instance.requestPermission();
    await PushService.instance.start(profile);
    await NotificationService.instance.sync(profile, events, todos);
  }

  /// Cualquier cambio (evento, pendiente…) reprograma los recordatorios.
  void _onDataChanged() {
    if (!mounted) return;
    NotificationService.instance.scheduleSync(
      context.read<ProfileRepository>(),
      context.read<EventsRepository>(),
      context.read<TodosRepository>(),
    );
  }

  @override
  void dispose() {
    _refresh?.removeListener(_onDataChanged);
    super.dispose();
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onSeeAllApps: () => _goTo(1), onOpenProfile: () => _goTo(3)),
      AppsScreen(onOpenProfile: () => _goTo(3)),
      ActivityScreen(onOpenProfile: () => _goTo(3)),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onSelect: _goTo,
        onCreate: () => showQuickCreate(context),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect, required this.onCreate});
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final initials = context.select<AuthController, String>((a) => a.user?.initials ?? '?');
    final avatarUrl = context.select<AuthController, String?>((a) => a.user?.avatarUrl);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF0FFFFFF),
            border: Border(top: BorderSide(color: Color(0xFFE8E7EB))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 70,
              child: Row(
                children: [
                  _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Inicio', active: index == 0, onTap: () => onSelect(0)),
                  _NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Apps', active: index == 1, onTap: () => onSelect(1)),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -10),
                        child: Semantics(
                          button: true,
                          label: 'Crear rápido',
                          child: GestureDetector(
                            onTap: onCreate,
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: AppColors.fab,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.background, width: 5),
                                boxShadow: const [BoxShadow(color: Color(0x33211E2C), blurRadius: 16, offset: Offset(0, 7))],
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _NavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Actividad', active: index == 2, onTap: () => onSelect(2)),
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelect(3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (avatarUrl != null)
                            Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: index == 3 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  avatarUrl,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: index == 3 ? AppColors.primary : const Color(0xFFE7E6EB),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                initials,
                                style: TextStyle(
                                  color: index == 3 ? Colors.white : const Color(0xFF62606A),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Perfil',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: index == 3 ? AppColors.primary : AppColors.mutedLight,
                            ),
                          ),
                        ],
                      ),
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
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF6756CF) : AppColors.mutedLight;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 25),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
