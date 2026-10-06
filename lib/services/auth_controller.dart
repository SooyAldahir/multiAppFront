import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import '../models/models.dart';

enum AuthStatus { loading, signedOut, signedIn }

/// Maneja la sesión: registro, inicio/cierre de sesión y token guardado de forma segura.
class AuthController extends ChangeNotifier {
  AuthController(this._api, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _api.onUnauthorized = () => signOut();
  }

  static const _tokenKey = 'multiapp_token';
  static const _userKey = 'multiapp_user';

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  AuthStatus status = AuthStatus.loading;
  User? user;

  /// Se ejecuta antes de cerrar sesión (con el token aún válido), p. ej. para dar de baja el push.
  Future<void> Function()? beforeSignOut;

  /// Restaura la sesión guardada al abrir la app.
  Future<void> restore() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final userJson = await _storage.read(key: _userKey);
      if (token != null && userJson != null) {
        _api.token = token;
        user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        status = AuthStatus.signedIn;
        notifyListeners();
        // Verifica en segundo plano que el token siga vigente.
        _refreshUser();
        return;
      }
    } catch (_) {
      // Si el almacenamiento falla, se pide iniciar sesión de nuevo.
    }
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _refreshUser() async {
    try {
      final data = await _api.get('/users/me') as Map<String, dynamic>;
      await setUser(User.fromJson(data));
    } on ApiException catch (e) {
      if (e.isUnauthorized) await signOut();
    }
  }

  /// Actualiza el usuario en memoria y en el almacenamiento (después de editar el perfil).
  Future<void> setUser(User updated) async {
    user = updated;
    await _storage.write(key: _userKey, value: jsonEncode(updated.toJson()));
    notifyListeners();
  }

  /// Guarda una sesión nueva devuelta por el servidor (ej. al cambiar el correo).
  Future<void> applySession(Map<String, dynamic> data) => _saveSession(data);

  /// Cierra la sesión localmente sin llamar al servidor (ej. después de eliminar la cuenta).
  Future<void> clearSession() async {
    _api.token = null;
    user = null;
    status = AuthStatus.signedOut;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post('/auth/login', {'email': email, 'password': password});
    await _saveSession(data as Map<String, dynamic>);
  }

  Future<void> register(String name, String email, String password) async {
    final data = await _api.post('/auth/register', {'name': name, 'email': email, 'password': password});
    await _saveSession(data as Map<String, dynamic>);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    user = User.fromJson(data['user'] as Map<String, dynamic>);
    _api.token = token;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user!.toJson()));
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  bool _signingOut = false;

  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      if (_api.token != null && beforeSignOut != null) {
        await beforeSignOut!().timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // No debe impedir cerrar sesión.
    } finally {
      _signingOut = false;
    }
    await clearSession();
  }
}
