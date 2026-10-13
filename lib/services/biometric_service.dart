import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Correo y contraseña guardados en el Llavero (iOS) / Keystore (Android).
class SavedCredentials {
  const SavedCredentials(this.email, this.password);
  final String email;
  final String password;
}

/// Entrar con Face ID / Touch ID / huella.
///
/// Al activarlo, el correo y la contraseña se guardan cifrados en el almacenamiento seguro del
/// teléfono (Llavero de iOS, solo en este dispositivo y con el teléfono desbloqueado; Keystore en
/// Android). Para leerlos, la app pide antes la biometría.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
  );
  static const _emailKey = 'bio_email';
  static const _passwordKey = 'bio_password';

  /// true si el teléfono tiene biometría configurada.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// "Face ID", "Touch ID" o "huella", para los textos.
  Future<String> label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      if (types.contains(BiometricType.face)) return ios ? 'Face ID' : 'reconocimiento facial';
      if (types.contains(BiometricType.fingerprint)) return ios ? 'Touch ID' : 'huella';
    } catch (_) {}
    return defaultTargetPlatform == TargetPlatform.iOS ? 'Face ID' : 'huella';
  }

  /// Muestra el diálogo del sistema. Devuelve false si se cancela o falla.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: false, persistAcrossBackgrounding: true);
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    try {
      return await _storage.containsKey(key: _passwordKey);
    } catch (_) {
      return false;
    }
  }

  Future<String?> savedEmail() async {
    try {
      return await _storage.read(key: _emailKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String email, String password) async {
    await _storage.write(key: _emailKey, value: email.trim().toLowerCase());
    await _storage.write(key: _passwordKey, value: password);
  }

  /// Pide la biometría y devuelve las credenciales guardadas (null si se cancela).
  Future<SavedCredentials?> unlock() async {
    final email = await savedEmail();
    if (email == null) return null;
    final label = await this.label();
    final ok = await authenticate('Usa $label para entrar a MultiApp');
    if (!ok) return null;
    final password = await _storage.read(key: _passwordKey);
    if (password == null) return null;
    return SavedCredentials(email, password);
  }

  /// Actualiza la contraseña guardada (al cambiarla) si la biometría está activa para ese correo.
  Future<void> updatePassword(String email, String password) async {
    if (await isEnabled() && (await savedEmail()) == email.trim().toLowerCase()) {
      await save(email, password);
    }
  }

  Future<void> disable() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {}
  }
}
