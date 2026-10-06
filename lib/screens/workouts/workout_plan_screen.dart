import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import 'workout_session_screen.dart';

/// Abre el tutorial de YouTube (búsqueda del ejercicio).
Future<void> openTutorial(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMessage(context, 'No se pudo abrir YouTube', error: true);
}

/// Muestra la rutina generada por la IA: por qué, calentamiento, ejercicios y estiramientos.
class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({super.key, this.focus, required this.minutes});
  final String? focus;
  final int minutes;

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  WorkoutPlan? _plan;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await context.read<WorkoutsRepository>().generate(focus: widget.focus, minutes: widget.minutes);
      if (!mounted) return;
      setState(() {
        _plan = plan;
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

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(plan?.title ?? 'Tu rutina'),
        actions: [
          if (!_loading)
            IconButton(tooltip: 'Otra rutina', onPressed: _generate, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      bottomNavigationBar: plan == null || plan.exercises.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => WorkoutSessionScreen(plan: plan)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Empezar entrenamiento'),
                ),
              ),
            ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Armando tu rutina…', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            )
          : _error != null
              ? Center(child: ErrorState(message: _error!, onRetry: _generate))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(icon: Icons.timer_outlined, text: '${plan!.durationMinutes} min'),
                        _Pill(icon: Icons.local_fire_department_outlined, text: '~${plan.estimatedCalories} kcal'),
                        _Pill(icon: Icons.format_list_numbered_rounded, text: '${plan.exercises.length} ejercicios'),
                      ],
                    ),
                    if (plan.reason.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      InsightCard(icon: Icons.auto_awesome, title: plan.focus.isEmpty ? 'Por qué hoy' : plan.focus, subtitle: plan.reason),
                    ],
                    if (plan.warmup.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const SectionHeader(title: 'Calentamiento'),
                      _Bullets(items: plan.warmup),
                    ],
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Ejercicios'),
                    for (var i = 0; i < plan.exercises.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ExerciseCard(index: i + 1, exercise: plan.exercises[i]),
                      ),
                    if (plan.cooldown.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const SectionHeader(title: 'Estiramiento final'),
                      _Bullets(items: plan.cooldown),
                    ],
                    if (plan.tips.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      InsightCard(
                        icon: Icons.lightbulb_outline_rounded,
                        title: 'Consejos',
                        subtitle: plan.tips.map((t) => '• $t').join('\n'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Rutina generada por IA como guía general. Si sientes dolor, detente; ante lesiones o condiciones médicas consulta a un profesional.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedLight, fontSize: 11),
                    ),
                  ],
                ),
    );
  }
}

/// Tarjeta desplegable de un ejercicio con instrucciones, errores comunes y tutorial.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({super.key, required this.index, required this.exercise, this.trailing});
  final int index;
  final PlanExercise exercise;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: ModuleTint.coral.background, borderRadius: BorderRadius.circular(11)),
            child: Text('$index', style: TextStyle(color: ModuleTint.coral.foreground, fontWeight: FontWeight.w800)),
          ),
          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Text(
            '${e.sets} × ${e.reps} · descanso ${e.restSeconds} s${e.muscles.isEmpty ? '' : ' · ${e.muscles.join(', ')}'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          trailing: trailing,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (e.instructions.isNotEmpty) ...[
              const Text('Cómo hacerlo', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (var i = 0; i < e.instructions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i + 1}. ${e.instructions[i]}', style: const TextStyle(height: 1.4)),
                ),
            ],
            if (e.commonMistakes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Evita', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.priorityHigh)),
              const SizedBox(height: 4),
              for (final m in e.commonMistakes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $m', style: const TextStyle(height: 1.4)),
                ),
            ],
            if (e.easierVariant != null && e.easierVariant!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Versión más fácil: ${e.easierVariant}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
            if (e.youtubeUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openTutorial(context, e.youtubeUrl),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD93025),
                  side: const BorderSide(color: Color(0xFFF4C7C3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Ver tutorial en YouTube'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
