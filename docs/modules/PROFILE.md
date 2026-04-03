# Módulo de Perfil

**Pantalla**: `lib/presentation/views/profile/profile_screen.dart`
**BLoC**: `ProfileBloc`
**Storage**: bucket `avatars` (Supabase Storage)
**Tabla**: `usuarios`

---

## UserModel

**Ubicación**: `lib/data/models/user_model.dart`

UserModel mapea directamente la tabla `usuarios`. El campo `color_mapa` que existía en versiones anteriores fue eliminado en la migración `remove_color_mapa` (2026-03-15) y no está presente en el modelo ni en la tabla.

| Campo | Tipo | Columna Fuente | Propósito |
|-------|------|----------------|-----------|
| id | String | usuarios.id | UUID del usuario, coincide con auth.users.id |
| email | String | usuarios.correo | Correo electrónico del usuario |
| nombre | String? | usuarios.nombre | Nombre completo |
| apodo | String? | usuarios.apodo | Apodo visible |
| modeloMoto | String? | usuarios.modelo_moto | Modelo de la moto |
| fotoPerfilUrl | String? | usuarios.foto_perfil_url | URL de foto de perfil (bucket avatars) |

El modelo usa constructor const, `fromJson`, `toJson` y `copyWith`.

---

## ProfileBloc

Gestiona la carga y actualización del perfil del usuario.

### Eventos

| Evento | Propósito |
|--------|-----------|
| ProfileLoadRequested | Obtiene el registro `usuarios` del usuario actual desde Supabase |
| ProfileNameChanged | Actualiza el campo nombre en el estado |
| ProfileNicknameChanged | Actualiza el campo apodo en el estado |
| ProfileMotoModelChanged | Actualiza el campo modeloMoto en el estado |
| ProfileSaveRequested | Hace upsert de los campos actualizados en Supabase |
| ProfileErrorCleared | Limpia el mensaje de error del estado |

### Estados (enum ProfileStatus)

| Status | Significado |
|--------|-------------|
| initial | Sin carga iniciada |
| loading | Consulta en progreso |
| loaded | Datos de perfil disponibles |
| saving | Guardado en progreso |
| saved | Actualización guardada exitosamente |
| error | Error con mensaje |

---

## Flujo de Subida de Foto

1. El usuario presiona el ícono de cámara sobre el avatar.
2. `_mostrarOpcionesFoto` muestra un bottom sheet (cámara / galería / eliminar).
3. La imagen se sube al bucket `avatars` con la ruta `{userId}/avatar.jpg` (sobrescribe la anterior).
4. Se obtiene la URL pública desde Supabase Storage.
5. `usuarios.foto_perfil_url` se actualiza con la nueva URL.

El bucket `avatars` está configurado con acceso de lectura público — no se requieren URLs firmadas para mostrar la foto.

---

## Visualización de Versión de la App

`profile_screen.dart` usa `package_info_plus` para leer y mostrar la versión actual de la app (ej. `1.2.1`). Se muestra en la UI de perfil como una etiqueta informativa estática. La versión proviene de `pubspec.yaml` (`version: 1.2.1+1`).

---

## RLS

La tabla `usuarios` tiene las siguientes políticas relevantes para la edición de perfil:

| Operación | Condición |
|-----------|-----------|
| SELECT | `true` — cualquier usuario autenticado puede leer cualquier perfil |
| UPDATE | `id = auth.uid()` — los usuarios solo pueden actualizar su propio registro |

Los usuarios no pueden modificar el perfil de otro usuario. Supabase hace cumplir esto via RLS; no se requiere ninguna guardia a nivel de aplicación para el caso básico.

---

## Funcionalidades de la Pantalla de Perfil

- Muestra y edita inline: nombre, apodo, modeloMoto (sin pantalla de edición separada).
- Foto de avatar: presionar ícono de cámara → cámara / galería / eliminar.
- Muestra correo (solo lectura).
- Muestra versión de la app (desde `package_info_plus`).
- Provee acceso al selector de tema (claro/oscuro/sistema) via ThemeCubit.
- Botón de cerrar sesión.
