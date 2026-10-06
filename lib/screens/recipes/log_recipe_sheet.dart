import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../health/health_labels.dart';
import '../nutrition/nutrition_widgets.dart';

/// "Lo comí": registra una receta en el conteo de calorías.
/// Pregunta si se cocinó tal cual; si hubo cambios, la IA recalcula con esos cambios.
Future<void> showLogRecipeSheet(BuildContext context, Recipe recipe) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _LogRecipeSheet(recipe: recipe),
  );
}

class _LogRecipeSheet extends StatefulWidget {
  const _LogRecipeSheet({required this.recipe});
  final Recipe recipe;

  @override
  State<_LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends State<_LogRecipeSheet> {
  bool _asIs = true;
  double _servings = 1;
  late String _meal = mealForTime(DateTime.now());
  final _changes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  Recipe get r => widget.recipe;

  /// Describe la receta para que la IA estime una porción (cuando hubo cambios o no hay datos).
  String _promptForAi() {
    final ingredients = r.ingredients.map((i) => i.quantity.isEmpty ? i.name : '${i.quantity} de ${i.name}').join(', ');
    final changes = _changes.text.trim();
    return 'Una porción de "${r.title}" (receta para ${r.servings} porciones con: $ingredients).'
        '${changes.isEmpty ? '' : ' Cambios que hice al cocinarla: $changes.'}';
  }

  Future<void> _save() async {
    if (!_asIs && _changes.text.trim().isEmpty) {
      showMessage(context, 'Cuéntanos qué cambiaste', error: true);
      return;
    }
    final repo = context.read<NutritionRepository>();
    final refresh = context.read<DataRefresh>();
    setState(() => _saving = true);
    try {
      Nutrition perServing;
      if (_asIs && r.nutritionPerServing != null) {
        perServing = r.nutritionPerServing!;
      } else {
        // Con cambios (o receta sin datos nutricionales): la IA estima una porción.
        perServing = (await repo.estimateText(_promptForAi())).total;
      }
      final servingsText = _servings == 1 ? '' : ' (${_servings.toStringAsFixed(_servings % 1 == 0 ? 0 : 1)} porciones)';
      final log = FoodLog.fromNutrition(
        n: perServing * _servings,
        description: '${r.title}$servingsText${_asIs ? '' : ' · con cambios'}',
        meal: _meal,
        source: 'recipe',
        servings: _servings,
        recipeId: r.id,
      );
      await repo.create(log);
      refresh.changed();
      if (!mounted) return;
      showMessage(context, '${log.calories} kcal registradas en ${mealLabels[_meal]!.toLowerCase()}');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = r.nutritionPerServing;
    final preview = n == null ? null : n * _servings;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFFD2D0D7), borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const Text('¿Lo comiste?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(r.title, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 18),
              const Text('¿Lo cocinaste tal cual la receta?', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Sí, tal cual')),
                  ButtonSegment(value: false, label: Text('Con cambios')),
                ],
                selected: {_asIs},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _asIs = s.first),
              ),
              if (!_asIs) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _changes,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Ej. usé pechuga en vez de muslo, sin crema, le puse el doble de queso…',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Porciones que comiste', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: _servings > 0.5 ? () => setState(() => _servings -= 0.5) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(_servings.toStringAsFixed(_servings % 1 == 0 ? 0 : 1),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: _servings < 10 ? () => setState(() => _servings += 0.5) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MealPicker(value: _meal, onChanged: (m) => setState(() => _meal = m), labels: mealLabels, icons: mealIcons),
              const SizedBox(height: 16),
              if (_asIs && preview != null)
                InsightCard(
                  icon: Icons.local_fire_department_outlined,
                  title: '${preview.calories.round()} kcal',
                  subtitle: 'Proteína ${preview.protein.round()} g · Carbs ${preview.carbs.round()} g · Grasa ${preview.fat.round()} g',
                )
              else
                const InsightCard(
                  icon: Icons.auto_awesome,
                  title: 'La IA calculará las calorías',
                  subtitle: 'Tomando en cuenta la receta y tus cambios.',
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
