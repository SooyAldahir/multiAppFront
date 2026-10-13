import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _accepted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      showMessage(context, 'Para crear tu cuenta acepta el Aviso de privacidad y los Términos', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final password = _password.text;
      await context.read<AuthController>().register(
        _name.text.trim(),
        email,
        password,
        beforeEnter: () async {
          TextInput.finishAutofillContext(); // ofrece guardar la contraseña en el Llavero
          if (mounted) await offerBiometrics(context, email, password);
        },
      );
      // Al registrarse, MultiApp cambia automáticamente a la pantalla principal.
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeader(eyebrow: 'Crea tu cuenta', title: 'Organiza tu día\nen un solo lugar.'),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration:
                            const InputDecoration(hintText: 'Nombre', prefixIcon: Icon(Icons.person_outline_rounded)),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Escribe tu nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            hintText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: (v) => (v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()))
                            ? 'Escribe un correo válido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          hintText: 'Contraseña (mínimo 8 caracteres)',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? 'Usa al menos 8 caracteres' : null,
                      ),
                      const SizedBox(height: 16),
                      _ConsentBox(value: _accepted, onChanged: (v) => setState(() => _accepted = v)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Crear cuenta'),
                      ),
                      const SocialButtons(),
                      if (SocialButtons.anyAvailable) ...[
                        const SizedBox(height: 12),
                        const LegalNotice(prefix: 'Con Google o Apple también aceptas los '),
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

/// Aviso de privacidad simplificado + consentimiento expreso (incluye datos de salud, que son sensibles).
class _ConsentBox extends StatelessWidget {
  const _ConsentBox({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                  children: [
                    const TextSpan(text: 'Acepto los '),
                    TextSpan(
                      text: 'Términos y condiciones',
                      style: link,
                      recognizer: TapGestureRecognizer()..onTap = () => openLink(context, AppConfig.termsUrl),
                    ),
                    const TextSpan(text: ' y el '),
                    TextSpan(
                      text: 'Aviso de privacidad',
                      style: link,
                      recognizer: TapGestureRecognizer()..onTap = () => openLink(context, AppConfig.privacyUrl),
                    ),
                    const TextSpan(
                      text: ', y consiento que MultiApp trate los datos de salud y bienestar que yo decida registrar '
                          '(peso, ejercicio, comidas) para darme sus funciones.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
