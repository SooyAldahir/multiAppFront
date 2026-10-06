import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';

/// Contraseña, correo y eliminación de la cuenta.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthController, String>((a) => a.user?.email ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta y seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const _ChangePasswordScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: const Text('Cambiar correo'),
                  subtitle: Text(email, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const _ChangeEmailScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Zona de peligro'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: AppColors.priorityHigh),
              title: const Text('Eliminar mi cuenta', style: TextStyle(color: AppColors.priorityHigh, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                'Borra para siempre tu agenda, notas, pendientes, gastos, recetas y todo lo demás.',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _deleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _deleteAccount(BuildContext context) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || !context.mounted) return;

    final repo = context.read<ProfileRepository>();
    final auth = context.read<AuthController>();
    try {
      // Primero se da de baja el push (después ya no habría sesión para hacerlo).
      await PushService.instance.stop(repo);
      await repo.deleteAccount(password);
      await NotificationService.instance.cancelScheduled();
      NotificationService.instance.stop();
      await auth.clearSession();
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
      // Si la contraseña era incorrecta, el teléfono se vuelve a registrar para push.
      await PushService.instance.start(repo);
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _understood && _password.text.isNotEmpty;
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Esta acción no se puede deshacer. Se borrarán todos tus datos de multiApp.'),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Tu contraseña'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _understood,
            onChanged: (v) => setState(() => _understood = v ?? false),
            title: const Text('Entiendo que perderé todo', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: canDelete ? () => Navigator.pop(context, _password.text) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.priorityHigh),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}

/* ---------------- Cambiar contraseña ---------------- */

class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen();

  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _show = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_current.text.isEmpty) {
      showMessage(context, 'Escribe tu contraseña actual', error: true);
      return;
    }
    if (_next.text.length < 8) {
      showMessage(context, 'La nueva contraseña debe tener al menos 8 caracteres', error: true);
      return;
    }
    if (_next.text != _confirm.text) {
      showMessage(context, 'Las contraseñas nuevas no coinciden', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ProfileRepository>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      showMessage(context, 'Contraseña actualizada');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => setState(() => _show = !_show),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _current,
            obscureText: !_show,
            decoration: InputDecoration(labelText: 'Contraseña actual', suffixIcon: toggle),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _next,
            obscureText: !_show,
            decoration: const InputDecoration(labelText: 'Nueva contraseña', helperText: 'Mínimo 8 caracteres'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirm,
            obscureText: !_show,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(labelText: 'Confirma la nueva contraseña'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Cambiar correo ---------------- */

class _ChangeEmailScreen extends StatefulWidget {
  const _ChangeEmailScreen();

  @override
  State<_ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<_ChangeEmailScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showMessage(context, 'Escribe un correo válido', error: true);
      return;
    }
    if (_password.text.isEmpty) {
      showMessage(context, 'Confirma con tu contraseña', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final session = await context.read<ProfileRepository>().changeEmail(email, _password.text);
      if (!mounted) return;
      await context.read<AuthController>().applySession(session);
      if (!mounted) return;
      showMessage(context, 'Correo actualizado');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.select<AuthController, String>((a) => a.user?.email ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar correo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Correo actual: $current', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Nuevo correo'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(labelText: 'Tu contraseña'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
