# Publicar MultiApp en App Store y Google Play

| Dato | Valor |
|---|---|
| Nombre en el teléfono | **MultiApp** |
| Bundle ID (iOS) / Package (Android) | **com.aldahirballina.multiapp** (permanente: no se puede cambiar después de publicar) |
| Versión | `version:` en `pubspec.yaml` → `1.0.0+1` (nombre visible + número de compilación) |
| Dispositivos | iPhone (sin layout de iPad) y teléfonos Android, solo vertical |

## 0. Lo que ya está listo en el proyecto

- Íconos de iOS (todas las medidas + 1024 sin transparencia) y de Android (clásico, adaptativo y monocromático para Android 13+).
- Ícono blanco para notificaciones de Android (`ic_notification`).
- Pantalla de inicio con fondo oscuro y logo: iOS (`LaunchScreen.storyboard`), Android ≤ 11 y Android 12+.
- Imágenes para las tiendas en `branding/store/`: ícono App Store 1024, ícono Play 512 y gráfico destacado 1024×500.
- Firma de release de Android preparada (lee `android/key.properties`).
- Android apunta a API 36 (obligatorio en Play desde el 31 de agosto de 2026).
- `http://` solo se permite en depuración; la versión publicada exige **https**.
- iOS: `ITSAppUsesNonExemptEncryption = NO` (evita la pregunta de cifrado en cada subida) y modo en segundo plano para push.

Si cambias el ícono: reemplaza `branding/icon_source.png` y ejecuta `python3 scripts/generate_branding.py`.

## 1. Antes de publicar (obligatorio en ambas tiendas)

1. **Backend en internet con HTTPS.** El teléfono de otra persona no puede llegar a tu computadora.
   Opciones: Azure App Service + Azure SQL, Railway, Render o un VPS con dominio y certificado.
   Luego compila con tu URL: `--dart-define=API_URL=https://api.tudominio.com/api`
2. **Política de privacidad** publicada en una URL (qué datos guardas, para qué, cómo borrarlos).
3. **Página web para pedir borrar la cuenta** (Google Play la exige además del botón dentro de la app, que ya existe).
4. **Cuenta de prueba** para los revisores (correo y contraseña con datos de ejemplo).
5. Firebase (si quieres push) registrado **con el ID nuevo** `com.aldahirballina.multiapp`.

## 2. Android / Google Play

### 2.1 Crear tu llave de firma (una sola vez, guárdala para siempre)

```bash
keytool -genkey -v -keystore ~/multiapp-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Crea `android/key.properties` (ya está en `.gitignore`):

```properties
storePassword=LA_CONTRASEÑA_QUE_ELEGISTE
keyPassword=LA_CONTRASEÑA_QUE_ELEGISTE
keyAlias=upload
storeFile=/Users/aldahirballina/multiapp-upload.jks
```

> Respalda el `.jks` y las contraseñas (gestor de contraseñas). Con *Play App Signing*, si la pierdes Google puede
> restablecerla, pero tarda días.

### 2.2 Compilar

```bash
flutter build appbundle --release --dart-define=API_URL=https://api.tudominio.com/api
# Resultado: build/app/outputs/bundle/release/app-release.aab
```

### 2.3 Play Console

1. Crea la app: nombre "MultiApp", idioma español (México), App, Gratis.
2. **Ficha de Play Store:** descripción corta (80 car.) y completa, ícono 512 (`branding/store/play_store_icon_512.png`),
   gráfico destacado (`play_feature_graphic_1024x500.png`) y mínimo 2 capturas de teléfono.
3. **Contenido de la app:** política de privacidad, acceso a la app (cuenta de prueba), anuncios (no),
   clasificación de contenido, público objetivo (mayores de 13/18), **Seguridad de los datos** (ver tabla abajo),
   **eliminación de cuenta** (URL), apps de salud (declara que es de bienestar, no médica).
4. **Cuentas personales nuevas:** antes de producción necesitas una **prueba cerrada con al menos 12 testers
   durante 14 días seguidos**. Sube el .aab a *Prueba cerrada*, invita por correo (o grupo de Google) y espera.
5. Después: *Producción → Crear versión* → sube el .aab → revisión (de horas a varios días).

## 3. iOS / App Store

### 3.1 En Xcode (una vez)

```bash
open ios/Runner.xcworkspace
```

1. Runner → *Signing & Capabilities* → Team: tu equipo, *Automatically manage signing* activado
   (crea el Bundle ID `com.aldahirballina.multiapp` solo).
2. **+ Capability → Push Notifications** y **+ Capability → Background Modes** (marca *Remote notifications*).
3. Si usas push: agrega `GoogleService-Info.plist` al target Runner y sube tu llave APNs (.p8) a Firebase.

### 3.2 App Store Connect

1. *Apps → + → Nueva app*: plataforma iOS, nombre (debe estar libre en la tienda; si "MultiApp" está ocupado usa
   p. ej. "MultiApp: tu día"), idioma español (México), Bundle ID, SKU `multiapp-001`.
2. **Privacidad de la app** (etiquetas de privacidad, misma información de la tabla de abajo) y URL de la política.
3. Capturas: iPhone 6.9" (1320×2868 o 1290×2796). Puedes tomarlas del simulador del iPhone Pro Max más reciente con ⌘S.
4. Ícono de la tienda: se toma del propio paquete (ya incluye el de 1024).

### 3.3 Compilar y subir

```bash
flutter build ipa --release --dart-define=API_URL=https://api.tudominio.com/api
# Resultado: build/ios/ipa/*.ipa
```

Súbelo con la app **Transporter** (Mac App Store) o desde Xcode → *Organizer → Distribute App*.
Pruébalo primero en **TestFlight**, luego *Agregar para revisión*. En *Notas para el revisor* pon la cuenta de prueba.

## 4. Datos que declara la app (Seguridad de los datos / Privacidad)

| Dato | Para qué | ¿Se comparte? |
|---|---|---|
| Nombre, correo, teléfono, fecha de nacimiento, ciudad | Cuenta y perfil | No |
| Foto de perfil | Perfil (se guarda en Cloudinary) | Proveedor de almacenamiento |
| Fotos de comida | Calcular calorías (se envían a la IA y **no se guardan**) | Proveedor de IA (Groq) |
| Ubicación aproximada/precisa | Tiendas cercanas (no se guarda) | OpenStreetMap |
| Salud y ejercicio (peso, estatura, comidas, entrenamientos) | Metas de calorías y rutinas | Proveedor de IA (Groq) |
| Agenda, notas, pendientes, gastos, compras, lugares | Funciones de la app | No |
| Token del dispositivo | Notificaciones push | Firebase |

Todo viaja cifrado (https) y el usuario puede borrar su cuenta y todos sus datos desde Perfil → Cuenta y seguridad.

## 5. Cada actualización

1. Sube la versión en `pubspec.yaml`, p. ej. `1.0.1+2` (el número después de `+` **siempre debe aumentar**).
2. `flutter build appbundle …` y `flutter build ipa …` con la misma `API_URL`.
3. Sube a Play Console y App Store Connect.
