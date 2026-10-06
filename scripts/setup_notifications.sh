#!/usr/bin/env bash
# Ajustes nativos para notificaciones (locales y push). Se puede ejecutar varias veces.
# Uso:  cd multiAppFront && bash scripts/setup_notifications.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_GRADLE=android/app/build.gradle.kts
SETTINGS_GRADLE=android/settings.gradle.kts
MANIFEST=android/app/src/main/AndroidManifest.xml
PLIST=ios/Runner/Info.plist
APPDELEGATE=ios/Runner/AppDelegate.swift

# ---------- Android: desugaring (lo pide flutter_local_notifications) ----------
if [ -f "$APP_GRADLE" ]; then
  if ! grep -q "isCoreLibraryDesugaringEnabled" "$APP_GRADLE"; then
    perl -0pi -e 's#compileOptions \{#compileOptions {\n        isCoreLibraryDesugaringEnabled = true#' "$APP_GRADLE"
    echo "✔ Desugaring activado en $APP_GRADLE"
  fi
  if ! grep -q "desugar_jdk_libs" "$APP_GRADLE"; then
    printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$APP_GRADLE"
    echo "✔ Dependencia desugar_jdk_libs agregada"
  fi
fi

# ---------- Android: permisos y receptores ----------
if [ -f "$MANIFEST" ]; then
  if ! grep -q "POST_NOTIFICATIONS" "$MANIFEST"; then
    perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>#' "$MANIFEST"
    echo "✔ Permisos de notificaciones agregados a Android"
  fi
  if ! grep -q "ScheduledNotificationReceiver" "$MANIFEST"; then
    perl -0pi -e 's#(\s*</application>)#
        <!-- Recordatorios programados (flutter_local_notifications) -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <!-- Canal para los push de Firebase -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="multiapp_general" />$1#' "$MANIFEST"
    echo "✔ Receptores de recordatorios agregados al AndroidManifest"
  fi
fi

# ---------- iOS: mostrar avisos con la app abierta + push en segundo plano ----------
if [ -f "$APPDELEGATE" ] && ! grep -q "UNUserNotificationCenter" "$APPDELEGATE"; then
  perl -0pi -e 's#(    GeneratedPluginRegistrant\.register\(with: self\))#    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate\n$1#' "$APPDELEGATE"
  perl -0pi -e 's#import UIKit#import UIKit\nimport UserNotifications#' "$APPDELEGATE"
  echo "✔ AppDelegate de iOS listo para notificaciones"
fi

if [ -f "$PLIST" ] && command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  if ! grep -q "remote-notification" "$PLIST"; then
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string remote-notification" "$PLIST"
    echo "✔ Modo en segundo plano 'remote-notification' agregado a iOS"
  fi
  # La cámara y las fotos ahora también se usan para la foto de perfil.
  /usr/libexec/PlistBuddy -c "Set :NSCameraUsageDescription 'multiApp usa la cámara para tu foto de perfil y para calcular las calorías de tu comida.'" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :NSPhotoLibraryUsageDescription 'multiApp usa tus fotos para tu foto de perfil y para calcular las calorías de un platillo.'" "$PLIST" 2>/dev/null || true
fi

# ---------- Firebase (solo si ya descargaste google-services.json) ----------
if [ -f android/app/google-services.json ]; then
  if [ -f "$SETTINGS_GRADLE" ] && ! grep -q "com.google.gms.google-services" "$SETTINGS_GRADLE"; then
    perl -0pi -e 's#(id\("com\.android\.application"\)[^\n]*\n)#$1    id("com.google.gms.google-services") version "4.4.2" apply false\n#' "$SETTINGS_GRADLE"
    echo "✔ Plugin de Google Services registrado en settings.gradle.kts"
  fi
  if [ -f "$APP_GRADLE" ] && ! grep -q "com.google.gms.google-services" "$APP_GRADLE"; then
    perl -0pi -e 's#(plugins \{\n)#$1    id("com.google.gms.google-services")\n#' "$APP_GRADLE"
    echo "✔ Plugin de Google Services aplicado en app/build.gradle.kts"
  fi
else
  echo "ℹ Sin android/app/google-services.json: push desactivado en Android (los recordatorios locales sí funcionan)."
fi

if [ ! -f ios/Runner/GoogleService-Info.plist ]; then
  echo "ℹ Sin ios/Runner/GoogleService-Info.plist: push desactivado en iOS (agrégalo desde Xcode al target Runner)."
fi

echo "✔ Notificaciones configuradas. Ejecuta: flutter pub get && flutter run"
