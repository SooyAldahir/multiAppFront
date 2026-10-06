import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/directions.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/items.dart';
import '../agenda/event_form_screen.dart';
import '../modules.dart';
import '../places/place_categories.dart';
import '../todos/todo_form_sheet.dart';
import 'finance_summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSeeAllApps, required this.onOpenProfile});
  final VoidCallback onSeeAllApps;
  final VoidCallback onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Dashboard? _data;
  List<Place> _places = [];
  BudgetView? _budget;
  List<SavingsFund> _funds = [];
  double _fundsTotal = 0;
  bool _financeLoaded = false;
  String? _error;
  bool _loading = true;
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
    _loadPlaces();
    _loadFinance();
    try {
      final data = await context.read<DashboardRepository>().today();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  /// Los accesos a lugares son secundarios: si fallan, simplemente no se muestran.
  Future<void> _loadPlaces() async {
    try {
      final places = await context.read<PlacesRepository>().all();
      if (mounted) setState(() => _places = places);
    } catch (_) {
      // Sin conexión o sin lugares: la sección no se muestra.
    }
  }

  /// Resumen de finanzas: también es secundario; si falla, la tarjeta no aparece.
  Future<void> _loadFinance() async {
    final budgetRepo = context.read<BudgetRepository>();
    final fundsRepo = context.read<FundsRepository>();
    BudgetView? budget;
    List<SavingsFund> funds = [];
    double total = 0;
    var ok = false;
    try {
      budget = await budgetRepo.current();
      ok = true;
    } catch (_) {}
    try {
      (funds, total) = await fundsRepo.all();
      ok = true;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _budget = budget;
      _funds = funds;
      _fundsTotal = total;
      _financeLoaded = ok;
    });
  }

  Future<void> _toggle(Todo todo) async {
    try {
      await context.read<TodosRepository>().toggle(todo);
      if (mounted) context.read<DataRefresh>().changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TopBar(
            eyebrow: Fmt.longDay(now),
            title: '${Fmt.greeting(now)}, ${user?.firstName ?? ''}',
            initials: user?.initials,
            avatarUrl: user?.avatarUrl,
            onSearch: widget.onSeeAllApps,
            onProfile: widget.onOpenProfile,
          ),
          _AiCard(onTap: () => openModule(context, moduleById('recipes'))),
          const SizedBox(height: 26),
          SectionHeader(title: 'Favoritos', actionLabel: 'Ver todo', onAction: widget.onSeeAllApps),
          Row(
            children: [
              for (final m in appModules.take(4))
                Expanded(
                  child: _FavoriteApp(
                    module: m,
                    badge: m.id == 'todos' && (_data?.counts.pendingTodos ?? 0) > 0
                        ? '${_data!.counts.pendingTodos}'
                        : null,
                  ),
                ),
            ],
          ),
          if (_places.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionHeader(title: 'Ir a…', actionLabel: 'Lugares', onAction: () => openModule(context, moduleById('places'))),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = _places[i];
                  final cat = placeCategory(p.category);
                  return ActionChip(
                    avatar: Icon(cat.icon, size: 18, color: cat.tint.foreground),
                    label: Text(p.name),
                    backgroundColor: cat.tint.background,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                    onPressed: () => showDirections(context, lat: p.latitude, lon: p.longitude, label: p.name),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 26),
          ..._todaySection(),
          if (_financeLoaded) ...[
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Tus finanzas',
              actionLabel: 'Abrir',
              onAction: () => openModule(context, moduleById('expenses')),
            ),
            FinanceSummaryCard(view: _budget, funds: _funds, fundsTotal: _fundsTotal),
          ],
        ],
      ),
    );
  }

  List<Widget> _todaySection() {
    if (_loading) {
      return const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))];
    }
    if (_error != null) return [ErrorState(message: _error!, onRetry: _load)];

    final data = _data!;
    final todos = data.todos.take(3).toList();
    final count = data.events.length + todos.length;
    final free = data.freeTimeToday(DateTime.now());

    return [
      SectionHeader(title: 'Hoy', trailing: count == 1 ? '1 elemento' : '$count elementos'),
      if (count == 0)
        EmptyState(
          icon: Icons.wb_sunny_outlined,
          title: 'Día libre',
          message: 'No tienes eventos ni pendientes para hoy.',
          action: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventFormScreen())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar evento'),
          ),
        ),
      for (final e in data.events)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EventTile(
            event: e,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventFormScreen(event: e))),
          ),
        ),
      for (final t in todos)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TodoTile(
            todo: t,
            subtitlePrefix: 'Pendientes',
            onToggle: () => _toggle(t),
            onTap: () => showTodoForm(context, todo: t),
          ),
        ),
      const SizedBox(height: 12),
      if (free > Duration.zero)
        InsightCard(
          title: 'Tienes ${Fmt.duration(free)} libres hoy',
          subtitle: data.counts.pendingTodos > 0
              ? 'Buen momento para avanzar en tus ${data.counts.pendingTodos} pendientes.'
              : 'Perfecto para enfocarte en lo que más te importa.',
          onTap: () => openModule(context, moduleById('todos')),
        ),
    ];
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.orbStart, AppColors.orbEnd],
              ),
              boxShadow: const [BoxShadow(color: Color(0x596349DA), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MULTIAPP IA',
                    style: TextStyle(color: Color(0xFFB7ACFA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
                SizedBox(height: 4),
                Text('¿Qué quieres cocinar hoy?',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Pide una receta y te digo cómo prepararla',
                    style: TextStyle(color: Color(0xFFAAA7B1), fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _FavoriteApp extends StatelessWidget {
  const _FavoriteApp({required this.module, this.badge});
  final AppModule module;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openModule(context, module),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            ModuleIcon(icon: module.icon, tint: module.tint, large: true, badge: badge),
            const SizedBox(height: 8),
            Text(module.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
