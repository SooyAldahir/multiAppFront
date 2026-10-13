import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/oauth_config.dart';

/// Resultado de iniciar sesión con Google o Apple: lo que se manda al servidor.
class SocialCredential {
  const SocialCredential({required this.provider, required this.idToken, this.authorizationCode, this.name});
  final String provider; // 'google' | 'apple'
  final String idToken;
  final String? authorizationCode;
  final String? name;

  Map<String, dynamic> toJson() => {
        'idToken': idToken,
        if (authorizationCode != null) 'authorizationCode': authorizationCode,
        if (name != null && name!.trim().isNotEmpty) 'name': name,
      };
}

/// El usuario cerró la ventana de Google/Apple: no es un error que haya que mostrar.
class SocialSignInCanceled implements Exception {}

class SocialSignInException implements Exception {
  SocialSignInException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SocialSignIn {
  SocialSignIn._();

  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Google está disponible cuando ya se configuraron los IDs de cliente (ver oauth_config.dart).
  static bool get googleAvailable =>
      OAuthConfig.googleServerClientId.isNotEmpty && (_android || (_ios && OAuthConfig.googleIosClientId.isNotEmpty));

  /// Sign in with Apple nativo: solo en iPhone/iPad.
  static bool get appleAvailable => _ios;

  static bool _googleReady = false;

  static Future<void> _initGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      clientId: _ios ? OAuthConfig.googleIosClientId : null,
      serverClientId: OAuthConfig.googleServerClientId,
    );
    _googleReady = true;
  }

  static Future<SocialCredential> google() async {
    try {
      await _initGoogle();
      // Se cierra la sesión anterior para que siempre deje elegir la cuenta.
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw SocialSignInException('Google no devolvió tu identificación. Intenta de nuevo.');
      return SocialCredential(provider: 'google', idToken: idToken, name: account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) {
        throw SocialSignInCanceled();
      }
      throw SocialSignInException('No se pudo entrar con Google (${e.code.name}).');
    }
  }

  static Future<SocialCredential> apple() async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final token = c.identityToken;
      if (token == null) throw SocialSignInException('Apple no devolvió tu identificación. Intenta de nuevo.');
      final name = [c.givenName, c.familyName].where((p) => p != null && p.trim().isNotEmpty).join(' ');
      return SocialCredential(
        provider: 'apple',
        idToken: token,
        authorizationCode: c.authorizationCode,
        name: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw SocialSignInCanceled();
      throw SocialSignInException('No se pudo entrar con Apple (${e.code.name}).');
    }
  }

  static Future<SocialCredential> withProvider(String provider) => provider == 'apple' ? apple() : google();

  /// Olvida la cuenta de Google en este teléfono (al cerrar sesión o eliminar la cuenta).
  static Future<void> signOutGoogle({bool disconnect = false}) async {
    if (!googleAvailable) return;
    try {
      await _initGoogle();
      disconnect ? await GoogleSignIn.instance.disconnect() : await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
