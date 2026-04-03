# Despliegue — MotoConnect

**Versión actual**: 1.2.1+1
**Rama actual**: MotoConnect_1.2.1
**Plataforma**: Solo Android (iOS, web, Linux, macOS y Windows han sido eliminados del proyecto)

---

## Build Android

### Debug

```bash
flutter build apk --debug
```

Salida: `build/app/outputs/flutter-apk/app-debug.apk`

### Release (APK)

```bash
flutter build apk --release
```

Salida: `build/app/outputs/flutter-apk/app-release.apk`

### Release (App Bundle — para Play Store)

```bash
flutter build appbundle --release
```

Salida: `build/app/outputs/bundle/release/app-release.aab`

### Ejecutar en dispositivo conectado

```bash
flutter run --release
```

---

## Configuración del Build

**Archivo de build**: `android/app/build.gradle.kts` (Kotlin DSL)

**Min SDK**: Ver valor de `minSdk` en `build.gradle.kts`.
**Target SDK**: Ver valor de `targetSdk` en `build.gradle.kts`.

**Nombre y código de versión** se configuran en `pubspec.yaml`:

```yaml
version: 1.2.1+1
# 1.2.1 = versionName (mostrado al usuario)
# 1     = versionCode (entero, debe incrementarse en cada subida a Play Store)
```

Para actualizar la versión en un nuevo lanzamiento, modificar esta línea en `pubspec.yaml`.

---

## Firmado

Un build de release requiere un keystore. Configurar el firmado en `android/app/build.gradle.kts` usando un bloque `signingConfigs`. Guardar las credenciales del keystore fuera del repositorio (variables de entorno o archivo `key.properties` excluido via `.gitignore`).

---

## Lista de Verificación Pre-Lanzamiento

- [ ] Actualizar `version` en `pubspec.yaml` (incrementar versionCode para Play Store)
- [ ] Confirmar que `SUPABASE_URL` y `SUPABASE_ANON_KEY` apuntan al proyecto de producción (`otxzwutudsruildrtuzy`)
- [ ] Confirmar que `GOOGLE_MAPS_API_KEY` está configurada en `android/app/src/main/AndroidManifest.xml`
- [ ] Confirmar que `google-services.json` de Firebase está en `android/app/`
- [ ] Ejecutar `flutter pub get` para asegurar que las dependencias estén actualizadas
- [ ] Ejecutar `flutter analyze` — corregir todos los warnings y errores
- [ ] Probar en un dispositivo Android físico (los emuladores no reproducen fielmente GPS ni servicios en primer plano)
- [ ] Verificar que los canales de notificación aparezcan correctamente:
  - `geolocator_channel_01` (IMPORTANCE_LOW) — notificación del servicio de ubicación en primer plano
  - `eventos_channel` (IMPORTANCE_HIGH) — notificaciones push de eventos
  - `sesiones_channel` (IMPORTANCE_HIGH) — notificaciones push de sesiones y SOS
- [ ] Probar seguimiento de GPS en segundo plano (minimizar app mientras se está en `MapaCompartidoScreen`)
- [ ] Probar notificaciones push FCM (crear evento, iniciar sesión)
- [ ] Verificar conexiones Supabase Realtime en `MapaCompartidoScreen` (actualizaciones de participantes y ubicaciones)
- [ ] Verificar guía de voz en navegación giro a giro
- [ ] Verificar detección de desvío y recálculo de ruta

---

## Despliegue de Edge Functions

Las Edge Functions se despliegan via el CLI de Supabase.

### Instalar / Actualizar CLI

```bash
npm install -g supabase
```

### Iniciar sesión

```bash
supabase login
```

### Desplegar una función específica

```bash
supabase functions deploy send-session-notification --project-ref otxzwutudsruildrtuzy
supabase functions deploy send-event-notification --project-ref otxzwutudsruildrtuzy
supabase functions deploy send-event-reminders --project-ref otxzwutudsruildrtuzy
```

### Desplegar todas las funciones

```bash
supabase functions deploy --project-ref otxzwutudsruildrtuzy
```

### Secretos de entorno de las Edge Functions

Las Edge Functions requieren credenciales de cuenta de servicio de Firebase para FCM. Configurar como secretos de Supabase:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}' --project-ref otxzwutudsruildrtuzy
```

Los secretos son accesibles dentro de las edge functions via `Deno.env.get('FIREBASE_SERVICE_ACCOUNT')`.

---

## Migraciones de Base de Datos

Las migraciones se rastrean en `supabase/migrations/`. Aplicar migraciones pendientes:

```bash
supabase db push --project-ref otxzwutudsruildrtuzy
```

Para crear un nuevo archivo de migración:

```bash
supabase migration new <nombre_migracion>
```

Esto crea un archivo SQL con timestamp en `supabase/migrations/`. Escribir el SQL de la migración y luego ejecutar push.

---

## Variables de Entorno

La app lee la configuración de Supabase y Google Maps en tiempo de build. Estos valores se configuran en:
- `lib/core/constants/api_constants.dart` y `lib/core/config/supabase_config.dart` para Supabase
- `android/app/src/main/AndroidManifest.xml` para la clave de Maps API

No subir claves API al repositorio. Usar configuración por entorno o secretos de CI/CD.

---

## Notas de CI/CD

- La rama `MotoConnect_1.2.2` es la rama de desarrollo actual.
- `main` es la rama estable de producción.
- Los pull requests deben apuntar a `main` para lanzamientos.
- Los directorios de plataforma iOS, web, Linux, macOS y Windows han sido eliminados. No restaurarlos a menos que las plataformas sean soportadas activamente.
