# multiApp · Frontend (Flutter)

App móvil para iOS y Android basada en el mockup de Figma "App Mockup Ideas", en español.

## Qué incluye

- **Acceso**: registro e inicio de sesión (token guardado con `flutter_secure_storage`).
- **Inicio**: saludo, tarjeta de IA (abre el Recetario), favoritos, eventos y pendientes de hoy, tiempo libre del día.
- **Apps**: menú principal con todas las apps y buscador.
- **Actividad**: últimos cambios en todas las apps, con filtros.
- **Perfil**: datos de la cuenta y cierre de sesión.
- **Crear rápido** (botón central +): tarea, evento, nota, gasto, compra, receta, comida o entrenamiento.
- Módulos: **Agenda**, **Notas**, **Pendientes**, **Recetario con IA**, **Gastos** y **Lista de compras**.
- **Gastos**: total del mes, promedio diario, desglose por categoría y movimientos por día.
- **Lista de compras**: agregar rápido con cantidad, marcar lo que ya está en el carrito y limpiar comprados.
  Desde el Recetario se pueden mandar los ingredientes de una receta a la lista.
- **¿Dónde compro?** (desde la Lista de compras): la IA agrupa lo pendiente por tipo de tienda
  (súper, farmacia, ferretería…) y muestra en el mapa las tiendas más cercanas con botón **Ir**.
- **Lugares**: guarda casa, trabajo, iglesia, etc. (buscando la dirección, con tu ubicación o tocando el mapa)
  y abre la ruta en Google Maps, Waze o Apple Maps. En Inicio aparecen como accesos rápidos.
- Mapas de **OpenStreetMap** (`flutter_map`), sin clave ni costo.
- **Ejercicio**: la IA arma la rutina del día según tu perfil (objetivo, nivel, equipo, lesiones) y lo que
  entrenaste en la semana; cada ejercicio trae cómo hacerlo, errores comunes y botón **Ver tutorial en YouTube**.
  Modo entrenamiento con series, temporizador de descanso e historial (se agrega a la Agenda).
- **Calorías**: meta diaria calculada con tu perfil, macros, calorías quemadas en ejercicio y registro de comidas
  describiéndolas, con **foto** (IA con visión + Cloudinary) o a mano. Desde el Recetario: **"Lo comí"**
  (tal cual o con cambios).
- **Perfil de salud** (en Perfil): peso, estatura, objetivo y nivel.

## Puesta en marcha

Requisitos: Flutter 3.27 o superior, Xcode (iOS) y/o Android Studio.

```bash
cd multiAppFront
bash scripts/setup.sh      # genera android/ e ios/, instala dependencias y habilita http para desarrollo
flutter run
```

### URL del backend

Por defecto la app usa:

- Emulador Android → `http://10.0.2.2:3000/api`
- Simulador iOS → `http://localhost:3000/api`

En un teléfono físico usa la IP de tu computadora:

```bash
flutter run --dart-define=API_URL=http://192.168.1.50:3000/api
```

## Estructura

```
lib/
  main.dart                  Providers, tema, idioma y selección login / app
  core/                      Configuración, tema (colores del mockup), cliente HTTP, formatos de fecha
  models/models.dart         User, AgendaEvent, Note, Todo, Dashboard, ActivityItem, Recipe, Expense, ShoppingItem
  services/                  AuthController (sesión) y repositorios por módulo
  widgets/                   Componentes del mockup: ModuleIcon, TopBar, GlowCard, EventTile, TodoTile…
  screens/
    modules.dart             Catálogo de mini apps (agregar un módulo = agregarlo aquí)
    shell/                   Barra inferior y hoja "Crear rápido"
    home/ apps/ activity/ profile/
    agenda/ notes/ todos/ recipes/ expenses/ shopping/ places/
    health/ workouts/ nutrition/
test/                        Pruebas de modelos y de la pantalla de login
```

## Comandos útiles

```bash
flutter analyze
flutter test
flutter build apk --dart-define=API_URL=https://tu-servidor/api
flutter build ios --dart-define=API_URL=https://tu-servidor/api
```

> Para producción usa HTTPS y elimina `usesCleartextTraffic` (Android) y `NSAllowsArbitraryLoads` (iOS).
# multiAppFront
