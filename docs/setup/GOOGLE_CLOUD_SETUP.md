# Configuración de Google Cloud — MotoConnect

## APIs a Habilitar

En [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Library, habilitar:

1. **Maps SDK for Android**
2. **Maps SDK for iOS**
3. **Directions API** — navegación turn-by-turn
4. **Places API** — búsqueda de lugares (LocationSearchField)
5. **Geocoding API** — coordenadas ↔ dirección

---

## Crear y Configurar API Key

1. APIs & Services → Credentials → Create Credentials → API Key
2. Restringir la key a las APIs anteriores y al package `com.example.motoconnect` (Android)
3. Copiar la key en dos lugares:

**`lib/core/constants/api_constants.dart`:**
```dart
static const String googleMapsApiKey = 'TU_API_KEY';
```

**`android/app/src/main/AndroidManifest.xml`:**
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="TU_API_KEY"/>
```

---

## Configurar Google OAuth (para Sign In with Google)

1. APIs & Services → OAuth consent screen → configurar
2. APIs & Services → Credentials → Create OAuth 2.0 Client ID
   - Tipo: **Android**
   - Package name: `com.example.motoconnect`
   - SHA-1: obtenido con `keytool -list -v -keystore ~/.android/debug.keystore`
3. También crear un Client ID tipo **Web** (necesario para Supabase)
4. Copiar el **Web Client ID** y **Client Secret** en Supabase Auth → Providers → Google

---

## Firebase Cloud Messaging

Firebase usa Google Cloud internamente. Asegurarse que la **Cloud Messaging API (V1)** esté habilitada:

1. Firebase Console → Project Settings → Cloud Messaging
2. Verificar que "Firebase Cloud Messaging API (V1)" esté activa
3. Si no aparece, habilitarla en Google Cloud Console → APIs & Services

---

## Verificación

Probar que las APIs funcionan:

```bash
# Test de Directions API
curl "https://maps.googleapis.com/maps/api/directions/json?origin=4.6534,-74.0836&destination=4.7110,-74.0721&mode=driving&key=TU_API_KEY"

# Debe retornar status: OK
```
