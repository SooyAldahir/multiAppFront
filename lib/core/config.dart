import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Configuración de la app.
///
/// Por defecto la app usa el servidor en internet (Render), también al emular.
/// Para probar contra el backend en tu computadora:
///   flutter run --dart-define=LOCAL_API=true
/// O con una URL concreta (p. ej. tu teléfono contra la IP de tu Mac):
///   flutter run --dart-define=API_URL=http://192.168.1.50:3000/api
class AppConfig {
  AppConfig._();

  static const String _fromEnv = String.fromEnvironment('API_URL');
  static const bool _useLocal = bool.fromEnvironment('LOCAL_API');

  /// Servidor en producción (Render). Si Render le dio otro nombre a tu servicio, cámbialo aquí.
  static const String productionUrl = 'https://multiapp-api.onrender.com/api';

  static String get apiUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    // El backend local solo en depuración y si se pide explícitamente.
    if (_useLocal && !kReleaseMode) {
      // Emulador Android: 10.0.2.2 apunta al localhost de tu computadora.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000/api';
      return 'http://localhost:3000/api';
    }
    return productionUrl;
  }

  /// El servidor gratuito (Render + Azure SQL) puede tardar en "despertar" la primera vez.
  static const Duration requestTimeout = Duration(seconds: 45);

  /// La IA puede tardar más en responder.
  static const Duration aiTimeout = Duration(seconds: 60);

  /// Identificador que se envía a los servidores de mapas de OpenStreetMap.
  static const String packageName = 'com.aldahirballina.multiapp';

  /// Centro del mapa cuando aún no hay ubicación (centro de México).
  static const LatLng defaultMapCenter = LatLng(23.6345, -102.5528);
}
