import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Ícono cuadrado redondeado de un módulo (con insignia opcional), como en el mockup.
class ModuleIcon extends StatelessWidget {
  const ModuleIcon({super.key, required this.icon, required this.tint, this.large = false, this.badge});

  final IconData icon;
  final ModuleTint tint;
  final bool large;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final size = large ? 58.0 : 44.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tint.background,
            borderRadius: BorderRadius.circular(large ? 18 : 14),
            boxShadow: large ? const [BoxShadow(color: Color(0x122A273B), blurRadius: 15, offset: Offset(0, 7))] : null,
          ),
          child: Icon(icon, color: tint.foreground, size: large ? 27 : 23),
        ),
        if (badge != null)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 21),
              height: 21,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Text(
                badge!,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

/// Encabezado de cada pestaña: texto pequeño en mayúsculas + título grande + acciones.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.eyebrow,
    required this.title,
    this.initials,
    this.avatarUrl,
    this.onSearch,
    this.onProfile,
  });

  final String eyebrow;
  final String title;
  final String? initials;
  final String? avatarUrl;
  final VoidCallback? onSearch;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
              ],
            ),
          ),
          if (onSearch != null) ...[
            _SquareButton(onTap: onSearch!, child: const Icon(Icons.search_rounded, size: 21, color: AppColors.ink)),
            const SizedBox(width: 8),
          ],
          if (initials != null) Avatar(initials: initials!, imageUrl: avatarUrl, onTap: onProfile),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0xFFE6E5E9)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Center(child: child)),
      ),
    );
  }
}

/// Avatar con foto (o iniciales si no hay) y punto verde de "en línea".
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.imageUrl, this.onTap, this.size = 42, this.showStatus = true});
  final String initials;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double size;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.31);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF383743), Color(0xFF74717F)],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontSize: size * 0.28, fontWeight: FontWeight.w800),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (imageUrl == null || imageUrl!.isEmpty)
            fallback
          else
            ClipRRect(
              borderRadius: radius,
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
              ),
            ),
          if (showStatus)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Título de sección con acción a la derecha ("Ver todo", "3 elementos").
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.trailing});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: AppColors.primaryText, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(color: AppColors.mutedLight, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Tarjeta oscura con degradado y brillo violeta (tarjeta de IA / automatizaciones).
class GlowCard extends StatelessWidget {
  const GlowCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.glowAlignment = Alignment.topRight, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Alignment glowAlignment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkCardStart, AppColors.darkCardEnd],
          ),
          boxShadow: const [BoxShadow(color: Color(0x2B272237), blurRadius: 28, offset: Offset(0, 14))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: glowAlignment,
                child: FractionalTranslation(
                  translation: Offset(glowAlignment.x * 0.25, glowAlignment.y * 0.35),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.glow.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta blanca con borde y sombra suave.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Tarjeta lila de sugerencia ("Tienes 2 h 30 min libres").
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.title, required this.subtitle, this.icon = Icons.auto_awesome, this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: AppColors.primaryBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF83808C), fontSize: 12)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío amigable.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Mensaje de error con botón para reintentar.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'No pudimos cargar la información',
      message: message,
      action: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
    );
  }
}

/// Muestra un mensaje breve en la parte inferior.
void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB3403A) : AppColors.ink,
    ));
}

/// Diálogo de confirmación (p. ej. antes de eliminar).
Future<bool> confirm(BuildContext context, {required String title, required String message, String action = 'Eliminar'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.priorityHigh),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
