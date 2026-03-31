# Módulo de Autenticación

## Descripción

Gestiona el ciclo de vida de la sesión: registro, login (email/password y Google), logout, y verificación de estado de autenticación.

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `lib/presentation/views/auth/splash_screen.dart` | Pantalla inicial — redirige según estado de auth |
| `lib/presentation/views/auth/login_screen.dart` | Login con email/password y Google |
| `lib/presentation/views/auth/register_screen.dart` | Registro de nuevo usuario |
| `lib/presentation/blocs/auth/auth/auth_bloc.dart` | Estado global de autenticación |
| `lib/presentation/blocs/auth/login/login_bloc.dart` | Lógica del proceso de login |
| `lib/data/repositories/auth_repository.dart` | Abstracción de auth |
| `lib/data/services/api/auth_api_service.dart` | Llamadas a Supabase Auth |
| `lib/domain/usecases/auth/` | LoginUseCase, RegisterUseCase, LogoutUseCase, CheckAuthStatusUseCase |

---

## Flujo

### Login
```
LoginScreen → LoginBloc.add(LoginSubmitted)
    → LoginUseCase.execute(email, password)
    → AuthRepository.signIn()
    → AuthApiService → supabase.auth.signInWithPassword()
    → AuthBloc.add(AuthUserChanged) → AuthAuthenticated
    → Navigator → /home
```

### Registro
```
RegisterScreen → RegisterUseCase.execute(email, password, nombre)
    → AuthApiService.signUp()
    → Supabase Auth crea auth.users
    → Trigger on_auth_user_created → INSERT INTO usuarios (id, correo, nombre, color_mapa)
    → AuthBloc detecta sesión → /home
```

### Google Sign In
```
LoginScreen → botón Google
    → AuthApiService.signInWithGoogle()
    → google_sign_in + supabase.auth.signInWithIdToken()
    → trigger crea perfil en usuarios (si es nuevo)
    → /home
```

---

## AuthBloc (Global)

El `AuthBloc` se provee en `main.dart` a nivel de toda la app:

```dart
MultiBlocProvider(
  providers: [
    BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
  ],
  child: const MotoConnectApp(),
)
```

**Estados:**
- `AuthInitial` — estado inicial
- `AuthLoading` — verificando sesión
- `AuthAuthenticated(user)` — sesión activa
- `AuthUnauthenticated` — sin sesión

**SplashScreen** escucha `AuthBloc` y redirige:
- Autenticado → `/home`
- No autenticado → `/login`

---

## Tablas Involucradas

- `auth.users` (Supabase interno) — credenciales
- `public.usuarios` — perfil extendido del usuario

---

## Proveedor de Autenticación

| Proveedor | Estado |
|-----------|--------|
| Email/Password | Activo |
| Google OAuth | Activo |
| Apple Sign In | No implementado |
