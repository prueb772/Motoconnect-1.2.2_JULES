# Variables de Configuración — MotoConnect

Las configuraciones están embebidas directamente en el código (no en archivos `.env`). Los valores se centralizan en `lib/core/constants/api_constants.dart`.

---

## Valores de Configuración

### Supabase

| Constante | Valor | Archivo |
|-----------|-------|---------|
| `supabaseUrl` | `https://otxzwutudsruildrtuzy.supabase.co` | `api_constants.dart` |
| `supabaseAnonKey` | `eyJhbGci...` | `api_constants.dart` y `main.dart` |

### Google

| Constante | Valor | Archivo |
|-----------|-------|---------|
| `googleMapsApiKey` | `AIzaSyDTFLe8BeQLca2P5ES7vXetX3icv7jiFEE` | `api_constants.dart` |
| API Key Android | Mismo valor | `android/app/src/main/AndroidManifest.xml` |

### Firebase

| Archivo | Descripción |
|---------|-------------|
| `android/app/google-services.json` | Configuración Firebase para Android |

---

## Tablas Supabase (ApiConstants)

| Constante | Valor |
|-----------|-------|
| `usersTable` | `usuarios` |
| `eventsTable` | `eventos` |
| `routesTable` | `rutas_realizadas` |
| `talleresTable` | `talleres` |
| `postsTable` | `comentarios_comunidad` |
| `eventParticipantsTable` | `participantes_eventos` |
| `fcmTokensTable` | `fcm_tokens` |

## Storage Buckets (ApiConstants)

| Constante | Valor |
|-----------|-------|
| `postsBucket` | `posts` |
| `avatarsBucket` | `avatars` |
| `eventsBucket` | `eventos` |

---

## Límites de Configuración

| Constante | Valor |
|-----------|-------|
| `apiTimeout` | 30 segundos |
| `uploadTimeout` | 60 segundos |
| `maxPostContentLength` | 1000 caracteres |
| `postsPerPage` | 10 |

---

## Rutas de Navegación Registradas (main.dart)

Estas son las rutas realmente registradas en el router de la app:

| Ruta | Pantalla | Argumentos |
|------|----------|-----------|
| `/splash` | SplashScreen | — |
| `/login` | LoginScreen | — |
| `/registro` | RegistroScreen | — |
| `/home` | HomeScreen | — |
| `/perfil` | PerfilScreen | — |
| `/eventos` | EventosScreen | — |
| `/evento-detalle` | EventDetailScreen | `eventId` (String) |
| `/rutas` | RutasScreen | `rutaInicial` (Map?) |
| `/rutas-recomendadas` | RutasRecomendadasScreen | — |
| `/talleres` | TalleresScreen | — |
| `/comunidad` | ComunidadScreen | — |
| `/grupos` | GruposScreen | — |
| `/grupo-detalle` | DetalleGrupoScreen | `grupoId` (String) |
| `/reset-password` | ResetPasswordScreen | — |
| `/map-picker` | MapPickerScreen | `{initialPosition, initialSearchQuery}` |

> **Nota:** `RouteConstants` centraliza algunas de estas rutas como constantes (principalmente `/splash`, `/login`, `/home`). Las pantallas de grupo y detalle de evento se navegan usando strings directos desde cada pantalla.
