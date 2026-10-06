import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// Tarjeta de evento con el cuadro de fecha a la izquierda (mockup: "Today").
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.onTap, this.onMore});
  final AgendaEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final tint = ModuleTint.byName(event.color);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 58,
            decoration: BoxDecoration(color: tint.background, borderRadius: BorderRadius.circular(15)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${event.startAt.day}',
                  style: TextStyle(color: tint.foreground, fontSize: 20, fontWeight: FontWeight.w800, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  Fmt.monthShort(event.startAt).toUpperCase(),
                  style: TextStyle(color: tint.foreground, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.allDay ? 'Todo el día' : Fmt.timeRange(event.startAt, event.endAt),
                  style: TextStyle(color: tint.foreground.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if ((event.location ?? '').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF9998A2), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onMore != null)
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz_rounded, color: AppColors.mutedLight),
            ),
        ],
      ),
    );
  }
}

/// Fila de tarea con casilla, subtítulo y etiqueta de prioridad.
class TodoTile extends StatelessWidget {
  const TodoTile({super.key, required this.todo, required this.onToggle, this.onTap, this.subtitlePrefix});
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final String? subtitlePrefix;

  @override
  Widget build(BuildContext context) {
    final due = todo.dueDate == null ? 'Sin fecha' : 'Vence ${Fmt.relativeDay(todo.dueDate!).toLowerCase()}';
    final subtitle = subtitlePrefix == null ? due : '$subtitlePrefix · $due';
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          _CheckBox(checked: todo.isCompleted, priority: todo.priority, onTap: onToggle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: todo.isCompleted ? AppColors.mutedLight : AppColors.ink,
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: todo.isOverdue ? AppColors.priorityHigh : AppColors.mutedLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!todo.isCompleted) PriorityChip(priority: todo.priority),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked, required this.priority, required this.onTap});
  final bool checked;
  final Priority priority;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      Priority.high => const Color(0xFFEE9388),
      Priority.medium => const Color(0xFFE5B95C),
      Priority.low => const Color(0xFFB7B5C0),
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: checked ? AppColors.primary : color, width: 1.6),
          ),
          child: checked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
        ),
      ),
    );
  }
}

class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.priority});
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (priority) {
      Priority.high => (AppColors.priorityHighBg, AppColors.priorityHigh),
      Priority.medium => (const Color(0xFFFFF4D9), const Color(0xFFB07D16)),
      Priority.low => (AppColors.chip, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(priority.label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
