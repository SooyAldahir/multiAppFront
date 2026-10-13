/// IDs de cliente de Google Sign-In (no son secretos).
///
/// Generado por `python3 tool/setup_google_sign_in.py` a partir de los archivos de Firebase.
class OAuthConfig {
  OAuthConfig._();

  /// "Web client ID" (client_type 3). El servidor verifica que el token venga para este ID.
  static const String googleServerClientId = '300205154711-pbi7n94pt0o1kgkh3i9krudtaj0740l0.apps.googleusercontent.com';

  /// CLIENT_ID de GoogleService-Info.plist (solo iOS).
  static const String googleIosClientId = '300205154711-b00hct7p4mauho50ueqsb2brq4ocp4i7.apps.googleusercontent.com';
}
