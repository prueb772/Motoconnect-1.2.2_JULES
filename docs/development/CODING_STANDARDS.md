# Estándares de Código — MotoConnect

## Dart / Flutter

### Nomenclatura

| Elemento | Convención | Ejemplo |
|----------|-----------|---------|
| Clases | PascalCase | `EventModel`, `TalleresBloc` |
| Variables / métodos | camelCase | `nombreRuta`, `getTalleres()` |
| Constantes | camelCase (en clase) | `ApiConstants.eventsTable` |
| Archivos | snake_case | `navigation_tracking_service.dart` |
| Carpetas | snake_case | `lib/presentation/blocs/events/` |

### Tipos Nullable

- Usar `String?` solo cuando el campo **puede ser null en BD**
- No usar `!`, `??` ni `?.` en campos declarados como no-nullable
- Los campos `NOT NULL` de Supabase = tipo no-nullable en Dart

```dart
// CORRECTO — fecha es NOT NULL en BD
final DateTime fecha;

// INCORRECTO — agrega null-safety innecesaria
final timeUntilEvent = event.date?.difference(DateTime.now());
```

### Modelos

Todos los modelos deben tener:
1. Campos `final` (inmutabilidad)
2. Constructor `const` si todos los campos son constantes
3. `factory fromJson(Map<String, dynamic> json)`
4. `Map<String, dynamic> toJson()`
5. `copyWith({...})` para modificar campos

### BLoC

- Un BLoC por módulo funcional
- Estado único con `status` enum + `copyWith`
- Estados extienden `Equatable`
- Eventos son clases simples (no herencia compleja)

```dart
// Estado: una clase con enum
class EventosState extends Equatable {
  final EventosStatus status;
  final List<EventModel> eventos;
  @override List<Object?> get props => [status, eventos];
}

// NO hacer esto:
abstract class EventosState {}
class EventosLoading extends EventosState {}
class EventosLoaded extends EventosState { final List<EventModel> eventos; }
```

### Widgets

- Preferir `StatelessWidget` cuando no hay estado local
- Usar `StatefulWidget` solo para estado efímero de UI (animaciones, campos de texto)
- Nunca crear `TextEditingController` fuera del widget que lo usa — puede causar `_dependents.isEmpty assertion`

### Strings Mágicos

Usar siempre las constantes definidas:

```dart
// CORRECTO
supabase.from(ApiConstants.eventsTable)
Navigator.pushNamed(context, RouteConstants.events)

// INCORRECTO
supabase.from('eventos')
Navigator.pushNamed(context, '/eventos')
```

---

## Supabase

### Selects con Join

Al hacer JOIN en Supabase, nombrar explícitamente los campos para evitar colisiones:

```dart
supabase
  .from('eventos')
  .select('*, evento_grupos(grupo_id, grupos_ruta(nombre)), usuarios(nombre)')
```

### Inserts y Updates

Nunca incluir campos que no existen en la tabla. Verificar siempre contra el esquema actual en `SUPABASE_SCHEMA.md`.

### RLS

Al agregar nuevas tablas que hacen JOIN con tablas que tienen RLS habilitado, verificar si hay riesgo de recursión infinita. Si es necesario, usar funciones `SECURITY DEFINER`.

---

## Análisis Estático

El proyecto debe mantener **0 errores y 0 warnings** en `flutter analyze`:

```bash
flutter analyze
# Esperado: No issues found!
```

Los `info` de `avoid_print` en código de producción son aceptables temporalmente.

---

## Commits

Mensajes de commit descriptivos en español o inglés:

```
feat: agregar pantalla de detalle de evento con mapa
fix: corregir recursión infinita en RLS de evento_grupos
refactor: eliminar campos muertos en RouteModel
chore: actualizar dependencias de Firebase
```
