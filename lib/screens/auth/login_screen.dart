import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../services/biometric_service.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  /// Texto del botón de biometría ("Face ID", "huella"…) si está activada en este teléfono.
  String? _bioLabel;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final bio = BiometricService.instance;
    if (!await bio.isEnabled() || !await bio.isAvailable()) return;
    final label = await bio.label();
    final email = await bio.savedEmail();
    if (!mounted) return;
    setState(() {
      _bioLabel = label;
      if (_email.text.isEmpty && email != null) _email.text = email;
    });
  }

  Future<void> _loginWithBiometrics() async {
    final creds = await BiometricService.instance.unlock();
    if (creds == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().login(creds.email, creds.password);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        // La contraseña cambió en otro lado: se desactiva y se pide escribirla.
        await BiometricService.instance.disable();
        if (!mounted) return;
        setState(() => _bioLabel = null);
        showMessage(
          context,
          'Tu contraseña cambió. Escríbela de nuevo para volver a activar el acceso rápido.',
          error: true,
        );
      } else {
        showMessage(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final password = _password.text;
      await context.read<AuthController>().login(
        email,
        password,
        beforeEnter: () async {
          // Le dice al sistema que el inicio de sesión funcionó: iOS / Android ofrecen guardar
          // la contraseña en el Llavero / Gestor de contraseñas de Google.
          TextInput.finishAutofillContext();
          if (mounted) await offerBiometrics(context, email, password);
        },
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeader(
                        eyebrow: 'Bienvenido de vuelta',
                        title: 'Todo lo que necesitas,\na un toque.',
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Escribe un correo válido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Iniciar sesión'),
                      ),
                      if (_bioLabel != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loginWithBiometrics,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Icon(_bioLabel!.contains('Face') || _bioLabel!.contains('facial')
                              ? Icons.face_retouching_natural
                              : Icons.fingerprint),
                          label: Text('Entrar con $_bioLabel'),
                        ),
                      ],
                      const SocialButtons(),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('¿No tienes cuenta?', style: TextStyle(color: AppColors.muted)),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            ),
                            child: const Text('Crear cuenta'),
                          ),
                        ],
                      ),
                      if (SocialButtons.anyAvailable) ...[
                        const SizedBox(height: 4),
                        const LegalNotice(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de las pantallas de acceso con la tarjeta oscura del mockup.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.eyebrow, required this.title});
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [AppColors.orbStart, AppColors.orbEnd]),
            ),
            child: const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            eyebrow.toUpperCase(),
            style:
                const TextStyle(color: Color(0xFFB7ACFA), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agenda, notas, pendientes y más en una sola app.',
            style: TextStyle(color: Color(0xFFAAA7B1), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
