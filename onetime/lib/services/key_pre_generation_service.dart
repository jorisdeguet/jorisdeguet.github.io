import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/random_key_generator_service.dart';
import '../services/key_exchange_service.dart';
import '../models/key_exchange_session.dart';

/// Service responsable de la pré-génération des données de clé
/// pour accélérer le démarrage de l'échange.
class KeyPreGenerationService {
  static final KeyPreGenerationService _instance = KeyPreGenerationService._internal();
  factory KeyPreGenerationService() => _instance;
  KeyPreGenerationService._internal();

  final RandomKeyGeneratorService _keyGenerator = RandomKeyGeneratorService();
  late final KeyExchangeService _keyExchangeService = KeyExchangeService(_keyGenerator);

  // Pool de sessions pré-générées
  // Clé: taille de la clé en bits (ex: 8192 * 8)
  final Map<int, _PreGeneratedSession> _preGeneratedPool = {};
  
  bool _isGenerating = false;
  
  // Tailles standards à pré-générer (8KB, 32KB)
  // On ne pré-génère pas les très grandes clés pour économiser la mémoire
  static const List<int> _standardSizes = [
    8192 * 8,  // 8 KB
    32768 * 8, // 32 KB
  ];

  // Nombre de segments cibles à avoir prêts (30 segments)
  static const int _targetReadySegments = 30;

  /// Initialise le service et commence la pré-génération
  void initialize() {
    debugPrint('[KeyPreGen] Initializing service...');
    // Démarrer la génération en arrière-plan sans bloquer
    Future.delayed(const Duration(seconds: 2), _replenishPool);
  }

  /// Récupère une session pré-générée si disponible
  /// Retourne null si aucune session n'est prête
  _PreGeneratedSession? consumeSession(int totalBits) {
    if (_preGeneratedPool.containsKey(totalBits)) {
      final session = _preGeneratedPool.remove(totalBits);
      debugPrint('[KeyPreGen] Consumed session ${session?.sessionId} for $totalBits bits');
      
      // Déclencher le remplissage du pool
      _triggerReplenish();
      
      return session;
    }
    return null;
  }

  void _triggerReplenish() {
    if (!_isGenerating) {
      // Attendre un peu pour ne pas impacter les performances immédiates
      Future.delayed(const Duration(seconds: 5), _replenishPool);
    }
  }

  Future<void> _replenishPool() async {
    if (_isGenerating) return;
    _isGenerating = true;

    try {
      for (final size in _standardSizes) {
        if (!_preGeneratedPool.containsKey(size)) {
          debugPrint('[KeyPreGen] Generating session for $size bits...');
          
          final session = await _generateSession(size);
          _preGeneratedPool[size] = session;
          
          debugPrint('[KeyPreGen] Session ready for $size bits (${session.preGeneratedSegments.length} segments)');
          
          // Yield to main thread
          await Future.delayed(Duration.zero);
        }
      }
    } catch (e) {
      debugPrint('[KeyPreGen] Error generating session: $e');
    } finally {
      _isGenerating = false;
    }
  }

  Future<_PreGeneratedSession> _generateSession(int totalBits) async {
    final sessionId = 'pre_${DateTime.now().millisecondsSinceEpoch}';
    
    // Créer une session temporaire pour utiliser la logique de génération existante
    // On met des IDs bidons car ils seront remplacés lors de l'utilisation réelle
    final tempSession = KeyExchangeSession(
      sessionId: sessionId,
      role: KeyExchangeRole.source,
      totalBits: totalBits,
      peerIds: ['placeholder'],
      localPeerId: 'source_placeholder',
    );

    final segments = <KeySegmentQrData>[];
    
    // Générer les N premiers segments
    for (int i = 0; i < _targetReadySegments; i++) {
      if (i * KeyExchangeService.segmentSizeBits >= totalBits) break;
      
      final segment = _keyExchangeService.generateNextSegment(tempSession);
      segments.add(segment);
      
      // Yield pour ne pas bloquer l'UI
      if (i % 5 == 0) await Future.delayed(Duration.zero);
    }

    return _PreGeneratedSession(
      sessionId: sessionId,
      preGeneratedSegments: segments,
      totalBits: totalBits,
    );
  }
}

class _PreGeneratedSession {
  final String sessionId;
  final int totalBits;
  final List<KeySegmentQrData> preGeneratedSegments;

  _PreGeneratedSession({
    required this.sessionId,
    required this.totalBits,
    required this.preGeneratedSegments,
  });
}
