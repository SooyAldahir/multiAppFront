import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../services/biometric_service.dart';
import '../../services/social_sign_in.dart';
import '../../widgets/common.dart';

/// Abre una página (aviso de privacidad, términos…) en el navegador dentro de la app.
Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  if (!ok && context.mounted) showMessage(context, 'No se pudo abrir $url', error: true);
}

/// "Al continuar aceptas los Términos y el Aviso de privacidad" con enlaces.
class LegalNotice extends StatelessWidget {
  const LegalNotice({super.key, this.prefix = 'Al continuar aceptas los '});
  final String prefix;

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        children: [
          TextSpan(text: prefix),
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
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Botones "Continuar con Apple" (solo iPhone) y "Continuar con Google".
class SocialButtons extends StatefulWidget {
  const SocialButtons({super.key});

  static bool get anyAvailable => SocialSignIn.appleAvailable || SocialSignIn.googleAvailable;

  @override
  State<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends State<SocialButtons> {
  String? _busy;

  Future<void> _go(String provider) async {
    setState(() => _busy = provider);
    try {
      final credential = await SocialSignIn.withProvider(provider);
      if (!mounted) return;
      await context.read<AuthController>().loginWithSocial(credential);
    } on SocialSignInCanceled {
      // El usuario cerró la ventana.
    } on SocialSignInException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo iniciar sesión: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SocialButtons.anyAvailable) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('o', style: TextStyle(color: AppColors.muted)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        if (SocialSignIn.appleAvailable)
          _ProviderButton(
            label: 'Continuar con Apple',
            icon: const Icon(Icons.apple, color: Colors.white, size: 24),
            background: Colors.black,
            foreground: Colors.white,
            busy: _busy == 'apple',
            onPressed: _busy == null ? () => _go('apple') : null,
          ),
        if (SocialSignIn.appleAvailable && SocialSignIn.googleAvailable) const SizedBox(height: 10),
        if (SocialSignIn.googleAvailable)
          _ProviderButton(
            label: 'Continuar con Google',
            icon: const _GoogleMark(),
            background: Colors.white,
            foreground: const Color(0xFF1F1F1F),
            border: const Color(0xFF747775),
            busy: _busy == 'google',
            onPressed: _busy == null ? () => _go('google') : null,
          ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.busy,
    required this.onPressed,
    this.border,
  });

  final String label;
  final Widget icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.7),
          side: BorderSide(color: border ?? background),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: foreground)),
                ],
              ),
      ),
    );
  }
}

/// "G" multicolor de Google dibujada (sin imágenes externas).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GooglePainter()));
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.1415926535 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335))); // rojo (arriba)
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05))); // amarillo (izquierda)
    canvas.drawArc(rect, -230 * deg, -95 * deg, false, p(const Color(0xFF34A853))); // verde (abajo)
    canvas.drawArc(rect, -325 * deg, -35 * deg, false, p(const Color(0xFF4285F4))); // azul (derecha)
    final blue = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, size.height / 2 - stroke / 2, size.width / 2, stroke),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Después de entrar con correo y contraseña: ofrece guardar el acceso con Face ID / huella.
Future<void> offerBiometrics(BuildContext context, String email, String password) async {
  final bio = BiometricService.instance;
  if (!await bio.isAvailable()) return;
  final saved = await bio.savedEmail();
  if (await bio.isEnabled() && saved == email.trim().toLowerCase()) {
    await bio.save(email, password); // mantiene la contraseña al día
    return;
  }
  if (!context.mounted) return;
  final label = await bio.label();
  if (!context.mounted) return;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(label.contains('Face') || label.contains('facial') ? Icons.face_retouching_natural : Icons.fingerprint,
          size: 40, color: AppColors.primary),
      title: Text('¿Entrar con $label?'),
      content: Text(
        'Guardaremos tu correo y contraseña cifrados en este teléfono para que la próxima vez entres con $label. '
        'Puedes desactivarlo en Perfil → Cuenta y seguridad.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activar')),
      ],
    ),
  );
  if (yes != true) return;
  if (await bio.authenticate('Confirma para activar $label en MultiApp')) {
    await bio.save(email, password);
  }
}
