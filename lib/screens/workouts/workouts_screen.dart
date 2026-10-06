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
import 'workout_plan_screen.dart';

/// Ejercicio: genera la rutina del día con IA y muestra el historial de la semana.
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  HealthData? _health;
  List<WorkoutSession> _history = [];
  bool _loading = true;
  String? _error;
  String? _focus; // null = la IA decide
  int? _minutes;
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
      final results = await Future.wait([
        context.read<HealthRepository>().get(),
        context.read<WorkoutsRepository>().history(from: DateTime.now().subtract(const Duration(days: 30))),
      ]);
      if (!mounted) return;
      setState(() {
        _health = results[0] as HealthData;
        _history = results[1] as List<WorkoutSession>;
        _minutes ??= _health?.profile?.minutesPerSession ?? 45;
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

  Future<void> _editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HealthProfileScreen(initial: _health?.profile)),
    );
  }

  void _generate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutPlanScreen(focus: _focus, minutes: _minutes ?? 45)),
    );
  }

  Future<void> _delete(WorkoutSession s) async {
    final ok = await confirm(context, title: 'Eliminar entrenamiento', message: '¿Eliminar "${s.title}" del historial?');
    if (!ok || !mounted) return;
    try {
      await context.read<WorkoutsRepository>().delete(s.id!);
      if (mounted) setState(() => _history = _history.where((x) => x.id != s.id).toList());
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicio'),
        actions: [IconButton(tooltip: 'Perfil de salud', onPressed: _editProfile, icon: const Icon(Icons.tune_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: ErrorState(message: _error!, onRetry: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      if (_health?.profile == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InsightCard(
                            icon: Icons.person_outline_rounded,
                            title: 'Completa tu perfil de salud',
                            subtitle: 'Así las rutinas se adaptan a tu nivel, objetivo y equipo.',
                            onTap: _editProfile,
                          ),
                        ),
                      _GenerateCard(
                        focus: _focus,
                        minutes: _minutes ?? 45,
                        onFocus: (f) => setState(() => _focus = f),
                        onMinutes: (m) => setState(() => _minutes = m),
                        onGenerate: _generate,
                      ),
                      const SizedBox(height: 24),
                      _WeekStats(history: _history, target: _health?.profile?.daysPerWeek),
                      const SizedBox(height: 24),
                      SectionHeader(title: 'Historial', trailing: _history.isEmpty ? null : '${_history.length}'),
                      if (_history.isEmpty)
                        const EmptyState(
                          icon: Icons.fitness_center_rounded,
                          title: 'Aún no hay entrenamientos',
                          message: 'Genera tu primera rutina y márcala al terminar.',
                        )
                      else
                        for (final s in _history)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SurfaceCard(
                              onTap: () => _showSession(s),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const ModuleIcon(icon: Icons.fitness_center_rounded, tint: ModuleTint.coral),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${Fmt.capitalize(Fmt.relativeDay(s.performedAt))} · ${s.durationMinutes} min · ${s.caloriesBurned} kcal',
                                          style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _delete(s),
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedLight),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }

  void _showSession(WorkoutSession s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${Fmt.capitalize(Fmt.longDay(s.performedAt))} · ${s.durationMinutes} min · ${s.caloriesBurned} kcal',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              for (final e in s.exercises)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        (e['setsDone'] ?? 0) >= (e['setsPlanned'] ?? 1) ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                        size: 18,
                        color: (e['setsDone'] ?? 0) >= (e['setsPlanned'] ?? 1) ? AppColors.success : AppColors.mutedLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${e['name']}')),
                      Text('${e['setsDone'] ?? 0}/${e['setsPlanned'] ?? 0} series', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateCard extends StatelessWidget {
  const _GenerateCard({
    required this.focus,
    required this.minutes,
    required this.onFocus,
    required this.onMinutes,
    required this.onGenerate,
  });

  final String? focus;
  final int minutes;
  final ValueChanged<String?> onFocus;
  final ValueChanged<int> onMinutes;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RUTINA DE HOY',
              style: TextStyle(color: Color(0xFFB7ACFA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
          const SizedBox(height: 4),
          const Text('¿Qué quieres entrenar?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (value, label) in focusOptions)
                ChoiceChip(
                  label: Text(label),
                  selected: focus == value,
                  showCheckmark: false,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  selectedColor: AppColors.orbStart,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  labelStyle: TextStyle(
                    color: focus == value ? Colors.white : const Color(0xFFD5CDF8),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  onSelected: (_) => onFocus(value),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFFAAA7B1), size: 20),
              const SizedBox(width: 8),
              Text('$minutes minutos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Expanded(
                child: Slider(
                  value: minutes.clamp(15, 120).toDouble(),
                  min: 15,
                  max: 120,
                  divisions: 21,
                  activeColor: AppColors.orbStart,
                  onChanged: (v) => onMinutes(v.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generar rutina'),
          ),
        ],
      ),
    );
  }
}

class _WeekStats extends StatelessWidget {
  const _WeekStats({required this.history, this.target});
  final List<WorkoutSession> history;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final week = history.where((s) => !s.performedAt.isBefore(monday)).toList();
    final minutes = week.fold<int>(0, (a, s) => a + s.durationMinutes);
    final kcal = week.fold<int>(0, (a, s) => a + s.caloriesBurned);

    Widget stat(String value, String label) => Expanded(
          child: SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Esta semana'),
        Row(
          children: [
            stat(target == null ? '${week.length}' : '${week.length}/$target', 'entrenamientos'),
            const SizedBox(width: 8),
            stat('$minutes', 'minutos'),
            const SizedBox(width: 8),
            stat('$kcal', 'kcal quemadas'),
          ],
        ),
      ],
    );
  }
}
