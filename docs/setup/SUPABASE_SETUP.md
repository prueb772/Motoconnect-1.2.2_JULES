# Configuración de Supabase — MotoConnect

## Proyecto Activo

| Campo | Valor |
|-------|-------|
| Nombre | MotoConnect |
| ID | `otxzwutudsruildrtuzy` |
| URL | `https://otxzwutudsruildrtuzy.supabase.co` |
| Región | us-east-2 |
| PostgreSQL | 17.x |
| Estado | ACTIVE_HEALTHY |

---

## Configurar en el Código

**`lib/core/constants/api_constants.dart`:**
```dart
static const String supabaseUrl = 'https://otxzwutudsruildrtuzy.supabase.co';
static const String supabaseAnonKey = 'TU_ANON_KEY';
```

**`lib/main.dart`:**
```dart
await SupabaseConfig.initialize(
  url: ApiConstants.supabaseUrl,
  anonKey: ApiConstants.supabaseAnonKey,
);
```

---

## Estructura de la Base de Datos

Ver el esquema completo en [`api/SUPABASE_SCHEMA.md`](../api/SUPABASE_SCHEMA.md) y la descripción detallada en [`Planes/InformeBD.md`](../../Planes/InformeBD.md).

La BD tiene **18 tablas** organizadas en 6 módulos:
- Usuarios y autenticación
- Grupos
- Eventos (con `evento_grupos` many-to-many)
- Talleres (con PostGIS para búsqueda geoespacial)
- Rutas y sesiones en vivo
- Comunidad y notificaciones FCM

---

## Extensiones Requeridas

Habilitar en Supabase Dashboard → **Database → Extensions**:

| Extensión | Para qué |
|-----------|----------|
| `postgis` | Búsqueda geoespacial de talleres |
| `pg_net` | Llamadas HTTP desde triggers (notificaciones) |
| `pg_cron` | Job diario de recordatorios de eventos |

---

## Storage Buckets

Crear en Supabase Dashboard → **Storage**:

```sql
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('posts', 'posts', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('eventos', 'eventos', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('grupos', 'grupos', true);
```

---

## Row Level Security (RLS)

Todas las tablas tienen RLS activado. Las reglas principales:

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `usuarios` | Todos | Solo propio (`auth.uid() = id`) | Solo propio | No |
| `eventos` | Públicos O miembro de grupo asociado O creador | Autenticado | Solo creador | Solo creador |
| `evento_grupos` | Lectura pública | `is_event_creator()` | `is_event_creator()` | `is_event_creator()` |
| `talleres` | Todos | Autenticado | Solo creador | Solo creador |
| `comentarios_comunidad` | Todos | Solo propio | Solo propio | Solo propio |
| `rutas_realizadas` | Todos | Solo propio | Solo propio | Solo propio |
| `grupos_ruta` | Todos | Autenticado | Admin del grupo | Creador |
| `miembros_grupo` | Todos | Admin del grupo | Admin del grupo | Admin del grupo |
| `fcm_tokens` | Solo propio | Solo propio | Solo propio | Solo propio |

> **Nota crítica:** La policy de `evento_grupos` usa la función `is_event_creator(evento_id)` con `SECURITY DEFINER` para evitar recursión infinita. Sin esto, la policy de `eventos` (que hace JOIN con `evento_grupos`) y la policy de `evento_grupos` (que consulta `eventos`) crearían un ciclo infinito.

---

## Notificaciones Push (FCM)

### Pre-requisitos
1. Proyecto Firebase con app Android registrada (`com.example.motoconnect`)
2. `android/app/google-services.json` descargado de Firebase Console
3. Firebase Cloud Messaging API habilitada en Google Cloud Console

### Configuración en Supabase

1. **Secret de Service Account:**
   - Firebase Console → Project Settings → Service accounts → Generate new private key
   - Supabase Dashboard → Edge Functions → Manage secrets → agregar:
     ```
     FIREBASE_SERVICE_ACCOUNT = <contenido del JSON descargado>
     ```

2. **Secret de Service Role Key** (para triggers que llaman Edge Functions):
   - Supabase Dashboard → Settings → API → `service_role` key
   - SQL Editor: `ALTER DATABASE postgres SET app.service_role_key TO 'TU_SERVICE_ROLE_KEY';`

### Scripts SQL a ejecutar (en orden)

```bash
# 1. Tabla de tokens FCM
scripts/create_fcm_tokens_table.sql

# 2. Trigger de notificación al crear evento
scripts/setup_event_notification_trigger.sql

# 3. Triggers de notificación de sesiones grupales
scripts/setup_session_notification_triggers.sql

# 4. Job diario de recordatorios (requiere pg_cron)
scripts/setup_pg_cron_reminders.sql
```

### Desplegar Edge Functions

Con [Supabase CLI](https://supabase.com/docs/guides/cli) instalado:

```bash
supabase functions deploy send-event-notification
supabase functions deploy send-event-reminders
```

### Verificación

```sql
-- Verificar que el token se registró tras iniciar sesión
SELECT * FROM fcm_tokens WHERE usuario_id = auth.uid();

-- Probar recordatorios manualmente
SELECT cron.run_job('send-event-reminders-daily');
```

---

## Habilitar Realtime

Para las ubicaciones en tiempo real de las sesiones grupales:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.ubicaciones_tiempo_real;
ALTER PUBLICATION supabase_realtime ADD TABLE public.participantes_sesion;
ALTER PUBLICATION supabase_realtime ADD TABLE public.rutas_sesion;
ALTER PUBLICATION supabase_realtime ADD TABLE public.sesiones_ruta_activa;
```

---

## Autenticación

### Email/Password
Habilitado por defecto en Supabase Auth.

### Google OAuth
1. Supabase Dashboard → Authentication → Providers → Google
2. Ingresar Client ID y Client Secret (del Google Cloud Console)
3. Redirect URL: `https://otxzwutudsruildrtuzy.supabase.co/auth/v1/callback`
4. En Google Cloud Console → OAuth 2.0 → agregar la redirect URL anterior

### Trigger de creación de perfil
Al registrarse, el trigger `on_auth_user_created` en `auth.users` ejecuta `handle_new_user()` que crea automáticamente la fila en `public.usuarios` con:
- `id` = UUID de auth
- `correo` = email
- `nombre` = del metadata del proveedor OAuth o formulario
- `color_mapa` = número aleatorio 0-9
