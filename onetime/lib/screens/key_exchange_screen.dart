import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../config/app_config.dart';
import '../model_remote/kex_session.dart';
import '../model_local/shared_key.dart';
import '../services/random_key_generator_service.dart';
import '../services/key_exchange_service.dart';
import '../services/key_exchange_sync_service.dart';
import '../services/key_storage_service.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import '../services/pseudo_storage_service.dart';
import '../services/crypto_service.dart';
import '../services/qr_segment_cache_service.dart';
import '../services/key_pre_generation_service.dart';
import '../services/app_logger.dart';
import '../services/service_locator.dart';
import 'key_exchange_summary_screen.dart';

/// Écran d'échange de clé via QR codes.
class KeyExchangeScreen extends StatefulWidget {
  final List<String> peerIds;
  final String? existingConversationId;

  const KeyExchangeScreen({
    super.key,
    required this.peerIds,
    this.existingConversationId,
  });

  @override
  State<KeyExchangeScreen> createState() => _KeyExchangeScreenState();
}

class _KeyExchangeScreenState extends State<KeyExchangeScreen> {
  final AuthService _authService = AuthService();
  final RandomKeyGeneratorService _keyGenerator = RandomKeyGeneratorService();
  final KeyExchangeSyncService _syncService = KeyExchangeSyncService();
  final KeyStorageService _keyStorageService = KeyStorageService();
  final PseudoStorageService _pseudoService = PseudoStorageService();
  final QrSegmentCacheService _cacheService = QrSegmentCacheService();
  late final KeyExchangeService _keyExchangeService;
  final _log = AppLogger();

  // Session locale (pour les données de clé)
  KexSessionReader? _session;

  // Session Firestore (pour la synchronisation)
  KexSessionModel? _firestoreSession;
  StreamSubscription<KexSessionModel?>? _sessionSubscription;

  KeyExchangeRole _role = KeyExchangeRole.source;
  int _currentStep = 0;
  KeySegmentQrData? _currentQrData;
  bool _isScanning = false;
  bool _processingScan = false;
  bool _isFinalizing = false;
  String? _errorMessage;
  
  // Taille de clé à générer (en bits)
  int _keySizeBits = 8192 * 8; // 8 KB par défaut

  // Gestion de la luminosité
  double? _originalBrightness;
  bool _isBrightnessMaxed = false;

  // Mode torrent: rotation automatique des QR codes
  Timer? _torrentRotationTimer;
  final bool _torrentModeEnabled = true;
  // Use 600ms (0.6s) per QR rotation to speed up manual testing
  Duration _torrentRotationInterval = const Duration(milliseconds: 600); // Commencer à 1 seconde

  // Suivi des participants ayant scanné au moins un segment dans le dernier tour
  Map<String, bool> _participantScannedInRound = {};

  @override
  void initState() {
    super.initState();
    _keyExchangeService = KeyExchangeService(_keyGenerator);
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _torrentRotationTimer?.cancel();
    _restoreBrightness();
    super.dispose();
  }

  /// Met la luminosité au maximum pour afficher le QR code
  Future<void> _setMaxBrightness() async {
    if (_isBrightnessMaxed) return;

    try {
      _originalBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
      _isBrightnessMaxed = true;
      _log.i('KeyExchange', 'Brightness set to maximum');
    } catch (e) {
      _log.e('KeyExchange', 'Error setting brightness: $e');
    }
  }

  /// Restaure la luminosité originale
  Future<void> _restoreBrightness() async {
    if (!_isBrightnessMaxed) return;

    try {
      if (_originalBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
      } else {
        await ScreenBrightness().resetScreenBrightness();
      }
      _isBrightnessMaxed = false;
      _log.i('KeyExchange', 'Brightness restored');
    } catch (e) {
      _log.e('KeyExchange', 'Error restoring brightness: $e');
    }
  }

  /// Envoie un message pseudo chiffré pour que les autres participants connaissent notre pseudo
  Future<void> _sendPseudoMessage(String conversationId, SharedKey sharedKey) async {
    // Vérifier si l'échange de pseudo est activé
    if (!AppConfig.pseudoExchangeStartConversation) {
      _log.d('KeyExchange', 'Pseudo exchange disabled by config');
      return;
    }

    try {
      final myPseudo = await _pseudoService.getMyPseudo();
      if (myPseudo == null || myPseudo.isEmpty) {
        _log.d('KeyExchange', 'No pseudo to send');
        return;
      }

      // Wait 3 seconds before sending
      _log.d('KeyExchange', 'Waiting 3 seconds before sending pseudo...');
      await Future.delayed(const Duration(seconds: 3));

      final pseudoMessage = PseudoExchangeMessage(
        oderId: _currentUserId,
        pseudo: myPseudo, // No smiley in stored message
      );

      final cryptoService = CryptoService(localPeerId: _currentUserId);
      final conversationService = ConversationService(localUserId: _currentUserId);

      // Chiffrer le message pseudo
      final result = cryptoService.encrypt(
        plaintext: pseudoMessage.toJson(),
        sharedKey: sharedKey,
        compress: true,
      );

      // Mettre à jour les bits utilisés
      await _keyStorageService.updateUsedBits(
        conversationId,
        result.usedSegment.startBit,
        result.usedSegment.endBit,
      );

      // Envoyer le message
      await conversationService.sendMessage(
        conversationId: conversationId,
        message: result.message,
        messagePreview: '👤 Pseudo partagé',
      );

      _log.i('KeyExchange', 'Pseudo message sent successfully');
    } catch (e) {
      _log.e('KeyExchange', 'Error sending pseudo message: $e');
      // Ne pas bloquer si l'envoi du pseudo échoue
    }
  }

  String get _currentUserId => _authService.currentUserId ?? '';

  Future<void> _startAsSource() async {
    final startTime = DateTime.now();
    _log.d('KeyExchange', '${startTime.toIso8601String()} - Button pressed, starting as source');

    if (_currentUserId.isEmpty) return;

    setState(() => _errorMessage = null);

    try {
      // CHECK FOR PRE-GENERATED SESSION
      final preGenService = KeyPreGenerationService();
      final preGenSession = preGenService.consumeSession(_keySizeBits);
      
      // Utiliser l'ID pré-généré si disponible, sinon en créer un nouveau
      // Note: On utilise un nouvel ID Firestore de toute façon pour garantir l'unicité et le bon format
      // mais on réutilise les données de clé pré-générées
      
      final step1 = DateTime.now();
      _log.d('KeyExchange', '+${step1.difference(startTime).inMilliseconds}ms - Calculating segments');

      // Calculer le nombre de segments
      final totalSegments = (_keySizeBits + KeyExchangeService.segmentSizeBits - 1) ~/
                            KeyExchangeService.segmentSizeBits;

      final step2 = DateTime.now();
      _log.d('KeyExchange', '+${step2.difference(startTime).inMilliseconds}ms - Creating Firestore session');

      // Créer la session dans Firestore D'ABORD pour avoir l'ID
      _firestoreSession = await _syncService.createSession(
        sourceId: _currentUserId,
        participants: widget.peerIds,
        totalKeyBits: _keySizeBits,
        totalSegments: totalSegments,
      );

      final step3 = DateTime.now();
      _log.d('KeyExchange', '+${step3.difference(startTime).inMilliseconds}ms - Firestore session created:');
      _log.d('KeyExchange', '  Session ID: ${_firestoreSession!.id}');
      _log.d('KeyExchange', '  Source: ${_firestoreSession!.sourceId}');
      _log.d('KeyExchange', '  Participants: ${_firestoreSession!.participants}');
      _log.d('KeyExchange', '  Other Participants: ${_firestoreSession!.otherParticipants}');
      _log.d('KeyExchange', '  Total Segments: ${_firestoreSession!.totalSegments}');
      _log.d('KeyExchange', 'Creating local session...');

      // Créer la session locale avec le MÊME ID que Firestore
      // Et injecter les segments pré-générés si disponibles
      _session = _keyExchangeService.createSourceSession(
        totalBits: _keySizeBits,
        peerIds: widget.peerIds,
        sourceId: _currentUserId,
        sessionId: _firestoreSession!.id, // Utiliser l'ID Firestore
        preGeneratedSegments: preGenSession?.preGeneratedSegments,
      );
      
      if (preGenSession != null && preGenSession.preGeneratedSegments.isNotEmpty) {
        _log.d('KeyExchange', 'Using ${preGenSession.preGeneratedSegments.length} pre-generated segments');
      }

      final step4 = DateTime.now();
      _log.d('KeyExchange', '+${step4.difference(startTime).inMilliseconds}ms - Local session created, setting up listeners');

      // Écouter les changements de la session Firestore
      _sessionSubscription = _syncService
          .watchSession(_firestoreSession!.id)
          .listen(_onSessionUpdate);

      final step5 = DateTime.now();
      _log.d('KeyExchange', '+${step5.difference(startTime).inMilliseconds}ms - Listeners setup, updating UI state');

      setState(() {
        _role = KeyExchangeRole.source;
        _currentStep = 1;
      });

      final step6 = DateTime.now();
      _log.d('KeyExchange', '+${step6.difference(startTime).inMilliseconds}ms - UI updated, generating segments');

      // Initialiser le suivi des participants pour le mode torrent
      if (_torrentModeEnabled) {
        _participantScannedInRound = {};
        for (final participantId in _firestoreSession!.otherParticipants) {
          _participantScannedInRound[participantId] = false;
        }
        
        final step7 = DateTime.now();
        _log.d('KeyExchange', '+${step7.difference(startTime).inMilliseconds}ms - Starting segment generation (torrent mode)');

        // --- MODIFICATION: Generate FIRST segment only, then start torrent rotation which will trigger background generation ---
        
        // 1. Generate first segment immediately (or use pre-generated if available)
        // Since we injected pre-generated segments, _currentQrData might need to be set from them
        if (preGenSession != null && preGenSession.preGeneratedSegments.isNotEmpty) {
           _log.d('KeyExchange', 'Displaying first pre-generated segment immediately');
           _displaySegmentAtIndex(0);
        } else {
           _log.d('KeyExchange', 'Generating first segment immediately for display');
           if (_session is KexSessionSource) _generateNextSegment(); // ensure source
        }
        
        // 2. Start torrent rotation - it will handle generating missing segments
        final step8 = DateTime.now();
        _log.d('KeyExchange', '+${step8.difference(startTime).inMilliseconds}ms - First segment ready, starting torrent rotation');

        _startTorrentRotation();
        
        // 3. Trigger background generation of remaining segments
        // Only if we don't have enough pre-generated segments
        if (preGenSession == null || preGenSession.preGeneratedSegments.length < totalSegments) {
          _log.d('KeyExchange', 'Triggering background generation of remaining segments');
          _generateRemainingSegmentsInBackground();
        } else {
          _log.d('KeyExchange', 'All segments already pre-generated!');
        }
        
        // ---------------------------------------------------------------------------------------------------------------------
        
        final step9 = DateTime.now();
        _log.d('KeyExchange', '+${step9.difference(startTime).inMilliseconds}ms - FIRST QR CODE SHOULD BE VISIBLE NOW');
      } else {
        // Mode manuel: générer un segment à la fois
        _generateNextSegment();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur: $e');
    }
  }

  void _onSessionUpdate(KexSessionModel? session) {
    if (session == null) {
      _log.w('KeyExchange', 'Session is null');
      return;
    }

    _log.d('KeyExchange', '───────────────────────────────────────────────────');
    _log.d('KeyExchange', 'Role: $_role');
    _log.d('KeyExchange', 'Session ID: ${session.id}');
    _log.d('KeyExchange', 'Status: ${session.status}');
    _log.d('KeyExchange', 'Source: ${session.sourceId}');
    _log.d('KeyExchange', 'Participants: ${session.participants}');
    _log.d('KeyExchange', 'Other Participants: ${session.otherParticipants}');
    _log.d('KeyExchange', 'Current Segment Index: ${_firestoreSession?.currentSegmentIndex ?? 0}');
    _log.d('KeyExchange', 'Total Segments: ${session.totalSegments}');
    _log.d('KeyExchange', 'ScannedBy map:');


    setState(() {
      _firestoreSession = session;
    });

    // Pour le READER: si la session est terminée, finaliser et retourner à la conversation
    if (_role == KeyExchangeRole.reader && session.status == KeyExchangeStatus.completed) {
      _log.i('KeyExchange', 'Reader detected completion - finalizing');
      _log.d('KeyExchange', '───────────────────────────────────────────────────');
      _finalizeExchangeForReader();
      return;
    }

    // Pour la SOURCE: vérifier si tous les segments sont scannés par tous
    if (_role == KeyExchangeRole.source && _session != null) {
      final totalSegments = (_session is KexSessionSource) ? (_session as KexSessionSource).totalSegments : (_firestoreSession?.totalSegments ?? 0);
      _log.d('KeyExchange', 'Checking completion: checking $totalSegments segments');

      // Vérifier si tous les segments (0 à totalSegments-1) sont scannés par tous
      bool allComplete = true;
      for (int i = 0; i < totalSegments; i++) {
        final isComplete = session.allParticipantsScannedSegment(i);
        _log.d('KeyExchange', '  Segment $i complete: $isComplete');
        if (!isComplete) {
          allComplete = false;
          break;
        }
      }

      // Si tous les segments sont complets, terminer automatiquement
      if (allComplete && session.status != KeyExchangeStatus.completed) {
        _log.i('KeyExchange', 'All segments complete - auto terminating');
        _log.d('KeyExchange', '───────────────────────────────────────────────────');
        // s'assurer qu'on ne l'appelle qu'une fois, ne plus écouter les mises à jour
        _sessionSubscription?.cancel();
        _terminateKeyExchange();
        return;
      }

      // En mode torrent, ne pas changer automatiquement le QR
      // Le timer de rotation s'en charge
      if (!_torrentModeEnabled) {
        // Mode manuel: changer automatiquement de QR quand le segment courant est scanné
        if (_currentQrData != null) {
          final displayedSegmentIdx = _currentQrData!.segmentIndex;
          final allScanned = session.allParticipantsScannedSegment(displayedSegmentIdx);

          _log.d('KeyExchange', 'Manual mode - displayed segment $displayedSegmentIdx, allScanned: $allScanned');

          // Si tous ont scanné et qu'il reste des segments, passer au suivant automatiquement
          if (allScanned && ( _session is KexSessionSource ? (_session as KexSessionSource).currentSegmentIndex < totalSegments : false)) {
            _log.d('KeyExchange', 'Moving to next segment...');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _generateNextSegment();
              }
            });
          }
        }
      }
    }
    _log.d('KeyExchange', '───────────────────────────────────────────────────');
  }

  /// Finalise l'échange côté reader et navigue vers la conversation
  Future<void> _finalizeExchangeForReader() async {
    if (_session == null || _firestoreSession == null) return;

    // Eviter l'exécution concurrente (double finalisation)
    if (_isFinalizing) return;
    _isFinalizing = true;

    try {
      // Récupérer la session mise à jour pour avoir le conversationId
      final updatedSession = await _syncService.getSession(_firestoreSession!.id);
      final conversationId = updatedSession?.conversationId;

      _log.d('KeyExchange', 'Reader: conversationId from session: $conversationId');

      if (conversationId == null || conversationId.isEmpty) {
        _log.d('KeyExchange', 'Reader: No conversationId found, waiting...');
        setState(() => _errorMessage = 'En attente de la création de la conversation par la source...');
        
        // Reset flag to allow retry
        _isFinalizing = false;

        // Réessayer dans 2 secondes
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _finalizeExchangeForReader();
          }
        });
        return;
      }

      // Récupérer la conversation existante
      final conversationService = ConversationService(localUserId: _currentUserId);
      final conversation = await conversationService.getConversation(conversationId);

      if (conversation == null) {
        _log.e('KeyExchange', 'Reader: Conversation not found: $conversationId');
        setState(() => _errorMessage = 'Conversation non trouvée. Réessayez.');
        _isFinalizing = false;
        return;
      }

      SharedKey finalKey;
      
      // Vérifier si c'est une extension de clé
      final existingKey = await _keyStorageService.getKey(conversation.id);

      if (existingKey != null) {
        // KEY EXTENSION: Étendre la clé existante
        _log.d('KeyExchange', 'Reader: Loading existing key for extension...');
        _log.d('KeyExchange', 'Reader: Existing key: ${existingKey.lengthInBits} bits');

        final newKeyData = _keyExchangeService.finalizeExchange(
          _session!,
          force: true,
        );
        
        _log.d('KeyExchange', 'Reader: New key data: ${newKeyData.lengthInBits} bits');

        // Étendre la clé existante
        finalKey = existingKey.extend(newKeyData.keyData);
        
        _log.d('KeyExchange', 'Reader: Extended key: ${finalKey.lengthInBits} bits');
      } else {
        // NOUVELLE CLÉ
        finalKey = _keyExchangeService.finalizeExchange(
          _session!,
          force: true,
        );
        
        _log.d('KeyExchange', 'Reader: New key: ${finalKey.lengthInBits} bits');
      }

      // Sauvegarder la clé localement avec le même conversationId
      _log.d('KeyExchange', 'Reader: Saving shared key locally for conversation ${conversation.id}');
      final readerContrib = _firestoreSession != null
        ? [{'kexId': _firestoreSession!.id, 'startBit': (_firestoreSession!.startIndex * KeyExchangeService.segmentSizeBits), 'endBit': min(finalKey.lengthInBits, _firestoreSession!.endIndex * KeyExchangeService.segmentSizeBits)}]
        : null;
      await _keyStorageService.saveKey(conversation.id, finalKey, lastKexId: _firestoreSession?.id, kexContributions: readerContrib);
      _log.i('KeyExchange', 'Reader: Shared key saved successfully');

      // Update Firestore keyDebugInfo immediately with the new key size
      _log.d('KeyExchange', 'Reader: Updating Firestore keyDebugInfo');
      await _updateKeyDebugInfoForConversation(conversation.id, finalKey);

      // Envoyer le message pseudo chiffré
      await _sendPseudoMessage(conversation.id, finalKey);

      // NE PAS supprimer la session - c'est la source qui s'en charge
      // await _sync_service.deleteSession(_firestore_session!.id);
      _log.d('KeyExchange', 'Reader: Key exchange completed (session cleanup by source)');

      // Ensure background service is initialized and attempt a rescan so the
      // reader gets recent messages decrypted immediately. Do not block UI.
      try {
        BackgroundServiceLocator.init(localUserId: _currentUserId);
        BackgroundServiceLocator.instance.rescanConversation(conversation.id).catchError((e) {
          _log.e('KeyExchange', 'Background rescan failed: $e');
        });
      } catch (e) {
        _log.e('KeyExchange', 'Could not initialize background service: $e');
      }

      if (mounted) {
        // Navigate to summary screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => KeyExchangeSummaryScreen(
              session: _firestoreSession!,
              previousKey: existingKey,
              newKey: finalKey,
              conversation: conversation,
              currentUserId: _currentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      _log.e('KeyExchange', 'Error in _finalizeExchangeForReader: $e');
      setState(() => _errorMessage = 'Erreur: $e');
      _isFinalizing = false;
    }
  }

  void _startAsReader() {
    setState(() {
      _role = KeyExchangeRole.reader;
      _currentStep = 1;
      _isScanning = true;
      _errorMessage = null;
    });
  }

  void _generateNextSegment() {
    if (_session == null) return;

    try {
      _currentQrData = _keyExchangeService.generateNextSegment((_session as KexSessionSource));
      // Mettre la luminosité au maximum pour l'affichage du QR code
      _setMaxBrightness();
      setState(() {});
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  /// Generate remaining segments in background without blocking UI
  void _generateRemainingSegmentsInBackground() async {
    if (_session == null) return;
    
    // Defer to next event loop to let UI render first frame
    await Future.delayed(Duration.zero);
    
    // Use the cache service to generate segments, but we don't await it here
    // so it doesn't block if called from a sync context (though here it is async)
    if (_session is KexSessionSource) {
      _cacheService.pregenerateSegments((_session as KexSessionSource), _keyExchangeService).then((_) {
         _log.d('KeyExchange', 'Background generation complete');
      });
    }
  }

  /// Démarre le mode torrent: rotation automatique des QR codes
  void _startTorrentRotation() {
    _stopTorrentRotation(); // S'assurer qu'il n'y a pas de timer actif
    
    _log.d('Torrent', 'Starting rotation mode (${_torrentRotationInterval.inMilliseconds}ms per segment)');

    _torrentRotationTimer = Timer.periodic(_torrentRotationInterval, (_) {
      if (!mounted || _session == null || _firestoreSession == null) {
        _stopTorrentRotation();
        return;
      }

      // Trouver le prochain segment non-complet à afficher
      final nextSegmentIndex = _findNextIncompleteSegment();
      
      if (nextSegmentIndex == null) {
        // Tous les segments sont complets, arrêter la rotation
        _log.d('Torrent', 'All segments complete, stopping rotation');
        _stopTorrentRotation();
        return;
      }

      // Générer et afficher le segment si différent de l'actuel
      if (_currentQrData == null || _currentQrData!.segmentIndex != nextSegmentIndex) {
        _displaySegmentAtIndex(nextSegmentIndex);
        
        // AUTO-SCAN: Source marks itself as having scanned this segment
        _autoScanSourceSegment(nextSegmentIndex);
      }
    });
  }

  /// Arrête le mode torrent
  void _stopTorrentRotation() {
    if (_torrentRotationTimer != null) {
      _torrentRotationTimer!.cancel();
      _torrentRotationTimer = null;
      _log.d('Torrent', 'Rotation stopped');
    }
  }

  /// Auto-scan: Source marks itself as having scanned a segment
  Future<void> _autoScanSourceSegment(int segmentIndex) async {
    if (_session == null || _firestoreSession == null) return;
    if (_currentUserId.isEmpty) return;

    try {
      // Check if source has already scanned this segment
      if (_firestoreSession!.hasParticipantScannedSegment(_currentUserId, segmentIndex)) {
        return; // Already scanned
      }

      _log.d('AutoScan', 'Source marking segment $segmentIndex as scanned');

      // Mark in Firestore that source has scanned this segment
      await _syncService.markSegmentScanned(
        sessionId: _firestoreSession!.id,
        participantId: _currentUserId,
        segmentIndex: segmentIndex,
      );

      _log.i('AutoScan', '✓ Segment $segmentIndex marked as scanned by source');
    } catch (e) {
      _log.e('AutoScan', 'Error marking segment as scanned: $e');
    }
  }

  /// Trouve le prochain segment qui n'a pas été scanné par tous les participants
  /// Retourne null si tous les segments sont complets
  /// Vérifie aussi si on a fait un tour complet et adapte la vitesse si nécessaire
  int? _findNextIncompleteSegment() {
    if (_session == null || _firestoreSession == null) return null;

    final totalSegments = _session!.totalSegments;
    final currentDisplayed = _currentQrData?.segmentIndex ?? 0;

    // Commencer à chercher après le segment actuellement affiché (rotation circulaire)
    for (int offset = 1; offset <= totalSegments; offset++) {
      final segmentIndex = (currentDisplayed + offset) % totalSegments;
      
      // Vérifier si ce segment a été scanné par tous
      if (!_firestoreSession!.allParticipantsScannedSegment(segmentIndex)) {
        // Si on revient au segment 0, on a fait un tour complet
        if (segmentIndex == 0 && currentDisplayed != 0) {
          _checkAndAdjustRotationSpeed();
        }
        return segmentIndex;
      }
    }

    // Tous les segments sont complets
    return null;
  }

  /// Vérifie si certains participants n'ont scanné aucun segment dans le tour
  /// et augmente la vitesse de rotation si nécessaire
  void _checkAndAdjustRotationSpeed() {
    if (_firestoreSession == null) return;

    final otherParticipants = _firestoreSession!.otherParticipants;
    bool someParticipantMissedAll = false;

    // Vérifier chaque participant
    for (final participantId in otherParticipants) {
      final scannedInRound = _participantScannedInRound[participantId] ?? false;
      
      if (!scannedInRound) {
        _log.d('Torrent', 'Participant $participantId missed all segments in round');
        someParticipantMissedAll = true;
      }
      
      // Réinitialiser pour le prochain tour
      _participantScannedInRound[participantId] = false;
    }

    // Si au moins un participant a tout raté, ralentir
    if (someParticipantMissedAll) {
      final newInterval = Duration(
        milliseconds: _torrentRotationInterval.inMilliseconds + 1000
      );
      
      _log.d('Torrent', 'Some participants missed all segments, increasing interval from ${_torrentRotationInterval.inMilliseconds}ms to ${newInterval.inMilliseconds}ms');

      setState(() {
        _torrentRotationInterval = newInterval;
      });
      
      // Redémarrer le timer avec le nouveau délai
      _startTorrentRotation();
    }
  }

  /// Affiche un segment spécifique par son index
  void _displaySegmentAtIndex(int segmentIndex) {
    if (_session == null) return;

    try {
      // Recréer le QR data pour ce segment
      final startBit = segmentIndex * KeyExchangeService.segmentSizeBits;
      final endBit = min(startBit + KeyExchangeService.segmentSizeBits, _session is KexSessionSource ? (_session as KexSessionSource).totalBits : (_firestoreSession?.totalSegments ?? startBit + KeyExchangeService.segmentSizeBits));

      // Récupérer les données du segment depuis la session
      final segmentData = _session!.getSegmentData(segmentIndex);
      
      if (segmentData == null) {
        _log.d('Torrent', 'Segment $segmentIndex data not found, regenerating...');
        // Le segment n'a pas encore été généré, le générer maintenant
        if (_session is KexSessionSource) {
          _keyExchangeService.generateNextSegment((_session as KexSessionSource));
        }
        return;
      }

      setState(() {
        _currentQrData = KeySegmentQrData(
          sessionId: _session!.sessionId,
          segmentIndex: segmentIndex,
          startBit: startBit,
          endBit: endBit,
          keyData: segmentData,
        );
      });

      _log.d('Torrent', 'Displaying segment $segmentIndex');
    } catch (e) {
      _log.e('Torrent', 'Error displaying segment $segmentIndex: $e');
    }
  }

  int min(int a, int b) => a < b ? a : b;

  Future<void> _onQrScanned(String qrData) async {
    if (_currentUserId.isEmpty) return;
    if (_processingScan) return;

    _processingScan = true;

    try {
      final segment = _keyExchangeService.parseQrCode(qrData);

      _log.d('QR SCAN', 'Reader: ${_currentUserId.substring(0, 8)}...');
      _log.d('QR SCAN', 'Segment Index: ${segment.segmentIndex}');
      _log.d('QR SCAN', 'Session ID: ${segment.sessionId}');

      // Première fois qu'on scanne - créer/récupérer la session
      if (_session == null) {
        _log.d('QR SCAN', 'First scan - creating reader session');

        // Récupérer la session Firestore D'ABORD pour avoir les bonnes infos
        _firestoreSession = await _syncService.getSession(segment.sessionId);

        if (_firestoreSession == null) {
          _log.e('QR SCAN', 'ERROR: Session not found in Firestore');
          setState(() => _errorMessage = 'Session non trouvée');
          return;
        }

        _log.d('QR SCAN', 'Firestore session loaded:');
        _log.d('QR SCAN', '  - Source: ${_firestoreSession!.sourceId}');
        _log.d('QR SCAN', '  - Participants: ${_firestoreSession!.participants}');
        _log.d('QR SCAN', '  - Total segments: ${_firestoreSession!.totalSegments}');

        // Créer la session locale reader avec les infos de Firestore
        _session = _keyExchangeService.createReaderSession(
          sessionId: segment.sessionId,
          localPeerId: _currentUserId,
          peerIds: _firestoreSession!.participants,
        );

        _log.d('QR SCAN', 'Local reader session created');

        // Écouter les changements
        _sessionSubscription = _syncService
            .watchSession(segment.sessionId)
            .listen(_onSessionUpdate);
            
        _log.d('QR SCAN', 'Started watching session updates');
      }

      // Vérifier qu'on n'a pas déjà scanné ce segment
      if (_session!.hasScannedSegment(segment.segmentIndex)) {
        _log.w('QR SCAN', 'Segment ${segment.segmentIndex} already scanned, skipping');
        _log.d('QR SCAN', 'Already scanned segments: ${_firestoreSession?.scannedBy[segment.segmentIndex]}');
        // Ne pas afficher d'erreur, juste continuer à scanner
        if (mounted) {
          setState(() {
            _isScanning = true;
          });
        }
        return;
      }

      _log.i('QR SCAN', 'New segment ${segment.segmentIndex} - processing');

      // Feedback haptique
      HapticFeedback.lightImpact();

      // Enregistrer le segment localement
      _keyExchangeService.recordReadSegment(_session!, segment);
      _log.d('QR SCAN', 'Segment recorded locally');

      // Notifier Firestore que ce participant a scanné ce segment
      _log.d('QR SCAN', 'Marking segment as scanned in Firestore...');
      await _syncService.markSegmentScanned(
        sessionId: segment.sessionId,
        participantId: _currentUserId,
        segmentIndex: segment.segmentIndex,
      );

      _log.i('QR SCAN', '✅ Segment ${segment.segmentIndex} marked as scanned in Firestore');
      _log.d('QR SCAN', 'Reader progress: ${_session!.readSegmentsCount}/${(_session is KexSessionSource ? (_session as KexSessionSource).totalSegments : (_firestoreSession?.totalSegments ?? 0))} segments');

      // Check if this user has finished scanning all segments
      if (_session!.readSegmentsCount >= (_session is KexSessionSource ? (_session as KexSessionSource).totalSegments : (_firestoreSession?.totalSegments ?? 0))) {
        _log.i('QR SCAN', 'All segments scanned! Stopping camera...');
        if (mounted) {
          setState(() {
            _isScanning = false;
            _errorMessage = null;
          });
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
      
      _log.d('QR SCAN', '═══════════════════════════════════════════════════');
    } catch (e) {
      _log.e('QR SCAN', 'ERROR: $e');
      _log.d('QR SCAN', '═══════════════════════════════════════════════════');
      if (mounted) {
        final msg = e.toString();
        setState(() => _errorMessage = 'Erreur scan: ${msg.length > 50 ? msg.substring(0, 50) : msg}...');
        // Reprendre le scan après l'erreur
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
              _errorMessage = null;
            });
          }
        });
      }
    } finally {
      // Debounce simple pour éviter les doubles scans rapides
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _processingScan = false;
    }
  }

  Future<void> _finalizeExchange() async {
    if (_session == null) return;

    try {
      if (_currentUserId.isEmpty) return;

      final conversationService = ConversationService(localUserId: _currentUserId);
      
      // Utiliser la conversation existante ou en créer une nouvelle
      String conversationId;
      SharedKey finalKey;
      SharedKey? existingKey; // Track existing key for summary
      
      if (widget.existingConversationId != null) {
        // Conversation existante : vérifier si c'est une extension ou une création initiale
        conversationId = widget.existingConversationId!;
        
        _log.d('KeyExchange', 'Checking for existing key...');
        existingKey = await _keyStorageService.getKey(conversationId);

        if (existingKey != null) {
          // KEY EXTENSION: La conversation a déjà une clé
          _log.d('KeyExchange', 'Existing key found: ${existingKey.lengthInBits} bits - extending...');

          // Forcer la finalisation pour obtenir les nouveaux segments
          final newKeyData = _keyExchangeService.finalizeExchange(
            (_session as KexSessionSource),
            force: true,
          );

          _log.d('KeyExchange', 'New key data: ${newKeyData.lengthInBits} bits');

          // Étendre la clé existante avec les nouveaux bits
          finalKey = existingKey.extend(newKeyData.keyData);

          _log.d('KeyExchange', 'Extended key: ${finalKey.lengthInBits} bits');
        } else {
          // CRÉATION INITIALE: La conversation existe mais sans clé encore
          _log.d('KeyExchange', 'No existing key - creating initial key for conversation');
          _log.w('KeyExchange', 'WARNING: Extension requested but no existing key found!');
          _log.d('KeyExchange', 'This may cause decryption errors. Delete conversation and restart.');

          finalKey = _keyExchangeService.finalizeExchange(
            (_session as KexSessionSource),
            force: true,
          );

          _log.d('KeyExchange', 'Initial key created: ${finalKey.lengthInBits} bits');
        }

        // Mettre à jour la conversation avec le nouveau total de bits
        await conversationService.updateConversationKey(
          conversationId: conversationId,
          totalKeyBits: finalKey.lengthInBits,
        );
        _log.d('KeyExchange', 'Conversation updated: $conversationId');
      } else {
        // NOUVELLE CONVERSATION: Créer tout de zéro
        existingKey = null;
        finalKey = _keyExchangeService.finalizeExchange(
          (_session as KexSessionSource),
          force: true,
        );

        final conversation = await conversationService.createConversation(
          peerIds: _session != null ? _session!.peerIds : widget.peerIds,
          totalKeyBits: finalKey.lengthInBits,
        );
        conversationId = conversation.id;
        _log.d('KeyExchange', 'New conversation created: $conversationId');
      }

      // Mettre à jour la session Firestore avec le conversationId AVANT de la terminer
      if (_firestoreSession != null) {
        try {
          await _syncService.setConversationId(_firestoreSession!.id, conversationId);
          _log.d('KeyExchange', 'Session updated with conversationId');

          // Marquer la session comme terminée
          await _syncService.completeSession(_firestoreSession!.id);
          _log.d('KeyExchange', 'Session marked as completed');
        } catch (e) {
          // La session peut avoir été supprimée par le reader, ce n'est pas grave
          _log.d('KeyExchange', 'Could not update session (may have been deleted by reader): $e');
        }
      }

      // Sauvegarder la clé localement
      _log.d('KeyExchange', 'Saving shared key locally for conversation $conversationId');
      final sourceContrib = _firestoreSession != null
        ? [{'kexId': _firestoreSession!.id, 'startBit': (_firestoreSession!.startIndex * KeyExchangeService.segmentSizeBits), 'endBit': min(finalKey.lengthInBits, _firestoreSession!.endIndex * KeyExchangeService.segmentSizeBits)}]
        : null;
      await _keyStorageService.saveKey(conversationId, finalKey, lastKexId: _firestoreSession?.id, kexContributions: sourceContrib);
      _log.i('KeyExchange', 'Shared key saved successfully');

      // Update Firestore keyDebugInfo immediately with the new key size
      _log.d('KeyExchange', 'Source: Updating Firestore keyDebugInfo');
      await _updateKeyDebugInfoForConversation(conversationId, finalKey);

      // Envoyer le message pseudo chiffré
      await _sendPseudoMessage(conversationId, finalKey);

      // Initialize background service and ensure we start listening to this conversation
      try {
        BackgroundServiceLocator.init(localUserId: _currentUserId);
        // Start listening immediately and trigger a rescan in background
        BackgroundServiceLocator.instance.startForConversation(conversationId);
        BackgroundServiceLocator.instance.rescanConversation(conversationId).catchError((e) {
          _log.e('KeyExchange', 'Background rescan failed (source): $e');
        });
      } catch (e) {
        _log.e('KeyExchange', 'Could not initialize background service (source): $e');
      }

      // Supprimer la session d'échange de Firestore (nettoyage par la source)
      if (_firestoreSession != null) {
        try {
          await _syncService.deleteSession(_firestoreSession!.id);
          _log.d('KeyExchange', 'Session deleted from Firestore');
        } catch (e) {
          _log.d('KeyExchange', 'Could not delete session: $e');
        }
      }

      // Récupérer la conversation pour naviguer
      final conversation = await conversationService.getConversation(conversationId);
      if (conversation == null) {
        setState(() => _errorMessage = 'Conversation non trouvée');
        return;
      }

      // Restaurer la luminosité avant de naviguer
      await _restoreBrightness();
      
      // Arrêter le mode torrent
      _stopTorrentRotation();

      if (mounted) {
        // Navigate to summary screen instead of directly to conversation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => KeyExchangeSummaryScreen(
              session: _firestoreSession!,
              previousKey: existingKey,
              newKey: finalKey,
              conversation: conversation,
              currentUserId: _currentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      _log.e('KeyExchange', 'Error in _finalizeExchange: $e');
      setState(() => _errorMessage = 'Erreur: $e');
    }
  }

  Widget _buildKeyGenButton(String label, int sizeInBits) {
    final isSelected = _keySizeBits == sizeInBits;
    return ElevatedButton(
      onPressed: () {
        setState(() => _keySizeBits = sizeInBits);
        _startAsSource();
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
        foregroundColor: isSelected ? Colors.white : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Échange de clé'),
      ),
      body: _currentStep == 0
          ? _buildRoleSelection()
          : _role == KeyExchangeRole.source
              ? _buildSourceView()
              : _buildReaderView(),
    );
  }

  Widget _buildRoleSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.key, size: 48, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    'Création de la clé partagée',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Un appareil génère la clé et l\'affiche en QR codes.\n'
                    'Les autres appareils scannent pour recevoir la clé.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Boutons de génération de clé (4 tailles)
          Text(
            'Générer une clé',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildKeyGenButton('8 KB', 8192 * 8),
              _buildKeyGenButton('32 KB', 32768 * 8),
              _buildKeyGenButton('128 KB', 131072 * 8),
              _buildKeyGenButton('512 KB', 524288 * 8),
            ],
          ),
          
          const SizedBox(height: 24),

          // Bouton de scan
          OutlinedButton.icon(
            onPressed: _startAsReader,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Ou scanner une clé'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceView() {
    if (_currentQrData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final session = _session!;
    final firestoreSession = _firestoreSession;
    final progress = (session.currentSegmentIndex / session.totalSegments);

    // L'index du segment actuellement affiché dans le QR code
    final displayedSegmentIdx = _currentQrData!.segmentIndex;

    // Nombre de participants ayant scanné ce segment
    final scannedList = firestoreSession?.scannedBy[displayedSegmentIdx] ?? [];
    final allScanned = firestoreSession?.allParticipantsScannedSegment(displayedSegmentIdx) ?? false;

    return Column(
      children: [
        // Top bar: Progress, segment count, and stop button on one line
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).primaryColor.withAlpha(25),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Progress indicator and segment count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // List of participants who scanned current segment
                      Text(
                        'Participants: ${scannedList.isEmpty ? "Personne" : scannedList.join(", ")}', // Show names/IDs
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${displayedSegmentIdx + 1}/${session.totalSegments}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Stop button
                // IconButton(
                //   onPressed: _terminateKeyExchange,
                //   icon: const Icon(Icons.stop_circle),
                //   iconSize: 40,
                //   color: session.currentSegmentIndex >= session.totalSegments
                //       ? Colors.green
                //       : Colors.orange,
                //   tooltip: 'Terminer',
                // ),
              ],
            ),
          ),
        ),

        // QR Code - takes all remaining space
        Expanded(
          child: Container(
            color: Colors.white,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge du numéro de segment
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: allScanned ? Colors.green : Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${displayedSegmentIdx + 1}/${session.totalSegments}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          // QR Code
                          Expanded(
                            child: QrImageView(
                              data: _currentQrData!.toQrString(),
                              version: QrVersions.auto,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Bottom info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).primaryColor.withAlpha(25),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                // Show interval in seconds with one decimal (e.g. 0.6s)
                Text(
                  '🔄 ${(_torrentRotationInterval.inMilliseconds / 1000).toStringAsFixed(1)}s/code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Termine l'échange de clé (appelé par la source)
  Future<void> _terminateKeyExchange() async {
    // Arrêter le mode torrent
    _stopTorrentRotation();
    
    if (_session == null || _firestoreSession == null) {
      _log.e('TERMINATE', '❌ ERROR: _session or _firestoreSession is null');
      return;
    }

    _log.d('TERMINATE', '═══════════════════════════════════════════════════');
    _log.d('TERMINATE', '═══        TERMINATE KEY EXCHANGE              ═══');
    _log.d('TERMINATE', '═══════════════════════════════════════════════════');
    _log.d('TERMINATE', 'Source ID: ${_firestoreSession!.sourceId}');
    _log.d('TERMINATE', 'All Participants: ${_firestoreSession!.participants}');
    _log.d('TERMINATE', 'Other Participants (excluding source): ${_firestoreSession!.otherParticipants}');
    _log.d('TERMINATE', 'Current Segment Index (local): ${_session!.currentSegmentIndex}');
    _log.d('TERMINATE', 'Total Segments (planned): ${_session!.totalSegments}');
    _log.d('TERMINATE', 'ScannedBy status from Firestore:');

    _firestoreSession!.scannedBy.forEach((idx, scanners) {
      final allScanned = _firestoreSession!.allParticipantsScannedSegment(idx);
      _log.d('TERMINATE', '  Segment $idx: $scanners → ${allScanned ? "✅ COMPLETE" : "⚠️  INCOMPLETE"}');
    });

    // Le segment actuellement affiché
    final displayedSegmentIdx = _currentQrData?.segmentIndex ?? 0;
    _log.d('TERMINATE', 'Currently displayed segment: $displayedSegmentIdx');
    _log.d('TERMINATE', '');
    _log.d('TERMINATE', 'Analyzing consecutive complete segments from 0...');

    // Trouver le dernier segment scanné par tous (segments consécutifs depuis 0)
    int lastCompleteSegment = -1;
    for (int i = 0; i <= displayedSegmentIdx; i++) {
      final scannedList = _firestoreSession!.scannedBy[i] ?? [];
      final otherParticipants = _firestoreSession!.otherParticipants;

      _log.d('TERMINATE', '  ─── Segment $i ───');
      _log.d('TERMINATE', '  Expected participants: $otherParticipants (${otherParticipants.length} total)');
      _log.d('TERMINATE', '  Actually scanned by: $scannedList (${scannedList.length} total)');

      final allScanned = _firestoreSession!.allParticipantsScannedSegment(i);
      _log.d('TERMINATE', '  allParticipantsScannedSegment($i) = $allScanned');

      // Check who is missing
      final missing = otherParticipants.where((p) => !scannedList.contains(p)).toList();
      if (missing.isNotEmpty) {
        _log.d('TERMINATE', '  ⚠️  Missing: $missing');
      }

      if (allScanned) {
        lastCompleteSegment = i;
        _log.d('TERMINATE', '  ✅ Segment $i is COMPLETE');
      } else {
        _log.d('TERMINATE', '  ❌ Segment $i is INCOMPLETE - breaking consecutive chain');
        break; // Les segments doivent être consécutifs
      }
    }

    _log.d('TERMINATE', '');
    _log.d('TERMINATE', 'Result: Last consecutive complete segment = $lastCompleteSegment');

    if (lastCompleteSegment < 0) {
      // No segments were fully shared - show error
      final otherParticipants = _firestoreSession!.otherParticipants;
      final scannedBy = _firestoreSession?.scannedBy ?? {};
      final errorMsg = 'Aucun segment complet.\nParticipants attendus: $otherParticipants\nScannedBy: $scannedBy';
      _log.e('TERMINATE', '❌ ERROR: $errorMsg');
      _log.d('TERMINATE', '═══════════════════════════════════════════════════');
      setState(() => _errorMessage = errorMsg);
      return;
    }

    // Trim the session to only include segments that were successfully shared with all peers
    final segmentsToInclude = lastCompleteSegment + 1; // +1 because index is 0-based
    _log.d('TERMINATE', '✓ Will include $segmentsToInclude segments (0 to $lastCompleteSegment) in the key');

    // Update the session's total bits to only include complete segments
    final bitsPerSegment = KeyExchangeService.segmentSizeBits;
    final adjustedTotalBits = segmentsToInclude * bitsPerSegment;
    
    _log.d('TERMINATE', 'Bits adjustment:');
    _log.d('TERMINATE', '  - Original totalBits: ${(_session is KexSessionSource) ? (_session as KexSessionSource).totalBits : 'unknown'}');
    _log.d('TERMINATE', '  - Adjusted totalBits: $adjustedTotalBits');
    _log.d('TERMINATE', '  - Original totalSegments: ${(_session is KexSessionSource) ? (_session as KexSessionSource).totalSegments : 'unknown'}');
    _log.d('TERMINATE', '  - Adjusted totalSegments: $segmentsToInclude');

    // Update the Firestore session so readers know how many segments to use
    _log.d('TERMINATE', 'Updating Firestore session with adjusted counts...');
    try {
      await _syncService.updateTotalSegments(
        _firestoreSession!.id,
        segmentsToInclude,
        adjustedTotalBits,
      );
      _log.d('TERMINATE', '✅ Firestore session updated successfully');
    } catch (e) {
      _log.d('TERMINATE', '⚠️  ERROR updating Firestore session: $e');
      // Continue anyway - readers will use force flag
    }

    _log.d('TERMINATE', 'Proceeding to finalize exchange...');
    _log.d('TERMINATE', '═══════════════════════════════════════════════════');

    try {
      // Finalize exchange with the complete segments
      // The _finalizeExchange method will build a key from available segments
      await _finalizeExchange();
    } catch (e) {
      _log.e('TERMINATE', '❌ ERROR in finalization: $e');
      _log.d('TERMINATE', '═══════════════════════════════════════════════════');
      setState(() => _errorMessage = 'Erreur: $e');
    }
  }

  Widget _buildReaderView() {
    final session = _session;
    final firestoreSession = _firestoreSession;
    final segmentsRead = session?.readSegmentsCount ?? 0;
    // Utiliser totalSegments de Firestore si disponible, sinon de la session locale
    final totalSegments = firestoreSession?.totalSegments ?? (_session is KexSessionSource ? (_session as KexSessionSource).totalSegments : 0);
    final isCompleted = firestoreSession?.status == KeyExchangeStatus.completed;
    
    // Check if current user has finished scanning all segments
    final currentUserFinished = firestoreSession?.hasParticipantFinishedScanning(_currentUserId) ?? false;
    final shouldShowScanner = !currentUserFinished && !isCompleted && _isScanning;

    return Column(
      children: [
        // Barre de progression pour l'utilisateur actuel
        LinearProgressIndicator(
          value: totalSegments > 0 ? segmentsRead / totalSegments : 0,
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Segments lus: $segmentsRead / $totalSegments',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // Statut de la session
        if (firestoreSession != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green[50] : (currentUserFinished ? Colors.amber[50] : Colors.blue[50]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted ? Colors.green : (currentUserFinished ? Colors.amber : Colors.blue),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : (currentUserFinished ? Icons.check_circle_outline : Icons.sync),
                  color: isCompleted ? Colors.green : (currentUserFinished ? Colors.amber : Colors.blue),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted
                      ? 'Échange terminé! Redirection...'
                      : (currentUserFinished 
                          ? 'Vous avez terminé! En attente des autres...'
                          : 'Scanning en cours...'),
                  style: TextStyle(
                    color: isCompleted ? Colors.green[800] : (currentUserFinished ? Colors.amber[800] : Colors.blue[800]),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // Progress bars for all peers (when current user has finished)
        if (currentUserFinished && !isCompleted && firestoreSession != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progression des participants:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ..._buildPeerProgressBars(firestoreSession),
              ],
            ),
          ),

        Expanded(
          child: shouldShowScanner
              ? Stack(
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                          _onQrScanned(barcodes.first.rawValue!);
                        }
                      },
                    ),
                    // Overlay d'aide au scan
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(179),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '📷 Positionnez le QR code dans le cadre\n'
                          'Le QR change toutes les ${(_torrentRotationInterval.inMilliseconds / 1000).toStringAsFixed(1)}s',
                           textAlign: TextAlign.center,
                           style: const TextStyle(
                             color: Colors.white,
                             fontSize: 12,
                           ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCompleted ? Icons.celebration : Icons.check_circle,
                        size: 64,
                        color: isCompleted ? Colors.amber : Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isCompleted
                            ? 'Échange terminé!'
                            : (currentUserFinished
                                ? 'Scan terminé!'
                                : 'Segment $segmentsRead reçu!'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCompleted
                            ? 'Redirection vers la conversation...'
                            : (currentUserFinished
                                ? 'En attente des autres participants...'
                                : 'Attendez que la source affiche le prochain QR code'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ],
                    ],
                  ),
                ),
        ),

        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red[100],
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[900]),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildPeerProgressBars(KexSessionModel session) {
    // Get all other participants (excluding current user)
    final otherPeers = session.otherParticipants.where((p) => p != _currentUserId).toList();
    
    // Sort by progress (most finished first)
    otherPeers.sort((a, b) {
      final progressA = session.getParticipantProgress(a);
      final progressB = session.getParticipantProgress(b);
      return progressB.compareTo(progressA);
    });

    return otherPeers.map((peerId) {
      final progress = session.getParticipantProgress(peerId);
      final isFinished = session.hasParticipantFinishedScanning(peerId);
      final shortId = peerId.length > 8 ? peerId.substring(0, 8) : peerId;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFinished ? Icons.check_circle : Icons.person,
                  size: 16,
                  color: isFinished ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  shortId,
                  style: TextStyle(
                    fontSize: 12,
                    color: isFinished ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Text(
                  '$progress/${session.totalSegments}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: session.totalSegments > 0 ? progress / session.totalSegments : 0,
              backgroundColor: Colors.grey[300],
              color: isFinished ? Colors.green : Colors.blue,
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Updates Firestore keyDebugInfo for a conversation
  Future<void> _updateKeyDebugInfoForConversation(String conversationId, SharedKey key) async {
    try {
      final availableBits = key.countAvailableBits(_currentUserId);
      final totalBits = key.lengthInBits;
      
      // Find first and last available index
      int firstAvailable = -1;
      int lastAvailable = -1;
      
      for (int i = 0; i < totalBits; i++) {
        if (!key.isBitUsed(i)) {
          if (firstAvailable == -1) firstAvailable = i;
          lastAvailable = i;
        }
      }
      
      // Generate consistency hash
      final consistencyHash = '$firstAvailable|$lastAvailable|$availableBits';

      final conversationService = ConversationService(localUserId: _currentUserId);
      await conversationService.updateKeyDebugInfo(
        conversationId: conversationId,
        userId: _currentUserId,
        info: {
          'availableBits': availableBits,
          'firstAvailableIndex': firstAvailable,
          'lastAvailableIndex': lastAvailable,
          'consistencyHash': consistencyHash,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      
      _log.d('KeyExchange', 'KeyDebugInfo updated for user $_currentUserId: $availableBits bits available');
      _log.d('KeyExchange', '  First available index: $firstAvailable last available index: $lastAvailable consistencyHash: $consistencyHash');
    } catch (e) {
      _log.e('KeyExchange', 'Error updating keyDebugInfo: $e');
    }
  }
}



