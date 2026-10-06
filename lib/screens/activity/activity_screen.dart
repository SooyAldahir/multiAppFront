import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../modules.dart';

/// Feed con lo último que pasó en todas las apps.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

/// Relación entre el "module" que manda la API y el módulo de la app.
const _apiModuleToApp = {
  'event': 'agenda',
  'todo': 'todos',
  'note': 'notes',
  'expense': 'expenses',
  'shopping': 'shopping',
};

const _filters = [
  (null, 'Todo'),
  ('todo', 'Pendientes'),
  ('event', 'Agenda'),
  ('note', 'Notas'),
];

class _ActivityScreenState extends State<ActivityScreen> {
  String? _filter;
  List<ActivityItem> _items = [];
  bool _loading = true;
  String? _error;
  late final DataRefresh _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = context.read<DataRefresh>()..addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<DashboardRepository>().activity(module: _filter);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Error inesperado: $e';
        _loading = false;
      });
    }
  }

  void _setFilter(String? f) {
    setState(() {
      _filter = f;
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TopBar(
            eyebrow: 'En todas tus apps',
            title: 'Actividad',
            initials: user?.initials,
            avatarUrl: user?.avatarUrl,
            onProfile: widget.onOpenProfile,
          ),
          _FilterTabs(selected: _filter, onSelect: _setFilter),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Reciente'),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_items.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Sin actividad todavía',
              message: 'Cuando crees eventos, notas o pendientes aparecerán aquí.',
            )
          else
            for (final item in _items) _ActivityRow(item: item),
        ],
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final (value, label) in _filters)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selected == value
                        ? const [BoxShadow(color: Color(0x1223202F), blurRadius: 8, offset: Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected == value ? const Color(0xFF4C4855) : AppColors.muted,
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

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final ActivityItem item;

  String get _headline {
    final noun = switch (item.module) {
      'event' => ('Evento', false),
      'todo' => ('Tarea', true),
      'note' => ('Nota', true),
      'expense' => ('Gasto', false),
      'shopping' => ('Artículo', false),
      _ => ('Elemento', false),
    };
    final (word, feminine) = noun;
    final verb = switch (item.action) {
      'completed' => feminine ? 'completada' : 'completado',
      'updated' => feminine ? 'actualizada' : 'actualizado',
      _ => feminine ? 'creada' : 'creado',
    };
    return '$word $verb';
  }

  @override
  Widget build(BuildContext context) {
    final module = moduleById(_apiModuleToApp[item.module] ?? 'todos');
    final isRecent = DateTime.now().difference(item.updatedAt).inHours < 1;

    return InkWell(
      onTap: () => openModule(context, module),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFECEBF0)))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleIcon(icon: module.icon, tint: module.tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_headline, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      Text(Fmt.ago(item.updatedAt), style: const TextStyle(color: AppColors.mutedLight, fontSize: 11)),
                      if (isRecent) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: Color(0xFF735FD5), shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF74727D), fontSize: 13),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEFEFF2), borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      module.name,
                      style: const TextStyle(color: Color(0xFF8D8B95), fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
