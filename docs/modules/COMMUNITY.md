# Módulo de Comunidad

## Descripción

Feed social donde los motociclistas comparten experiencias, fotos, videos y referencias a rutas, eventos y talleres. Los posts se almacenan en la tabla `comentarios_comunidad` (nombre histórico).

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `lib/presentation/views/community/community_screen.dart` | Feed principal con lista de posts |
| `lib/presentation/blocs/community/community_bloc.dart` | Estado del módulo |

---

## Tabla `comentarios_comunidad`

> El nombre histórico de la tabla es `comentarios_comunidad`, pero en la app funciona como el **feed de posts**. La constante en código es `ApiConstants.postsTable = 'comentarios_comunidad'`.

Tipos de post (`tipo`):
| Tipo | Descripción |
|------|-------------|
| `texto` | Solo texto |
| `imagen` | Texto + imagen en Storage |
| `video` | Texto + video en Storage |
| `ruta_compartida` | Referencia a una ruta (`referencia_ruta_id`) |
| `evento_compartido` | Referencia a un evento (`referencia_evento_id`) |
| `taller_compartido` | Referencia a un taller (`referencia_taller_id`) |

---

## Storage de Media

Los archivos de posts (imágenes y videos) se suben al bucket `posts` de Supabase Storage.

- El campo `media_url` almacena la URL pública del archivo
- `imagen_url` es un campo histórico que puede contener también URLs de imágenes
- Los videos se reproducen con `video_player ^2.9.2`

---

## Estado del BLoC (`CommunityBloc`)

```dart
enum CommunityStatus { initial, loading, loaded, posting, posted, deleted, error }

class CommunityState {
  final CommunityStatus status;
  final List<PublicacionConAutor> publicaciones;
  final String? errorMessage;
}

// Eventos activos
class CommunityLoadRequested extends CommunityEvent {}
class CommunityRefreshRequested extends CommunityEvent {}
class CommunityTextPostRequested extends CommunityEvent { final String content; }
class CommunityMediaPostRequested extends CommunityEvent { /* content, mediaUrl, tipo */ }
class CommunityPostEditRequested extends CommunityEvent { final String postId; final String newContent; }
class CommunityPostDeleteRequested extends CommunityEvent { final String postId; }
class CommunityErrorCleared extends CommunityEvent {}
```

---

## Edición de Posts

La edición de posts usa un `StatefulWidget` (`_EditarPublicacionDialog`) que es dueño del `TextEditingController` para evitar el error de assertion `_dependents.isEmpty` que ocurre cuando el controller se dispone externamente mientras el diálogo aún cierra con animación.


