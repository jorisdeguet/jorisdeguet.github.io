import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../models/key_exchange_session.dart';
import '../services/key_exchange_service.dart';

/// Service pour pré-générer et cacher les segments QR
class QrSegmentCacheService {
  static final QrSegmentCacheService _instance = QrSegmentCacheService._internal();
  factory QrSegmentCacheService() => _instance;
  QrSegmentCacheService._internal();

  final Map<String, List<Uint8List>> _segmentCache = {};
  bool _isGenerating = false;

  /// Pré-génère les segments pour une session
  Future<void> pregenerateSegments(
    KeyExchangeSession session,
    KeyExchangeService service,
  ) async {
    final sessionId = session.sessionId;
    
    if (_isGenerating) return;
    if (_segmentCache.containsKey(sessionId)) return;

    _isGenerating = true;
    debugPrint('[QrCache] Pre-generating ${session.totalSegments} segments...');
    final startTime = DateTime.now();

    try {
      final segments = <Uint8List>[];
      
      // Générer tous les segments
      for (int i = 0; i < session.totalSegments; i++) {
        service.generateNextSegment(session);
        // Yield to event loop every 5 segments to keep UI responsive
        if (i % 5 == 0) await Future.delayed(Duration.zero);
      }

      // Stocker les données générées (pas besoin de cache pour l'instant,
      // les segments sont déjà dans la session)
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('[QrCache] Pre-generated ${session.totalSegments} segments in ${duration}ms');
    } catch (e) {
      debugPrint('[QrCache] Error pre-generating segments: $e');
    } finally {
      _isGenerating = false;
    }
  }

  /// Récupère un segment depuis le cache
  Uint8List? getCachedSegment(String sessionId, int index) {
    final segments = _segmentCache[sessionId];
    if (segments == null || index >= segments.length) return null;
    return segments[index];
  }

  /// Vérifie si une session est en cache
  bool isCached(String sessionId) {
    return _segmentCache.containsKey(sessionId);
  }

  /// Nettoie le cache pour une session
  void clearSession(String sessionId) {
    _segmentCache.remove(sessionId);
    debugPrint('[QrCache] Cleared cache for session $sessionId');
  }

  /// Nettoie tout le cache
  void clearAll() {
    _segmentCache.clear();
    debugPrint('[QrCache] Cleared all cache');
  }
}
