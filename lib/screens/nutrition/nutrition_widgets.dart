import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';

/// Anillo de progreso de calorías (consumidas vs meta).
class CalorieRing extends StatelessWidget {
  const CalorieRing({super.key, required this.consumed, this.goal, this.size = 132});
  final double consumed;
  final double? goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = goal ?? 0;
    final progress = g <= 0 ? 0.0 : (consumed / g);
    final over = progress > 1;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: progress.clamp(0.0, 1.0).toDouble(), over: over),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${consumed.round()}',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              Text(
                g > 0 ? 'de ${g.round()} kcal' : 'kcal',
                style: const TextStyle(color: Color(0xFFAAA7B1), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.over});
  final double progress;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bg);
    if (progress <= 0) return;
    final fg = Paint()
      ..color = over ? const Color(0xFFFF8A7A) : AppColors.orbStart
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.over != over;
}

/// Barra de un macronutriente (consumido vs meta).
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.value, this.target, required this.color});
  final String label;
  final double value;
  final double? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = target ?? 0;
    final share = t <= 0 ? 0.0 : (value / t).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          t > 0 ? '${value.round()}/${t.round()} g' : '${value.round()} g',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 6,
            backgroundColor: AppColors.chip,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Resumen de una estimación de la IA, con multiplicador de porciones.
class EstimateReview extends StatelessWidget {
  const EstimateReview({super.key, required this.estimate, required this.servings, required this.onServings});
  final FoodEstimate estimate;
  final double servings;
  final ValueChanged<double> onServings;

  @override
  Widget build(BuildContext context) {
    final total = estimate.total * servings;
    final confidenceColor = switch (estimate.confidence) {
      'alta' => AppColors.success,
      'baja' => AppColors.priorityHigh,
      _ => const Color(0xFFCA901F),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${total.calories.round()} kcal',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('Confianza ${estimate.confidence}',
                    style: TextStyle(color: confidenceColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          Text(
            'Proteína ${total.protein.round()} g · Carbs ${total.carbs.round()} g · Grasa ${total.fat.round()} g',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final i in estimate.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i.quantity.isEmpty ? i.name : '${i.name} · ${i.quantity}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text('${(i.nutrition.calories * servings).round()} kcal',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const Divider(height: 22),
          Row(
            children: [
              const Text('Porciones', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: servings > 0.5 ? () => onServings(servings - 0.5) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text(servings.toStringAsFixed(servings % 1 == 0 ? 0 : 1),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: servings < 10 ? () => onServings(servings + 0.5) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (estimate.notes.isNotEmpty)
            Text(estimate.notes, style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
          if (estimate.imageWarning != null) ...[
            const SizedBox(height: 6),
            Text(estimate.imageWarning!, style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Selector de comida del día (desayuno, comida, cena, colación).
class MealPicker extends StatelessWidget {
  const MealPicker({super.key, required this.value, required this.onChanged, required this.labels, required this.icons});
  final String value;
  final ValueChanged<String> onChanged;
  final Map<String, String> labels;
  final Map<String, IconData> icons;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in labels.entries)
          ChoiceChip(
            avatar: Icon(icons[e.key], size: 18, color: value == e.key ? Colors.white : ModuleTint.amber.foreground),
            label: Text(e.value),
            selected: value == e.key,
            showCheckmark: false,
            selectedColor: ModuleTint.amber.foreground,
            backgroundColor: ModuleTint.amber.background,
            side: BorderSide.none,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: value == e.key ? Colors.white : AppColors.inkSoft),
            onSelected: (_) => onChanged(e.key),
          ),
      ],
    );
  }
}
