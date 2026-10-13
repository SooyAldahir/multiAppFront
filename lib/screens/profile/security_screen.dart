import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/ai_consent.dart';
import '../../services/auth_controller.dart';
import '../../services/biometric_service.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/repositories.dart';
import '../../services/social_sign_in.dart';
import '../../widgets/common.dart';
import '../auth/auth_widgets.dart';

/// Contraseña, correo, biometría, permisos y eliminación de la cuenta.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _bio = BiometricService.instance;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  String _bioLabel = 'Face ID';
  bool _aiGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = context.read<AuthController>().user?.email.toLowerCase();
    final available = await _bio.isAvailable();
    final label = await _bio.label();
    final enabled = await _bio.isEnabled() && await _bio.savedEmail() == email;
    final ai = await AiConsent.granted();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioLabel = label;
      _bioEnabled = enabled;
      _aiGranted = ai;
    });
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (!on) {
      await _bio.disable();
      if (mounted) setState(() => _bioEnabled = false);
      return;
    }
    final user = context.read<AuthController>().user!;
    final repo = context.read<ProfileRepository>();
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _PasswordPrompt(
        title: 'Activar $_bioLabel',
        message: 'Escribe tu contraseña para guardarla cifrada en este teléfono.',
        email: user.email,
      ),
    );
    if (password == null || !mounted) return;
    try {
      await repo.verifyPassword(user.email, password);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.isUnauthorized ? 'La contraseña no es correcta' : e.message, error: true);
      return;
    }
    if (!await _bio.authenticate('Confirma para activar $_bioLabel en MultiApp')) return;
    await _bio.save(user.email, password);
    if (mounted) setState(() => _bioEnabled = true);
  }

  Future<void> _revokeAi() async {
    await AiConsent.revoke();
    if (!mounted) return;
    setState(() => _aiGranted = false);
    showMessage(context, 'Listo. Te pediremos permiso la próxima vez que uses la IA.');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final email = user?.email ?? '';
    final hasPassword = user?.hasPassword ?? true;
    final providers = user?.providers ?? const <String>[];
    String providerName(String p) => p == 'apple' ? 'Apple' : 'Google';

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
                  title: Text(hasPassword ? 'Cambiar contraseña' : 'Crear contraseña'),
                  subtitle: hasPassword
                      ? null
                      : const Text('Para entrar también con tu correo', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, _ChangePasswordScreen(hasPassword: hasPassword)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: const Text('Cambiar correo'),
                  subtitle: Text(email, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: hasPassword
                      ? () => _push(context, const _ChangeEmailScreen())
                      : () => showMessage(context, 'Primero crea una contraseña para poder cambiar tu correo'),
                ),
                if (providers.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(providers.contains('apple') ? Icons.apple : Icons.account_circle_outlined),
                    title: const Text('Cuentas vinculadas'),
                    subtitle: Text(providers.map(providerName).join(' · '), style: const TextStyle(fontSize: 12)),
                  ),
                ],
                if (_bioAvailable && hasPassword) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(
                      _bioLabel.contains('Face') || _bioLabel.contains('facial')
                          ? Icons.face_retouching_natural
                          : Icons.fingerprint,
                    ),
                    title: Text('Entrar con $_bioLabel'),
                    subtitle: const Text('Guarda tu acceso cifrado en este teléfono', style: TextStyle(fontSize: 12)),
                    value: _bioEnabled,
                    onChanged: _toggleBiometrics,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Privacidad'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Permiso para la IA'),
                  subtitle: Text(
                    _aiGranted ? 'Permitido · toca para retirarlo' : 'Se pedirá al usar una función con IA',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: _aiGranted ? _revokeAi : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Aviso de privacidad'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => openLink(context, AppConfig.privacyUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Términos y condiciones'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => openLink(context, AppConfig.termsUrl),
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
              title: const Text('Eliminar mi cuenta',
                  style: TextStyle(color: AppColors.priorityHigh, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                'Borra para siempre tu agenda, notas, pendientes, gastos, recetas y todo lo demás.',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _deleteAccount(context, user),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _deleteAccount(BuildContext context, User? user) async {
    if (user == null) return;
    final hasPassword = user.hasPassword;
    final provider = user.providers.contains('apple') && SocialSignIn.appleAvailable
        ? 'apple'
        : (user.providers.isNotEmpty ? user.providers.first : 'google');
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteAccountDialog(
        needsPassword: hasPassword,
        providerName: provider == 'apple' ? 'Apple' : 'Google',
      ),
    );
    if (password == null || !context.mounted) return;

    final repo = context.read<ProfileRepository>();
    final auth = context.read<AuthController>();

    // Sin contraseña: se confirma la identidad volviendo a entrar con Google/Apple.
    SocialCredential? credential;
    if (!hasPassword) {
      try {
        credential = await SocialSignIn.withProvider(provider);
      } on SocialSignInCanceled {
        return;
      } on SocialSignInException catch (e) {
        if (context.mounted) showMessage(context, e.message, error: true);
        return;
      }
      if (!context.mounted) return;
    }

    try {
      // Primero se da de baja el push (después ya no habría sesión para hacerlo).
      await PushService.instance.stop(repo);
      if (credential != null) {
        await repo.deleteAccountWithProvider(credential.provider, credential.idToken);
      } else {
        await repo.deleteAccount(password);
      }
      await NotificationService.instance.cancelScheduled();
      NotificationService.instance.stop();
      await BiometricService.instance.disable();
      await AiConsent.revoke();
      await SocialSignIn.signOutGoogle(disconnect: true);
      await auth.clearSession();
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
      // Si la confirmación falló, el teléfono se vuelve a registrar para push.
      await PushService.instance.start(repo);
    }
  }
}

/// Pide la contraseña (con autocompletado del Llavero).
class _PasswordPrompt extends StatefulWidget {
  const _PasswordPrompt({required this.title, required this.message, required this.email});
  final String title;
  final String message;
  final String email;

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => v.isEmpty ? null : Navigator.pop(context, v),
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _password.text.isEmpty ? null : () => Navigator.pop(context, _password.text),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.needsPassword, required this.providerName});
  final bool needsPassword;
  final String providerName;

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
    final canDelete = _understood && (!widget.needsPassword || _password.text.isNotEmpty);
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta acción no se puede deshacer. Se borrarán de inmediato todos tus datos de MultiApp.'),
            const SizedBox(height: 16),
            if (widget.needsPassword)
              TextField(
                controller: _password,
                obscureText: true,
                autofocus: true,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Tu contraseña'),
              )
            else
              Text(
                'Para confirmar que eres tú, te pediremos entrar de nuevo con ${widget.providerName}.',
                style: const TextStyle(color: AppColors.muted),
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
  const _ChangePasswordScreen({this.hasPassword = true});
  final bool hasPassword;

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
    if (widget.hasPassword && _current.text.isEmpty) {
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
      final repo = context.read<ProfileRepository>();
      final auth = context.read<AuthController>();
      await repo.changePassword(widget.hasPassword ? _current.text : null, _next.text);
      // Mantiene al día el acceso con Face ID / huella y el dato "tiene contraseña".
      final email = auth.user?.email;
      if (email != null) await BiometricService.instance.updatePassword(email, _next.text);
      if (!widget.hasPassword) await auth.setUser(await repo.me());
      if (!mounted) return;
      showMessage(context, widget.hasPassword ? 'Contraseña actualizada' : 'Contraseña creada');
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
      appBar: AppBar(title: Text(widget.hasPassword ? 'Cambiar contraseña' : 'Crear contraseña')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (widget.hasPassword) ...[
            TextField(
              controller: _current,
              obscureText: !_show,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: 'Contraseña actual', suffixIcon: toggle),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _next,
            obscureText: !_show,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              helperText: 'Mínimo 8 caracteres',
              suffixIcon: widget.hasPassword ? null : toggle,
            ),
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
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
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
      final bio = BiometricService.instance;
      if (await bio.isEnabled()) await bio.save(email, _password.text);
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
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
