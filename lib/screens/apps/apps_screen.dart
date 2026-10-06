import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../widgets/common.dart';
import '../modules.dart';

/// Menú principal con todas las apps disponibles dentro de multiApp.
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key, required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úù]'), 'u');

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final q = _normalize(_query.trim());
    final modules = q.isEmpty
        ? appModules
        : appModules.where((m) => _normalize('${m.name} ${m.description}').contains(q)).toList();

    return GestureDetector(
      onTap: () => _focus.unfocus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TopBar(
            eyebrow: 'Todo en un solo lugar',
            title: 'Tus apps',
            initials: user?.initials,
            avatarUrl: user?.avatarUrl,
            onProfile: widget.onOpenProfile,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: _focus.hasFocus
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.09), spreadRadius: 3)]
                  : null,
            ),
            child: TextField(
              controller: _search,
              focusNode: _focus,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar apps y acciones',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mutedLight),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.mutedLight),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          SectionHeader(title: 'Todas tus apps', trailing: '${modules.length}'),
          if (modules.isEmpty)
            const EmptyState(icon: Icons.search_off_rounded, title: 'Sin resultados', message: 'Prueba con otra palabra.')
          else
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 18,
              childAspectRatio: 0.78,
              children: [for (final m in modules) _AppGridItem(module: m)],
            ),
          const SizedBox(height: 28),
          _AutomationCard(onTap: () => openModule(context, moduleById('recipes'))),
        ],
      ),
    );
  }
}

class _AppGridItem extends StatelessWidget {
  const _AppGridItem({required this.module});
  final AppModule module;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openModule(context, module),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: module.available ? 1 : 0.55,
            child: ModuleIcon(icon: module.icon, tint: module.tint, large: true),
          ),
          const SizedBox(height: 8),
          Text(
            module.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (!module.available)
            const Text('Pronto', style: TextStyle(fontSize: 10, color: AppColors.mutedLight, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon) => Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFFC1B7F6)),
        );
    Widget dash() => Container(width: 18, height: 1, color: const Color(0xFF777181));

    return GlowCard(
      padding: const EdgeInsets.all(22),
      glowAlignment: Alignment.bottomRight,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            chip(Icons.restaurant_menu_rounded),
            dash(),
            chip(Icons.shopping_cart_outlined),
            dash(),
            chip(Icons.calendar_month_outlined),
          ]),
          const SizedBox(height: 18),
          const Text('FLUJOS INTELIGENTES',
              style: TextStyle(color: Color(0xFFB8ABF4), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          const Text('Haz que tus apps trabajen juntas',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Pide una receta a la IA, conviértela en tu lista de compras y agenda cuándo cocinarla.',
            style: TextStyle(color: Color(0xFFAAA6B1), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Text('Probar el recetario',
                  style: TextStyle(color: Color(0xFFD5CDF8), fontSize: 13, fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 17, color: Color(0xFFD5CDF8)),
            ],
          ),
        ],
      ),
    );
  }
}
