// Constantes relacionadas con APIs y servicios externos
// Centraliza configuraciones de APIs para facilitar cambios entre entornos (desarrollo, producción)

class ApiConstants {
  ApiConstants._();

  // ========================================
  // SUPABASE
  // ========================================

  /// URL base de Supabase
  /// NOTA: Reemplazar con tu URL real en producción
  static const String supabaseUrl = 'https://otxzwutudsruildrtuzy.supabase.co';

  /// Clave anónima de Supabase
  /// NOTA: Reemplazar con tu clave real en producción
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90eHp3dXR1ZHNydWlsZHJ0dXp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4NDk2OTIsImV4cCI6MjA3ODQyNTY5Mn0.cAfcpSPDGdfDDNbk6bq6KiGdzuQhsOLUAcGz7dNwE5w';

  // ========================================
  // GOOGLE MAPS
  // ========================================

  /// API Key de Google Maps
  /// IMPORTANTE: Mantener segura, considerar usar variables de entorno
  static const String googleMapsApiKey =
      'AIzaSyDTFLe8BeQLca2P5ES7vXetX3icv7jiFEE';

  // ========================================
  // TABLAS DE SUPABASE
  // ========================================

  /// Nombre de tabla de usuarios
  static const String usersTable = 'usuarios';

  /// Nombre de tabla de eventos
  static const String eventsTable = 'eventos';

  /// Nombre de tabla de rutas
  static const String routesTable = 'rutas_realizadas';

  /// Nombre de tabla de talleres
  static const String talleresTable = 'talleres';

  /// Nombre de tabla de publicaciones
  static const String postsTable = 'comentarios_comunidad';

  /// Nombre de tabla de participantes de eventos
  static const String eventParticipantsTable = 'participantes_eventos';

  /// Tabla de tokens FCM para push notifications
  static const String fcmTokensTable = 'fcm_tokens';

  /// Nombre de tabla de reacciones
  static const String reactionsTable = 'reacciones_comunidad';

  // ========================================
  // TIMEOUTS
  // ========================================

  /// Timeout para llamadas a API (en segundos)
  static const int apiTimeout = 30;

  /// Timeout para subida de archivos (en segundos)
  static const int uploadTimeout = 60;

  // ========================================
  // STORAGE BUCKETS
  // ========================================

  /// Bucket para imágenes de posts
  static const String postsBucket = 'posts';

  /// Bucket para avatares de usuarios
  static const String avatarsBucket = 'avatars';

  /// Bucket para fotos de eventos
  static const String eventsBucket = 'eventos';

  // ========================================
  // LÍMITES Y CONFIGURACIONES
  // ========================================

  /// Límite máximo de caracteres para contenido de post
  static const int maxPostContentLength = 1000;

  /// Límite máximo de caracteres para comentarios
  static const int maxCommentLength = 500;

  /// Cantidad de posts por página (paginación)
  static const int postsPerPage = 10;

  /// Cantidad de comentarios por página (paginación)
  static const int commentsPerPage = 20;

  // ========================================
  // TIPOS DE PUBLICACIONES
  // ========================================

  /// Tipo: publicación de texto
  static const String postTypeText = 'texto';

  /// Tipo: ruta compartida
  static const String postTypeSharedRoute = 'ruta_compartida';

  /// Tipo: evento compartido
  static const String postTypeSharedEvent = 'evento_compartido';

  /// Tipo: taller compartido
  static const String postTypeSharedTaller = 'taller_compartido';

  // ========================================
  // DEEP LINKS
  // ========================================

  /// Scheme para deep links de la app
  static const String appScheme = 'io.supabase.motoconnect';

  /// URL de redirect para reset de contraseña
  static const String resetPasswordRedirectUrl =
      '$appScheme://reset-callback';
}
