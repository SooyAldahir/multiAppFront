#!/usr/bin/env python3
"""
Configura "Continuar con Google" a partir de los archivos de Firebase.

Antes:
  1. Firebase Console → Authentication → Sign-in method → Google → Habilitar → Guardar.
  2. Firebase Console → Configuración del proyecto → app Android → agrega la huella SHA-1
     (debug: `cd android && ./gradlew signingReport`; la de Play: Play Console → Integridad de la app).
  3. Vuelve a descargar google-services.json (android/app/) y GoogleService-Info.plist (ios/Runner/).

Luego, desde multiAppFront:
  python3 tool/setup_google_sign_in.py

Hace tres cosas:
  - escribe los IDs en lib/core/oauth_config.dart
  - agrega el URL scheme (REVERSED_CLIENT_ID) a ios/Runner/Info.plist
  - imprime el valor de GOOGLE_CLIENT_IDS para el servidor (Render → Environment)
"""
import json
import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GS_JSON = ROOT / 'android/app/google-services.json'
GS_PLIST = ROOT / 'ios/Runner/GoogleService-Info.plist'
INFO_PLIST = ROOT / 'ios/Runner/Info.plist'
OUT = ROOT / 'lib/core/oauth_config.dart'


def fail(msg):
    print(f'✖ {msg}')
    sys.exit(1)


data = json.loads(GS_JSON.read_text())
web_ids = {
    o['client_id']
    for c in data.get('client', [])
    for o in c.get('oauth_client', []) + c.get('services', {}).get('appinvite_service', {}).get('other_platform_oauth_client', [])
    if o.get('client_type') == 3
}
android_ok = any(o.get('client_type') == 1 for c in data.get('client', []) for o in c.get('oauth_client', []))
if not web_ids:
    fail('google-services.json no trae el "Web client ID". Habilita Google en Firebase Authentication y vuelve a descargarlo.')
web_id = sorted(web_ids)[0]

plist = plistlib.loads(GS_PLIST.read_bytes())
ios_id = plist.get('CLIENT_ID')
reversed_id = plist.get('REVERSED_CLIENT_ID')
if not ios_id or not reversed_id:
    fail('GoogleService-Info.plist no trae CLIENT_ID / REVERSED_CLIENT_ID. Vuelve a descargarlo después de habilitar Google.')

OUT.write_text(f'''/// IDs de cliente de Google Sign-In (no son secretos).
///
/// Generado por `python3 tool/setup_google_sign_in.py` a partir de los archivos de Firebase.
class OAuthConfig {{
  OAuthConfig._();

  /// "Web client ID" (client_type 3). El servidor verifica que el token venga para este ID.
  static const String googleServerClientId = '{web_id}';

  /// CLIENT_ID de GoogleService-Info.plist (solo iOS).
  static const String googleIosClientId = '{ios_id}';
}}
''')

info = plistlib.loads(INFO_PLIST.read_bytes())
types = info.setdefault('CFBundleURLTypes', [])
if not any(reversed_id in t.get('CFBundleURLSchemes', []) for t in types):
    types.append({'CFBundleTypeRole': 'Editor', 'CFBundleURLSchemes': [reversed_id]})
INFO_PLIST.write_bytes(plistlib.dumps(info))

print('✔ lib/core/oauth_config.dart actualizado')
print('✔ URL scheme de Google agregado a ios/Runner/Info.plist')
if not android_ok:
    print('⚠ google-services.json no trae cliente Android: agrega la huella SHA-1 en Firebase y vuelve a descargarlo.')
print()
print('En Render → multiapp-api → Environment pon:')
print(f'  GOOGLE_CLIENT_IDS = {web_id},{ios_id}')
