#!/usr/bin/env bash
# Genera las carpetas nativas (android/ e ios/) y ajusta permisos de red para desarrollo.
# Uso:  cd multiAppFront && bash scripts/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▶ Generando proyectos nativos (no sobrescribe lib/ ni pubspec.yaml)…"
flutter create . --project-name multiapp --org mx.edu.ulv --platforms=android,ios

echo "▶ Instalando dependencias…"
flutter pub get

MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
    perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
    echo "✔ Permiso INTERNET agregado a Android"
  fi
  if ! grep -q "usesCleartextTraffic" "$MANIFEST"; then
    # Permite http:// hacia el backend local durante el desarrollo.
    perl -0pi -e 's#<application#<application\n        android:usesCleartextTraffic="true"#' "$MANIFEST"
    echo "✔ Tráfico http habilitado en Android (solo para desarrollo)"
  fi
  if ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
    perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>#' "$MANIFEST"
    echo "✔ Permisos de ubicación agregados a Android"
  fi
fi

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q "NSLocationWhenInUseUsageDescription" "$PLIST"; then
  if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy \
      -c "Add :NSLocationWhenInUseUsageDescription string 'multiApp usa tu ubicación para mostrarte tiendas cercanas y cómo llegar a tus lugares.'" \
      "$PLIST"
    echo "✔ Permiso de ubicación agregado a iOS"
  fi
fi

if [ -f "$PLIST" ] && ! grep -q "NSAppTransportSecurity" "$PLIST"; then
  if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy \
      -c "Add :NSAppTransportSecurity dict" \
      -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" \
      -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" \
      "$PLIST"
    echo "✔ Tráfico http habilitado en iOS (solo para desarrollo)"
  else
    echo "⚠ No se encontró PlistBuddy (¿no estás en macOS?). Agrega NSAppTransportSecurity a $PLIST manualmente."
  fi
fi

if [ -f "$PLIST" ] && ! grep -q "NSCameraUsageDescription" "$PLIST"; then
  if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy \
      -c "Add :NSCameraUsageDescription string 'multiApp usa la cámara para tomar fotos de tu comida y calcular sus calorías.'" \
      -c "Add :NSPhotoLibraryUsageDescription string 'multiApp usa tus fotos para calcular las calorías de un platillo.'" \
      "$PLIST"
    echo "✔ Permisos de cámara y fotos agregados a iOS"
  fi
fi

bash scripts/setup_notifications.sh

echo "✔ Listo. Ejecuta: flutter run"
