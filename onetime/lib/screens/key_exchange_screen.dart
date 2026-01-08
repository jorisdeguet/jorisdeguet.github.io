import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../config/app_config.dart';
import '../models/key_exchange_session.dart';
import '../models/shared_key.dart';
import '../services/random_key_generator_service.dart';
import '../services/key_exchange_service.dart';
import '../services/key_exchange_sync_service.dart';
import '../services/key_storage_service.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import '../services/pseudo_storage_service.dart';
import '../services/crypto_service.dart';
import '../services/qr_segment_cache_service.dart';
import 'conversation_detail_screen.dart';

/// Écran d'échange de clé via QR codes.
class KeyExchangeScreen extends StatefulWidget {
  final List<String> peerIds;
  final String? conversationName;
  final String? existingConversationId;

  const KeyExchangeScreen({
    super.key,
    required this.peerIds,
    this.conversationName,
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
  
  // Session locale (pour les données de clé)
  KeyExchangeSession? _session;

  // Session Firestore (pour la synchronisation)
  KeyExchangeSessionModel? _firestoreSession;
  StreamSubscription<KeyExchangeSessionModel?>? _sessionSubscription;

  KeyExchangeRole _role = KeyExchangeRole.source;
  int _currentStep = 0;
  KeySegmentQrData? _currentQrData;
  bool _isScanning = false;
  String? _errorMessage;
  
  // Taille de clé à générer (en bits)
  int _keySizeBits = 8192 * 8; // 8 KB par défaut

  // Gestion de la luminosité
  double? _originalBrightness;
  bool _isBrightnessMaxed = false;

  // Mode torrent: rotation automatique des QR codes
  Timer? _torrentRotationTimer;
  final bool _torrentModeEnabled = true;
  Duration _torrentRotationInterval = const Duration(seconds: 1); // Commencer à 1 seconde
  
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
      debugPrint('[KeyExchange] Brightness set to maximum');
    } catch (e) {
      debugPrint('[KeyExchange] Error setting brightness: $e');
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
      debugPrint('[KeyExchange] Brightness restored');
    } catch (e) {
      debugPrint('[KeyExchange] Error restoring brightness: $e');
    }
  }

  /// Envoie un message pseudo chiffré pour que les autres participants connaissent notre pseudo
  Future<void> _sendPseudoMessage(String conversationId, SharedKey sharedKey) async {
    // Vérifier si l'échange de pseudo est activé
    if (!AppConfig.pseudoExchangeStartConversation) {
      debugPrint('[KeyExchange] Pseudo exchange disabled by config');
      return;
    }

    try {
      final myPseudo = await _pseudoService.getMyPseudo();
      if (myPseudo == null || myPseudo.isEmpty) {
        debugPrint('[KeyExchange] No pseudo to send');
        return;
      }

      // Wait 3 seconds before sending
      debugPrint('[KeyExchange] Waiting 3 seconds before sending pseudo...');
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

      debugPrint('[KeyExchange] Pseudo message sent successfully');
    } catch (e) {
      debugPrint('[KeyExchange] Error sending pseudo message: $e');
      // Ne pas bloquer si l'envoi du pseudo échoue
    }
  }

  /// Log des informations de debug pour la clé (premiers et derniers 1024 bits)
  void _logKeyDebugInfo(SharedKey key) {
    try {
      debugPrint('=== KEY DEBUG INFO ===');
      debugPrint('[KeyExchange] Total key length: ${key.lengthInBits} bits (${key.lengthInBytes} bytes)');
      
      // Extraire les premiers 1024 bits (128 bytes)
      final first1024Bits = key.lengthInBits >= 1024 
          ? key.keyData.sublist(0, 128) 
          : key.keyData;
      final first1024Base64 = base64Encode(first1024Bits);
      debugPrint('[KeyExchange] First 1024 bits (base64): $first1024Base64');
      
      // Extraire les derniers 1024 bits (128 bytes)
      if (key.lengthInBits >= 1024) {
        final lastStart = key.lengthInBytes - 128;
        final last1024Bits = key.keyData.sublist(lastStart);
        final last1024Base64 = base64Encode(last1024Bits);
        debugPrint('[KeyExchange] Last 1024 bits (base64): $last1024Base64');
      }
      
      debugPrint('=== END KEY DEBUG INFO ===');
    } catch (e) {
      debugPrint('[KeyExchange] Error logging key debug info: $e');
    }
  }

  String get _currentUserId => _authService.currentUserId ?? '';

  Future<void> _startAsSource() async {
    final startTime = DateTime.now();
    debugPrint('[KeyExchange] ${startTime.toIso8601String()} - Button pressed, starting as source');
    
    if (_currentUserId.isEmpty) return;

    setState(() => _errorMessage = null);

    try {
      final step1 = DateTime.now();
      debugPrint('[KeyExchange] +${step1.difference(startTime).inMilliseconds}ms - Calculating segments');
      
      // Calculer le nombre de segments
      final totalSegments = (_keySizeBits + KeyExchangeService.segmentSizeBits - 1) ~/
                            KeyExchangeService.segmentSizeBits;

      final step2 = DateTime.now();
      debugPrint('[KeyExchange] +${step2.difference(startTime).inMilliseconds}ms - Creating Firestore session');
      
      // Créer la session dans Firestore D'ABORD pour avoir l'ID
      _firestoreSession = await _syncService.createSession(
        sourceId: _currentUserId,
        participants: widget.peerIds,
        totalKeyBits: _keySizeBits,
        totalSegments: totalSegments,
      );

      final step3 = DateTime.now();
      debugPrint('[KeyExchange] +${step3.difference(startTime).inMilliseconds}ms - Firestore session created, creating local session');
      
      // Créer la session locale avec le MÊME ID que Firestore
      _session = _keyExchangeService.createSourceSession(
        totalBits: _keySizeBits,
        peerIds: widget.peerIds,
        sourceId: _currentUserId,
        sessionId: _firestoreSession!.id, // Utiliser l'ID Firestore
      );

      final step4 = DateTime.now();
      debugPrint('[KeyExchange] +${step4.difference(startTime).inMilliseconds}ms - Local session created, setting up listeners');

      // Écouter les changements de la session Firestore
      _sessionSubscription = _syncService
          .watchSession(_firestoreSession!.id)
          .listen(_onSessionUpdate);

      final step5 = DateTime.now();
      debugPrint('[KeyExchange] +${step5.difference(startTime).inMilliseconds}ms - Listeners setup, updating UI state');

      setState(() {
        _role = KeyExchangeRole.source;
        _currentStep = 1;
      });

      final step6 = DateTime.now();
      debugPrint('[KeyExchange] +${step6.difference(startTime).inMilliseconds}ms - UI updated, generating segments');

      // Initialiser le suivi des participants pour le mode torrent
      if (_torrentModeEnabled) {
        _participantScannedInRound = {};
        for (final participantId in _firestoreSession!.otherParticipants) {
          _participantScannedInRound[participantId] = false;
        }
        
        final step7 = DateTime.now();
        debugPrint('[KeyExchange] +${step7.difference(startTime).inMilliseconds}ms - Starting segment generation (torrent mode)');
        
        _generateAllSegments();
        
        final step8 = DateTime.now();
        debugPrint('[KeyExchange] +${step8.difference(startTime).inMilliseconds}ms - All segments generated, starting torrent rotation');
        
        _startTorrentRotation();
        
        final step9 = DateTime.now();
        debugPrint('[KeyExchange] +${step9.difference(startTime).inMilliseconds}ms - FIRST QR CODE SHOULD BE VISIBLE NOW');
      } else {
        // Mode manuel: générer un segment à la fois
        _generateNextSegment();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur: $e');
    }
  }

  void _onSessionUpdate(KeyExchangeSessionModel? session) {
    if (session == null) return;

    // Mettre à jour le suivi des participants qui ont scanné dans ce tour
    if (_role == KeyExchangeRole.source && _firestoreSession != null) {
      final oldSession = _firestoreSession!;
      
      // Comparer les scannedBy entre l'ancienne et la nouvelle session
      session.scannedBy.forEach((segmentIndex, participantIds) {
        final oldParticipantIds = oldSession.scannedBy[segmentIndex] ?? [];
        
        // Trouver les nouveaux participants qui ont scanné ce segment
        for (final participantId in participantIds) {
          if (!oldParticipantIds.contains(participantId)) {
            // Ce participant a scanné un segment dans ce tour
            _participantScannedInRound[participantId] = true;
            debugPrint('[Torrent] Participant $participantId scanned segment $segmentIndex');
          }
        }
      });
    }

    setState(() {
      _firestoreSession = session;
    });

    // Pour le READER: si la session est terminée, finaliser et retourner à la conversation
    if (_role == KeyExchangeRole.reader && session.status == KeyExchangeStatus.completed) {
      _finalizeExchangeForReader();
      return;
    }

    // Pour la SOURCE: vérifier si tous les segments sont scannés par tous
    if (_role == KeyExchangeRole.source && _session != null) {
      final totalSegments = _session!.totalSegments;

      // Vérifier si tous les segments (0 à totalSegments-1) sont scannés par tous
      bool allComplete = true;
      for (int i = 0; i < totalSegments; i++) {
        if (!session.allParticipantsScannedSegment(i)) {
          allComplete = false;
          break;
        }
      }

      // Si tous les segments sont complets, terminer automatiquement
      if (allComplete && session.status != KeyExchangeStatus.completed) {
        debugPrint('All segments scanned by all participants - auto terminating');
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

          // Si tous ont scanné et qu'il reste des segments, passer au suivant automatiquement
          if (allScanned && _session!.currentSegmentIndex < totalSegments) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _syncService.moveToNextSegment(session.id);
                _generateNextSegment();
              }
            });
          }
        }
      }
    }
  }

  /// Finalise l'échange côté reader et navigue vers la conversation
  Future<void> _finalizeExchangeForReader() async {
    if (_session == null || _firestoreSession == null) return;

    try {
      // Récupérer la session mise à jour pour avoir le conversationId
      final updatedSession = await _syncService.getSession(_firestoreSession!.id);
      final conversationId = updatedSession?.conversationId;

      debugPrint('[KeyExchange] Reader: conversationId from session: $conversationId');

      if (conversationId == null || conversationId.isEmpty) {
        debugPrint('[KeyExchange] Reader: No conversationId found, waiting...');
        setState(() => _errorMessage = 'En attente de la création de la conversation par la source...');
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
        debugPrint('[KeyExchange] Reader: Conversation not found: $conversationId');
        setState(() => _errorMessage = 'Conversation non trouvée. Réessayez.');
        return;
      }

      SharedKey finalKey;
      
      // Vérifier si c'est une extension de clé
      final existingKey = await _keyStorageService.getKey(conversation.id);
      
      if (existingKey != null) {
        // KEY EXTENSION: Étendre la clé existante
        debugPrint('[KeyExchange] Reader: Loading existing key for extension...');
        debugPrint('[KeyExchange] Reader: Existing key: ${existingKey.lengthInBits} bits');
        
        final newKeyData = _keyExchangeService.finalizeExchange(
          _session!,
          conversationName: widget.conversationName,
          force: true,
        );
        
        debugPrint('[KeyExchange] Reader: New key data: ${newKeyData.lengthInBits} bits');
        
        // Étendre la clé existante
        finalKey = existingKey.extend(newKeyData.keyData);
        
        debugPrint('[KeyExchange] Reader: Extended key: ${finalKey.lengthInBits} bits');
      } else {
        // NOUVELLE CLÉ
        finalKey = _keyExchangeService.finalizeExchange(
          _session!,
          conversationName: widget.conversationName,
          force: true,
        );
        
        debugPrint('[KeyExchange] Reader: New key: ${finalKey.lengthInBits} bits');
      }

      // Sauvegarder la clé localement avec le même conversationId
      debugPrint('[KeyExchange] Reader: Saving shared key locally for conversation ${conversation.id}');
      await _keyStorageService.saveKey(conversation.id, finalKey);
      debugPrint('[KeyExchange] Reader: Shared key saved successfully');

      // DEBUG: Afficher les premiers et derniers 1024 bits de la clé
      _logKeyDebugInfo(finalKey);

      // Envoyer le message pseudo chiffré
      await _sendPseudoMessage(conversation.id, finalKey);

      // NE PAS supprimer la session - c'est la source qui s'en charge
      // await _syncService.deleteSession(_firestoreSession!.id);
      debugPrint('[KeyExchange] Reader: Key exchange completed (session cleanup by source)');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationDetailScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _finalizeExchangeForReader: $e');
      setState(() => _errorMessage = 'Erreur: $e');
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
      _currentQrData = _keyExchangeService.generateNextSegment(_session!);
      // Mettre la luminosité au maximum pour l'affichage du QR code
      _setMaxBrightness();
      setState(() {});
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  /// Génère tous les segments à l'avance (pour le mode torrent)
  void _generateAllSegments() async {
    if (_session == null) return;

    debugPrint('[Torrent] Generating all ${_session!.totalSegments} segments...');
    
    try {
      // Pré-générer tous les segments en arrière-plan
      await _cacheService.pregenerateSegments(_session!, _keyExchangeService);
      
      // Afficher le premier segment
      _displaySegmentAtIndex(0);
      
      // Mettre la luminosité au maximum
      _setMaxBrightness();
      
      debugPrint('[Torrent] All segments generated successfully');
    } catch (e) {
      setState(() => _errorMessage = 'Erreur génération segments: $e');
      debugPrint('[Torrent] Error generating segments: $e');
    }
  }

  /// Démarre le mode torrent: rotation automatique des QR codes
  void _startTorrentRotation() {
    _stopTorrentRotation(); // S'assurer qu'il n'y a pas de timer actif
    
    debugPrint('[Torrent] Starting rotation mode (${_torrentRotationInterval.inMilliseconds}ms per segment)');
    
    _torrentRotationTimer = Timer.periodic(_torrentRotationInterval, (_) {
      if (!mounted || _session == null || _firestoreSession == null) {
        _stopTorrentRotation();
        return;
      }

      // Trouver le prochain segment non-complet à afficher
      final nextSegmentIndex = _findNextIncompleteSegment();
      
      if (nextSegmentIndex == null) {
        // Tous les segments sont complets, arrêter la rotation
        debugPrint('[Torrent] All segments complete, stopping rotation');
        _stopTorrentRotation();
        return;
      }

      // Générer et afficher le segment si différent de l'actuel
      if (_currentQrData == null || _currentQrData!.segmentIndex != nextSegmentIndex) {
        _displaySegmentAtIndex(nextSegmentIndex);
      }
    });
  }

  /// Arrête le mode torrent
  void _stopTorrentRotation() {
    if (_torrentRotationTimer != null) {
      _torrentRotationTimer!.cancel();
      _torrentRotationTimer = null;
      debugPrint('[Torrent] Rotation stopped');
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
        debugPrint('[Torrent] Participant $participantId missed all segments in round');
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
      
      debugPrint('[Torrent] Some participants missed all segments, increasing interval from ${_torrentRotationInterval.inMilliseconds}ms to ${newInterval.inMilliseconds}ms');
      
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
      final endBit = min(startBit + KeyExchangeService.segmentSizeBits, _session!.totalBits);
      
      // Récupérer les données du segment depuis la session
      final segmentData = _session!.getSegmentData(segmentIndex);
      
      if (segmentData == null) {
        debugPrint('[Torrent] Segment $segmentIndex data not found, regenerating...');
        // Le segment n'a pas encore été généré, le générer maintenant
        _keyExchangeService.generateNextSegment(_session!);
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

      debugPrint('[Torrent] Displaying segment $segmentIndex');
    } catch (e) {
      debugPrint('[Torrent] Error displaying segment $segmentIndex: $e');
    }
  }

  int min(int a, int b) => a < b ? a : b;

  Future<void> _onQrScanned(String qrData) async {
    if (_currentUserId.isEmpty) return;

    try {
      final segment = _keyExchangeService.parseQrCode(qrData);
      
      // Première fois qu'on scanne - créer/récupérer la session
      if (_session == null) {
        // Récupérer la session Firestore D'ABORD pour avoir les bonnes infos
        _firestoreSession = await _syncService.getSession(segment.sessionId);

        if (_firestoreSession == null) {
          setState(() => _errorMessage = 'Session non trouvée');
          return;
        }

        // Créer la session locale reader avec les infos de Firestore
        _session = _keyExchangeService.createReaderSession(
          sessionId: segment.sessionId,
          localPeerId: _currentUserId,
          peerIds: _firestoreSession!.participants,
          totalBits: _firestoreSession!.totalKeyBits,
        );

        // Écouter les changements
        _sessionSubscription = _syncService
            .watchSession(segment.sessionId)
            .listen(_onSessionUpdate);
      }

      // Vérifier qu'on n'a pas déjà scanné ce segment
      if (_session!.hasScannedSegment(segment.segmentIndex)) {
        debugPrint('[KeyExchange] Segment ${segment.segmentIndex} already scanned, skipping');
        // Ne pas afficher d'erreur, juste continuer à scanner
        setState(() {
          _isScanning = true;
        });
        return;
      }

      debugPrint('[KeyExchange] Scanned segment ${segment.segmentIndex}');

      // Enregistrer le segment localement
      _keyExchangeService.recordReadSegment(_session!, segment);
      
      // Notifier Firestore que ce participant a scanné ce segment
      await _syncService.markSegmentScanned(
        sessionId: segment.sessionId,
        participantId: _currentUserId,
        segmentIndex: segment.segmentIndex,
      );

      debugPrint('[KeyExchange] Segment ${segment.segmentIndex} marked as scanned in Firestore');

      // Pas besoin d'arrêter le scan - continuer immédiatement
      setState(() {
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[KeyExchange] Error scanning QR: $e');
      setState(() => _errorMessage = 'Erreur scan: ${e.toString().substring(0, 50)}...');
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
  }

  Future<void> _finalizeExchange() async {
    if (_session == null) return;

    try {
      if (_currentUserId.isEmpty) return;

      final conversationService = ConversationService(localUserId: _currentUserId);
      
      // Utiliser la conversation existante ou en créer une nouvelle
      String conversationId;
      SharedKey finalKey;
      
      if (widget.existingConversationId != null) {
        // Conversation existante : vérifier si c'est une extension ou une création initiale
        conversationId = widget.existingConversationId!;
        
        debugPrint('[KeyExchange] Checking for existing key...');
        final existingKey = await _keyStorageService.getKey(conversationId);
        
        if (existingKey != null) {
          // KEY EXTENSION: La conversation a déjà une clé
          debugPrint('[KeyExchange] Existing key found: ${existingKey.lengthInBits} bits - extending...');
          
          // Forcer la finalisation pour obtenir les nouveaux segments
          final newKeyData = _keyExchangeService.finalizeExchange(
            _session!,
            conversationName: widget.conversationName,
            force: true,
          );
          
          debugPrint('[KeyExchange] New key data: ${newKeyData.lengthInBits} bits');
          
          // Étendre la clé existante avec les nouveaux bits
          finalKey = existingKey.extend(newKeyData.keyData);
          
          debugPrint('[KeyExchange] Extended key: ${finalKey.lengthInBits} bits');
        } else {
          // CRÉATION INITIALE: La conversation existe mais sans clé encore
          debugPrint('[KeyExchange] No existing key - creating initial key for conversation');
          debugPrint('[KeyExchange] WARNING: Extension requested but no existing key found!');
          debugPrint('[KeyExchange] This may cause decryption errors. Delete conversation and restart.');
          
          finalKey = _keyExchangeService.finalizeExchange(
            _session!,
            conversationName: widget.conversationName,
            force: true,
          );
          
          debugPrint('[KeyExchange] Initial key created: ${finalKey.lengthInBits} bits');
        }
        
        // Mettre à jour la conversation avec le nouveau total de bits
        await conversationService.updateConversationKey(
          conversationId: conversationId,
          totalKeyBits: finalKey.lengthInBits,
        );
        debugPrint('[KeyExchange] Conversation updated: $conversationId');
      } else {
        // NOUVELLE CONVERSATION: Créer tout de zéro
        finalKey = _keyExchangeService.finalizeExchange(
          _session!,
          conversationName: widget.conversationName,
          force: true,
        );
        
        final conversation = await conversationService.createConversation(
          peerIds: finalKey.peerIds,
          totalKeyBits: finalKey.lengthInBits,
          name: widget.conversationName,
        );
        conversationId = conversation.id;
        debugPrint('[KeyExchange] New conversation created: $conversationId');
      }

      // Mettre à jour la session Firestore avec le conversationId AVANT de la terminer
      if (_firestoreSession != null) {
        try {
          await _syncService.setConversationId(_firestoreSession!.id, conversationId);
          debugPrint('[KeyExchange] Session updated with conversationId');

          // Marquer la session comme terminée
          await _syncService.completeSession(_firestoreSession!.id);
          debugPrint('[KeyExchange] Session marked as completed');
        } catch (e) {
          // La session peut avoir été supprimée par le reader, ce n'est pas grave
          debugPrint('[KeyExchange] Could not update session (may have been deleted by reader): $e');
        }
      }

      // Sauvegarder la clé localement
      debugPrint('[KeyExchange] Saving shared key locally for conversation $conversationId');
      await _keyStorageService.saveKey(conversationId, finalKey);
      debugPrint('[KeyExchange] Shared key saved successfully');

      // DEBUG: Afficher les premiers et derniers 1024 bits de la clé
      _logKeyDebugInfo(finalKey);

      // Envoyer le message pseudo chiffré
      await _sendPseudoMessage(conversationId, finalKey);

      // Supprimer la session d'échange de Firestore (nettoyage par la source)
      if (_firestoreSession != null) {
        try {
          await _syncService.deleteSession(_firestoreSession!.id);
          debugPrint('[KeyExchange] Session deleted from Firestore');
        } catch (e) {
          debugPrint('[KeyExchange] Could not delete session: $e');
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationDetailScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _finalizeExchange: $e');
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
    final scannedCount = scannedList.length;
    final totalOthers = firestoreSession?.otherParticipants.length ?? 1;
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
                      Text(
                        'Segments scannés: $scannedCount/$totalOthers',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                IconButton(
                  onPressed: _terminateKeyExchange,
                  icon: const Icon(Icons.stop_circle),
                  iconSize: 40,
                  color: session.currentSegmentIndex >= session.totalSegments
                      ? Colors.green
                      : Colors.orange,
                  tooltip: 'Terminer',
                ),
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
                Text(
                  '🔄 ${_torrentRotationInterval.inSeconds}s/code',
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
      debugPrint('ERROR: _session or _firestoreSession is null');
      return;
    }

    debugPrint('=== TERMINATE KEY EXCHANGE ===');
    debugPrint('sourceId: ${_firestoreSession!.sourceId}');
    debugPrint('participants: ${_firestoreSession!.participants}');
    debugPrint('otherParticipants: ${_firestoreSession!.otherParticipants}');
    debugPrint('scannedBy: ${_firestoreSession!.scannedBy}');
    debugPrint('currentSegmentIndex (session): ${_session!.currentSegmentIndex}');
    debugPrint('totalSegments: ${_session!.totalSegments}');

    // Le segment actuellement affiché
    final displayedSegmentIdx = _currentQrData?.segmentIndex ?? 0;
    debugPrint('displayedSegmentIdx: $displayedSegmentIdx');

    // Trouver le dernier segment scanné par tous (segments consécutifs depuis 0)
    int lastCompleteSegment = -1;
    for (int i = 0; i <= displayedSegmentIdx; i++) {
      final scannedList = _firestoreSession!.scannedBy[i] ?? [];
      final otherParticipants = _firestoreSession!.otherParticipants;

      debugPrint('Segment $i: scannedBy=$scannedList, otherParticipants=$otherParticipants');

      final allScanned = _firestoreSession!.allParticipantsScannedSegment(i);
      debugPrint('Segment $i allParticipantsScannedSegment: $allScanned');

      if (allScanned) {
        lastCompleteSegment = i;
      } else {
        debugPrint('Segment $i NOT complete - breaking loop');
        break; // Les segments doivent être consécutifs
      }
    }

    debugPrint('lastCompleteSegment: $lastCompleteSegment');
    debugPrint('=== END DEBUG ===');

    if (lastCompleteSegment < 0) {
      // Afficher plus de détails sur l'erreur
      final otherParticipants = _firestoreSession!.otherParticipants;
      final scannedBy = _firestoreSession!.scannedBy;
      final errorMsg = 'Aucun segment complet.\nParticipants attendus: $otherParticipants\nScannedBy: $scannedBy';
      debugPrint('ERROR: $errorMsg');
      setState(() => _errorMessage = errorMsg);
      return;
    }

    try {
      // Ne PAS marquer comme terminée ici - on le fera dans _finalizeExchange
      // après avoir créé la conversation et défini le conversationId
      // await _syncService.completeSession(_firestoreSession!.id);

      // Finaliser l'échange (créera la conversation et marquera comme terminée)
      await _finalizeExchange();
    } catch (e) {
      debugPrint('ERROR in _terminateKeyExchange: $e');
      setState(() => _errorMessage = 'Erreur: $e');
    }
  }

  Widget _buildReaderView() {
    final session = _session;
    final firestoreSession = _firestoreSession;
    final segmentsRead = session?.readSegmentsCount ?? 0;
    // Utiliser totalSegments de Firestore si disponible, sinon de la session locale
    final totalSegments = firestoreSession?.totalSegments ?? session?.totalSegments ?? 0;
    final isCompleted = firestoreSession?.status == KeyExchangeStatus.completed;

    return Column(
      children: [
        // Barre de progression
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
              color: isCompleted ? Colors.green[50] : Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted ? Colors.green : Colors.blue,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.sync,
                  color: isCompleted ? Colors.green : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted
                      ? 'Échange terminé! Redirection...'
                      : 'Scanning en cours...',
                  style: TextStyle(
                    color: isCompleted ? Colors.green[800] : Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: _isScanning
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
                          'Le QR change toutes les secondes',
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
                            : 'Segment $segmentsRead reçu!',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCompleted
                            ? 'Redirection vers la conversation...'
                            : 'Attendez que la source affiche le prochain QR code',
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
}
