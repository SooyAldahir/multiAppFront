import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../health/health_labels.dart';
import '../health/health_profile_screen.dart';
import 'add_food_screen.dart';
import 'nutrition_widgets.dart';

/// Conteo de calorías del día: meta, macros, quemadas en ejercicio y comidas registradas.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _day = startOfDay(DateTime.now());
  NutritionSummary? _summary;
  List<FoodLog> _logs = [];
  bool _loading = true;
  String? _error;
  late final DataRefresh _refresh;

  bool get _isToday => _day == startOfDay(DateTime.now());

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
    final from = _day;
    final to = DateTime(_day.year, _day.month, _day.day + 1);
    try {
      final repo = context.read<NutritionRepository>();
      final results = await Future.wait([repo.summary(from, to), repo.logs(from, to)]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as NutritionSummary;
        _logs = results[1] as List<FoodLog>;
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

  void _changeDay(int delta) {
    setState(() {
      _day = DateTime(_day.year, _day.month, _day.day + delta);
      _loading = true;
    });
    _load();
  }

  Future<void> _delete(FoodLog log) async {
    final repo = context.read<NutritionRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _logs = _logs.where((l) => l.id != log.id).toList());
    try {
      await repo.delete(log.id!);
      refresh.changed();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      _load();
    }
  }

  Future<void> _openProfile() async {
    final health = await context.read<HealthRepository>().get().catchError((_) => const HealthData());
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HealthProfileScreen(initial: health.profile)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calorías'),
        actions: [IconButton(tooltip: 'Perfil de salud', onPressed: _openProfile, icon: const Icon(Icons.tune_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddFoodScreen(day: _day))),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar comida'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            Row(
              children: [
                IconButton(onPressed: () => _changeDay(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: Text(
                    _isToday ? 'Hoy' : Fmt.capitalize(Fmt.longDay(_day)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _isToday ? null : () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else ...[
              _SummaryCard(summary: _summary!, onSetupProfile: _openProfile),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Row(
                  children: [
                    Expanded(
                      child: MacroBar(
                        label: 'Proteína',
                        value: _summary!.consumed.protein,
                        target: _summary!.targets?.protein,
                        color: ModuleTint.coral.foreground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MacroBar(
                        label: 'Carbohidratos',
                        value: _summary!.consumed.carbs,
                        target: _summary!.targets?.carbs,
                        color: ModuleTint.blue.foreground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MacroBar(
                        label: 'Grasa',
                        value: _summary!.consumed.fat,
                        target: _summary!.targets?.fat,
                        color: ModuleTint.amber.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_logs.isEmpty)
                const EmptyState(
                  icon: Icons.restaurant_rounded,
                  title: 'Sin comidas registradas',
                  message: 'Describe lo que comiste o tómale foto al plato y calculamos las calorías.',
                )
              else
                for (final meal in mealLabels.keys)
                  if (_logs.any((l) => l.meal == meal)) ...[
                    SectionHeader(
                      title: mealLabels[meal]!,
                      trailing: '${_logs.where((l) => l.meal == meal).fold<int>(0, (a, l) => a + l.calories)} kcal',
                    ),
                    for (final log in _logs.where((l) => l.meal == meal))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey('food-${log.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.priorityHighBg,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh),
                          ),
                          onDismissed: (_) => _delete(log),
                          child: _FoodTile(log: log),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
              const SizedBox(height: 8),
              const Text(
                'Las calorías estimadas por IA son aproximadas y sirven como guía.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedLight, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onSetupProfile});
  final NutritionSummary summary;
  final VoidCallback onSetupProfile;

  @override
  Widget build(BuildContext context) {
    final goal = summary.targets?.calories;
    final consumed = summary.consumed.calories;
    // Las calorías quemadas en ejercicio se suman al presupuesto del día.
    final budget = goal == null ? null : goal + summary.burned;
    final left = budget == null ? null : budget - consumed;

    return GlowCard(
      child: Row(
        children: [
          CalorieRing(consumed: consumed, goal: budget),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (left != null) ...[
                  Text(
                    left >= 0 ? 'Te quedan' : 'Te pasaste por',
                    style: const TextStyle(color: Color(0xFFB7ACFA), fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${left.abs().round()} kcal',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('Meta: ${goal!.round()} kcal', style: const TextStyle(color: Color(0xFFAAA7B1), fontSize: 12)),
                ] else ...[
                  const Text('Sin meta todavía', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onSetupProfile,
                    child: const Text(
                      'Completa tu perfil de salud para calcularla →',
                      style: TextStyle(color: Color(0xFFD5CDF8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFFB38A)),
                    const SizedBox(width: 4),
                    Text(
                      'Ejercicio: +${summary.burned} kcal',
                      style: const TextStyle(color: Color(0xFFAAA7B1), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.log});
  final FoodLog log;

  @override
  Widget build(BuildContext context) {
    final macros = [
      if (log.proteinG != null) 'P ${log.proteinG!.round()} g',
      if (log.carbsG != null) 'C ${log.carbsG!.round()} g',
      if (log.fatG != null) 'G ${log.fatG!.round()} g',
    ].join(' · ');
    return SurfaceCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: log.imageUrl != null
                ? Image.network(
                    log.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _FoodIcon(),
                  )
                : const _FoodIcon(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (macros.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(macros, style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
                ],
              ],
            ),
          ),
          Text('${log.calories} kcal', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FoodIcon extends StatelessWidget {
  const _FoodIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: ModuleTint.amber.background,
      child: Icon(Icons.restaurant_rounded, color: ModuleTint.amber.foreground),
    );
  }
}
