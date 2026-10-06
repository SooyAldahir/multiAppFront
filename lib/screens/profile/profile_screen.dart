import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../health/health_profile_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'security_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// "29 años · Monterrey"
  static String _details(User? user) {
    if (user == null) return '';
    return [
      if (user.age != null) '${user.age} años',
      if ((user.city ?? '').isNotEmpty) user.city!,
      if ((user.phone ?? '').isNotEmpty) user.phone!,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const TopBar(eyebrow: 'Tu cuenta', title: 'Perfil'),
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: InkWell(
            onTap: () => _open(context, const EditProfileScreen()),
            child: Row(
              children: [
                Avatar(initials: user?.initials ?? '?', imageUrl: user?.avatarUrl, size: 64, showStatus: false),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      if (_details(user).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_details(user), style: const TextStyle(color: AppColors.mutedLight, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, color: AppColors.mutedLight, size: 20),
              ],
            ),
          ),
        ),
        if ((user?.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(user!.bio!, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.35)),
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: 'Cuenta'),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Datos personales'),
                subtitle: const Text('Foto, nombre, teléfono, cumpleaños, ciudad', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, const EditProfileScreen()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Notificaciones'),
                subtitle: const Text('Recordatorios y resumen del día', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, const NotificationSettingsScreen()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Cuenta y seguridad'),
                subtitle: const Text('Contraseña, correo y eliminar cuenta', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, const SecurityScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Salud'),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Perfil de salud'),
            subtitle: const Text('Peso, estatura, objetivo y nivel de entrenamiento', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final health = await context.read<HealthRepository>().get().catchError((_) => const HealthData());
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HealthProfileScreen(initial: health.profile)),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Acerca de'),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Versión'),
                trailing: Text('1.0.0', style: TextStyle(color: AppColors.muted)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Servidor'),
                subtitle: Text(AppConfig.apiUrl, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await confirm(
              context,
              title: 'Cerrar sesión',
              message: '¿Seguro que quieres salir de tu cuenta?',
              action: 'Cerrar sesión',
            );
            if (ok && context.mounted) await context.read<AuthController>().signOut();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.priorityHigh,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
