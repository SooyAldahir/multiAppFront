import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../screens/auth/auth_widgets.dart';

/// Navegador de la app, para mostrar el permiso de IA desde cualquier pantalla.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Permiso para enviar datos a la IA (Apple 5.1.2(i): avisar y pedir permiso antes de compartir
/// datos personales con una IA de terceros). Se pregunta una vez por cuenta y por teléfono.
class AiConsent {
  AiConsent._();

  static const _storage = FlutterSecureStorage();
  static const _version = 'v1';

  static int? userId;
  static bool? _cached;
  static Future<bool>? _asking;

  static String get _key => 'ai_consent_${_version}_${userId ?? 0}';

  static Future<bool> granted() async {
    if (_cached != null) return _cached!;
    try {
      _cached = await _storage.read(key: _key) == 'yes';
    } catch (_) {
      _cached = false;
    }
    return _cached!;
  }

  static Future<void> revoke() async {
    _cached = false;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }

  static void forUser(int? id) {
    userId = id;
    _cached = null;
  }

  /// Se engancha en ApiClient.ensureAiConsent: lanza ApiException si la persona no acepta.
  static Future<void> ensure() async {
    if (await granted()) return;
    final ok = await (_asking ??= _ask().whenComplete(() => _asking = null));
    if (!ok) {
      throw ApiException('Para usar las funciones de inteligencia artificial necesitas darnos permiso.');
    }
  }

  static Future<bool> _ask() async {
    final context = appNavigatorKey.currentContext;
    if (context == null) return false;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 36),
        title: const Text('Funciones con inteligencia artificial'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para generar recetas, rutinas, calcular calorías, ordenar tu lista de compras y darte consejos '
                'de presupuesto, MultiApp envía lo que escribas (o la foto de tu comida) y los datos necesarios '
                '—por ejemplo tu perfil de ejercicio o tus gastos del periodo— a Groq, un servicio de IA en '
                'Estados Unidos.',
              ),
              const SizedBox(height: 10),
              const Text(
                'No enviamos tu nombre ni tu correo, y las fotos de comida no se guardan. '
                'Los resultados son aproximados y no sustituyen la opinión de un profesional.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openLink(context, '${AppConfig.privacyUrl}#encargados'),
                child: const Text('Leer el Aviso de privacidad'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, gracias')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Permitir')),
        ],
      ),
    );
    if (yes == true) {
      _cached = true;
      try {
        await _storage.write(key: _key, value: 'yes');
      } catch (_) {}
      return true;
    }
    return false;
  }
}
