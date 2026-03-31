/// Servicio de Text-to-Speech para Navegación
///
/// Proporciona anuncios de voz durante la navegación:
/// - Instrucciones de navegación
/// - Alertas de proximidad a giros
/// - Anuncios periódicos de progreso
/// - Anuncio de llegada al destino
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NavigationVoiceService {
  // ========================================
  // DEPENDENCIAS
  // ========================================

  late final FlutterTts _flutterTts;

  // ========================================
  // ESTADO
  // ========================================

  /// Indica si actualmente está hablando
  bool _isSpeaking = false;

  /// Indica si el servicio está inicializado
  bool _isInitialized = false;

  // ========================================
  // GETTERS
  // ========================================

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  // ========================================
  // MÉTODOS PÚBLICOS
  // ========================================

  /// Inicializa el servicio de TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();

      // Configurar idioma: priorizar español latinoamericano
      await _configurarIdiomaEspanol();

      // Velocidad moderada para motociclistas
      await _flutterTts.setSpeechRate(0.5);

      // Volumen máximo para que se escuche con casco
      await _flutterTts.setVolume(1.0);

      // Tono normal
      await _flutterTts.setPitch(1.0);

      // Configurar callbacks para trackear estado
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('Error en TTS: $msg');
        _isSpeaking = false;
      });

      _isInitialized = true;
      debugPrint('NavigationVoiceService inicializado correctamente');
    } catch (e) {
      debugPrint('Error al inicializar TTS: $e');
      _isInitialized = false;
    }
  }

  /// Anuncia una instrucción de navegación.
  ///
  /// [instruction] - Texto de la instrucción (puede contener HTML y abreviaciones)
  /// [distanceText] - Distancia formateada (ej: "200 m", "1.5 km")
  Future<void> announceInstruction(
    String instruction,
    String distanceText,
  ) async {
    if (!_isInitialized) return;

    final cleanInstruction = _prepareTextForTts(instruction);
    final message = 'En $distanceText, $cleanInstruction';
    await _speak(message);
    debugPrint('Anunciado: $message');
  }

  /// Anuncia una alerta de proximidad a un giro.
  ///
  /// [instruction] - Texto de la instrucción (puede contener HTML y abreviaciones)
  /// [distanceMeters] - Distancia en metros al giro (200 o 50)
  Future<void> announceProximityAlert(
    String instruction,
    int distanceMeters,
  ) async {
    if (!_isInitialized) return;

    final cleanInstruction = _prepareTextForTts(instruction);
    final message =
        distanceMeters <= 50
            ? 'Prepárate para $cleanInstruction'
            : 'En $distanceMeters metros, $cleanInstruction';
    await _speak(message);
    debugPrint('Alerta de proximidad: $message');
  }

  /// Anuncia el progreso de la navegación
  ///
  /// [remainingDistance] - Distancia restante formateada
  /// [remainingTime] - Tiempo restante formateado
  Future<void> announceProgress(
    String remainingDistance,
    String remainingTime,
  ) async {
    if (!_isInitialized) return;

    final message =
        'Tiempo restante: $remainingTime. Distancia: $remainingDistance';

    await _speak(message);

    debugPrint('Progreso anunciado: $message');
  }

  /// Anuncia la llegada al destino
  Future<void> announceArrival() async {
    if (!_isInitialized) return;

    const message = 'Has llegado a tu destino';

    await _speak(message);

    debugPrint('Llegada anunciada');
  }

  /// Anuncia que se está recalculando la ruta
  Future<void> announceRecalculating() async {
    if (!_isInitialized) return;
    await _speak('Recalculando ruta...');
    debugPrint('Recalculando anunciado');
  }

  /// Detiene el TTS inmediatamente
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('Error al detener TTS: $e');
    }
  }

  /// Limpia recursos
  void dispose() {
    if (_isInitialized) {
      _flutterTts.stop();
      _isInitialized = false;
      _isSpeaking = false;
      debugPrint('NavigationVoiceService disposed');
    }
  }

  // ========================================
  // MÉTODOS PRIVADOS
  // ========================================

  /// Configura el idioma del TTS priorizando español latinoamericano.
  ///
  /// Orden de preferencia:
  ///   1. es-US  → más disponible en Android latinoamericano (Google TTS)
  ///   2. es-MX  → alternativa latinoamericana
  ///   3. es-ES  → fallback universal
  ///
  Future<void> _configurarIdiomaEspanol() async {
    const preferidos = ['es-US', 'es-MX', 'es-ES'];

    for (final lang in preferidos) {
      try {
        final disponible = await _flutterTts.isLanguageAvailable(lang);
        if (disponible == true || disponible == 1) {
          await _flutterTts.setLanguage(lang);
          debugPrint('TTS: idioma configurado → $lang');
          return;
        }
      } catch (_) {
        continue;
      }
    }

    // Último fallback sin verificar disponibilidad
    await _flutterTts.setLanguage('es-ES');
    debugPrint('TTS: idioma fallback → es-ES');
  }

  /// Habla un mensaje usando TTS.
  /// Interrumpe cualquier anuncio en curso — las instrucciones de navegación
  /// son time-critical y no deben encolarse indefinidamente.
  Future<void> _speak(String message) async {
    if (!_isInitialized) return;

    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }
      await _flutterTts.speak(message);
    } catch (e) {
      debugPrint('Error al hablar: $e');
      _isSpeaking = false;
    }
  }

  /// Prepara el texto para TTS: limpia HTML y expande abreviaciones.
  String _prepareTextForTts(String text) {
    return _normalizeAbbreviations(_cleanHtmlTags(text));
  }

  /// Expande abreviaciones comunes de vías colombianas para una pronunciación
  /// natural en TTS. Se aplica después de limpiar el HTML.
  String _normalizeAbbreviations(String text) {
    return text
        .replaceAll(RegExp(r'\bCra\.?\s*', caseSensitive: false), 'Carrera ')
        .replaceAll(RegExp(r'\bCll\.?\s*', caseSensitive: false), 'Calle ')
        .replaceAll(RegExp(r'\bCl\.?\s*', caseSensitive: false), 'Calle ')
        .replaceAll(RegExp(r'\bKr\.?\s*', caseSensitive: false), 'Carrera ')
        .replaceAll(RegExp(r'\bAv\.?\s*', caseSensitive: false), 'Avenida ')
        .replaceAll(RegExp(r'\bDg\.?\s*', caseSensitive: false), 'Diagonal ')
        .replaceAll(RegExp(r'\bTv\.?\s*', caseSensitive: false), 'Transversal ')
        .replaceAll(RegExp(r'\bKm\.?\s*', caseSensitive: false), 'kilómetro ')
        .replaceAll(RegExp(r'\bNro\.?\s*', caseSensitive: false), 'número ')
        .replaceAll(
          RegExp(r'\bAutop.\.?\s*', caseSensitive: false),
          'Autopista ',
        )
        .trim();
  }

  /// Limpia tags HTML de un texto.
  /// Google Directions API devuelve instrucciones con HTML.
  /// Ejemplo: "Gira a la <b>derecha</b>" → "Gira a la derecha"
  String _cleanHtmlTags(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', 'y')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

}
