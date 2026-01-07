import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:screen_brightness/screen_brightness.dart';

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
  static const Duration _torrentRotationInterval = Duration(milliseconds: 100);

  final List<int> _keySizeOptions = [
    1024 * 2,   // 2 segments (pour tests rapides)
    1024 * 8,   // 1 KB
    8192 * 8,   // 8 KB
    32768 * 8,  // 32 KB
    131072 * 8, // 128 KB
    524288 * 8, // 512 KB
  ];

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
    try {
      final myPseudo = await _pseudoService.getMyPseudo();
      if (myPseudo == null || myPseudo.isEmpty) {
        debugPrint('[KeyExchange] No pseudo to send');
        return;
      }

      final pseudoMessage = PseudoExchangeMessage(
        oderId: _currentUserId,
        pseudo: myPseudo,
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

  String get _currentUserId => _authService.currentUserId ?? '';

  Future<void> _startAsSource() async {
    if (_currentUserId.isEmpty) return;

    setState(() => _errorMessage = null);

    try {
      // Calculer le nombre de segments
      final totalSegments = (_keySizeBits + KeyExchangeService.segmentSizeBits - 1) ~/
                            KeyExchangeService.segmentSizeBits;

      // Créer la session dans Firestore D'ABORD pour avoir l'ID
      _firestoreSession = await _syncService.createSession(
        sourceId: _currentUserId,
        participants: widget.peerIds,
        totalKeyBits: _keySizeBits,
        totalSegments: totalSegments,
      );

      // Créer la session locale avec le MÊME ID que Firestore
      _session = _keyExchangeService.createSourceSession(
        totalBits: _keySizeBits,
        peerIds: widget.peerIds,
        sourceId: _currentUserId,
        sessionId: _firestoreSession!.id, // Utiliser l'ID Firestore
      );

      // Écouter les changements de la session Firestore
      _sessionSubscription = _syncService
          .watchSession(_firestoreSession!.id)
          .listen(_onSessionUpdate);

      setState(() {
        _role = KeyExchangeRole.source;
        _currentStep = 1;
      });

      // En mode torrent, générer TOUS les segments à l'avance
      if (_torrentModeEnabled) {
        _generateAllSegments();
        _startTorrentRotation();
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
      // Construire la clé avec les segments reçus (force car vérification via Firestore)
      final sharedKey = _keyExchangeService.finalizeExchange(
        _session!,
        conversationName: widget.conversationName,
        force: true,
      );

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

      // Sauvegarder la clé localement avec le même conversationId
      debugPrint('[KeyExchange] Reader: Saving shared key locally for conversation ${conversation.id}');
      await _keyStorageService.saveKey(conversation.id, sharedKey);
      debugPrint('[KeyExchange] Reader: Shared key saved successfully');

      // Envoyer le message pseudo chiffré
      await _sendPseudoMessage(conversation.id, sharedKey);

      // Supprimer la session d'échange de Firestore (nettoyage par le reader)
      await _syncService.deleteSession(_firestoreSession!.id);
      debugPrint('[KeyExchange] Reader: Key exchange session deleted from Firestore');

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
  void _generateAllSegments() {
    if (_session == null) return;

    debugPrint('[Torrent] Generating all ${_session!.totalSegments} segments...');
    
    try {
      // Générer tous les segments
      for (int i = 0; i < _session!.totalSegments; i++) {
        _keyExchangeService.generateNextSegment(_session!);
      }
      
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
  int? _findNextIncompleteSegment() {
    if (_session == null || _firestoreSession == null) return null;

    final totalSegments = _session!.totalSegments;
    final currentDisplayed = _currentQrData?.segmentIndex ?? 0;

    // Commencer à chercher après le segment actuellement affiché (rotation circulaire)
    for (int offset = 1; offset <= totalSegments; offset++) {
      final segmentIndex = (currentDisplayed + offset) % totalSegments;
      
      // Vérifier si ce segment a été scanné par tous
      if (!_firestoreSession!.allParticipantsScannedSegment(segmentIndex)) {
        return segmentIndex;
      }
    }

    // Tous les segments sont complets
    return null;
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
        setState(() {
          _errorMessage = 'Segment déjà scanné, attendez le suivant...';
          _isScanning = true;
        });
        return;
      }

      // Enregistrer le segment localement
      _keyExchangeService.recordReadSegment(_session!, segment);
      
      // Notifier Firestore que ce participant a scanné ce segment
      await _syncService.markSegmentScanned(
        sessionId: segment.sessionId,
        participantId: _currentUserId,
        segmentIndex: segment.segmentIndex,
      );

      setState(() {
        _isScanning = false;
        _errorMessage = null;
      });

      // Continuer à scanner après une courte pause
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _firestoreSession?.status != KeyExchangeStatus.completed) {
          setState(() => _isScanning = true);
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Erreur: $e');
      // Reprendre le scan après l'erreur
      Future.delayed(const Duration(seconds: 2), () {
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
      // Forcer la finalisation car la vérification est faite via Firestore
      final sharedKey = _keyExchangeService.finalizeExchange(
        _session!,
        conversationName: widget.conversationName,
        force: true,
      );

      if (_currentUserId.isEmpty) return;

      final conversationService = ConversationService(localUserId: _currentUserId);
      
      // Utiliser la conversation existante ou en créer une nouvelle
      String conversationId;
      if (widget.existingConversationId != null) {
        // Mettre à jour la conversation existante avec les bits de clé
        conversationId = widget.existingConversationId!;
        await conversationService.updateConversationKey(
          conversationId: conversationId,
          totalKeyBits: sharedKey.lengthInBits,
        );
        debugPrint('[KeyExchange] Existing conversation updated: $conversationId');
      } else {
        // Créer une nouvelle conversation
        final conversation = await conversationService.createConversation(
          peerIds: sharedKey.peerIds,
          totalKeyBits: sharedKey.lengthInBits,
          name: widget.conversationName,
        );
        conversationId = conversation.id;
        debugPrint('[KeyExchange] New conversation created: $conversationId');
      }

      // Mettre à jour la session Firestore avec le conversationId AVANT de la terminer
      if (_firestoreSession != null) {
        await _syncService.setConversationId(_firestoreSession!.id, conversationId);
        debugPrint('[KeyExchange] Session updated with conversationId');

        // Marquer la session comme terminée
        await _syncService.completeSession(_firestoreSession!.id);
        debugPrint('[KeyExchange] Session marked as completed');
      }

      // Sauvegarder la clé localement
      debugPrint('[KeyExchange] Saving shared key locally for conversation $conversationId');
      await _keyStorageService.saveKey(conversationId, sharedKey);
      debugPrint('[KeyExchange] Shared key saved successfully');

      // Envoyer le message pseudo chiffré
      await _sendPseudoMessage(conversationId, sharedKey);

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

          // Sélection de la taille de clé
          Text(
            'Taille de la clé',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _keySizeBits,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.data_usage),
            ),
            items: _keySizeOptions.map((size) {
              final segments = (size + KeyExchangeService.segmentSizeBits - 1) ~/ KeyExchangeService.segmentSizeBits;
              final kb = size ~/ 8 ~/ 1024;
              final label = segments <= 2
                  ? '🧪 TEST: $segments seg.'
                  : '$kb KB ($segments seg.)';
              return DropdownMenuItem(
                value: size,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _keySizeBits = value);
              }
            },
          ),
          const SizedBox(height: 32),

          // Boutons de rôle
          ElevatedButton.icon(
            onPressed: _startAsSource,
            icon: const Icon(Icons.qr_code),
            label: const Text('Générer la clé (afficher QR)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _startAsReader,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner la clé'),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progression globale
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text(
            'Segment ${session.currentSegmentIndex} / ${session.totalSegments}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Statut des participants pour le segment affiché
          if (firestoreSession != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: allScanned ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: allScanned ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        allScanned ? Icons.check_circle : Icons.hourglass_empty,
                        color: allScanned ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        allScanned
                            ? 'Tous les participants ont scanné!'
                            : 'Segment $displayedSegmentIdx - Scannés: $scannedCount / $totalOthers',
                        style: TextStyle(
                          color: allScanned ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (scannedList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Participants: ${scannedList.join(", ")}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),

          // QR Code avec indicateur de segment
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge du numéro de segment (mode torrent)
                    if (_torrentModeEnabled)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: allScanned ? Colors.green : Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${displayedSegmentIdx + 1}/${session.totalSegments}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    QrImageView(
                      data: _currentQrData!.toQrString(),
                      version: QrVersions.auto,
                      size: 280,
                      errorCorrectionLevel: QrErrorCorrectLevel.L,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ID de session pour les participants
          if (firestoreSession != null)
            Text(
              'Session: ${firestoreSession.id.substring(0, 20)}...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 8),

          // Instructions
          Text(
            _torrentModeEnabled
                ? '🔄 Mode Torrent: rotation automatique tous les ${_torrentRotationInterval.inMilliseconds}ms\nLe QR affiche les segments non-complets'
                : 'Faites scanner ce QR code par les autres appareils\nLe QR change automatiquement quand tous ont scanné',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Bouton Terminer (toujours visible)
          ElevatedButton.icon(
            onPressed: _terminateKeyExchange,
            icon: const Icon(Icons.stop),
            label: Text(
              session.currentSegmentIndex >= session.totalSegments
                  ? 'Terminer l\'échange'
                  : 'Terminer maintenant (${session.currentSegmentIndex}/${session.totalSegments} segments)',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: session.currentSegmentIndex >= session.totalSegments
                  ? Colors.green
                  : Colors.orange,
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
      // Marquer la session comme terminée dans Firestore
      await _syncService.completeSession(_firestoreSession!.id);

      // Finaliser l'échange
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
                      : 'En attente du prochain segment...',
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
              ? MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      _onQrScanned(barcodes.first.rawValue!);
                    }
                  },
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
