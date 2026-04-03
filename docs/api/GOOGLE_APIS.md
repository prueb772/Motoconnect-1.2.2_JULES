# Google APIs — MotoConnect

## APIs Utilizadas

| API | Uso | SDK/Paquete |
|-----|-----|-------------|
| Maps SDK for Android/iOS | Mapa interactivo | `google_maps_flutter ^2.12.0` |
| Directions API | Rutas turn-by-turn | HTTP directo (`http ^0.13.6`) |
| Places API | Búsqueda de lugares | `google_place ^0.4.7` |
| Geocoding API | Convertir coordenadas ↔ dirección | `geocoding ^4.0.0` |

**API Key:** Configurada en `ApiConstants.googleMapsApiKey` y en `android/app/src/main/AndroidManifest.xml`.

---

## Maps SDK

Usado en:
- `MapaCompartidoScreen` — mapa compartido de sesión en vivo
- `RutasScreen` — visualización y trazado de rutas
- `MapPickerScreen` — selector de ubicación en mapa
- `EventDetailScreen` — mapa del punto de encuentro

```dart
GoogleMap(
  initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 14),
  markers: _markers,
  polylines: _polylines,
  onTap: (latLng) => ...,
)
```

---

## Directions API

Invocada desde `GoogleDirectionsService` para navegación turn-by-turn.

**Endpoint:**
```
GET https://maps.googleapis.com/maps/api/directions/json
  ?origin={lat},{lng}
  &destination={lat},{lng}
  &mode=driving
  &language=es
  &key={API_KEY}
```

**Respuesta parseada a:**
- `DirectionsResponse` — respuesta completa
- `NavigationStep` — cada instrucción (maniobra, distancia, duración, HTML)
- Polilínea decodificada con `flutter_polyline_points`

---

## Places API

Usado en `LocationSearchField` para autocompletar búsquedas de lugares.

```dart
GooglePlace googlePlace = GooglePlace(ApiConstants.googleMapsApiKey);
final result = await googlePlace.autocomplete.get(query);
```

---

## Geocoding API

Usado para convertir coordenadas GPS a nombre de dirección legible.

```dart
List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
```

---

## Configuración Android

En `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyDTFLe8BeQLca2P5ES7vXetX3icv7jiFEE"/>
```

---

## Habilitar APIs en Google Cloud Console

En [console.cloud.google.com](https://console.cloud.google.com), habilitar para el proyecto:
1. Maps SDK for Android
2. Maps SDK for iOS
3. Directions API
4. Places API
5. Geocoding API
