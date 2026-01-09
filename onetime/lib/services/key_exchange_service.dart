import 'dart:convert';
import 'dart:typed_data';

import '../models/shared_key.dart';
import 'random_key_generator_service.dart';

/// Service pour l'échange local de clés entre appareils via QR code.
/// 
/// Protocole d'échange:
/// 1. Un appareil (source) génère et affiche les bits de clé en QR codes
/// 2. Les autres appareils (lecteurs) scannent les QR codes
/// 3. Les lecteurs confirment via réseau (Bluetooth/WiFi/Cloud) les indices lus
/// 4. Les bits de clé ne transitent jamais sur le réseau
class KeyExchangeService {
  final RandomKeyGeneratorService _keyGenerator;
  
  /// Taille d'un segment de clé en bits pour un QR code
  static const int segmentSizeBits = 8192; // 1024 octets
  
  /// Taille maximale d'un QR code en bits
  static const int maxQrCodeBits = 23200;

  KeyExchangeService(this._keyGenerator);

  /// Crée une nouvelle session d'échange de clé (côté source).
  /// 
  /// [totalBits] - Taille totale de la clé à partager
  /// [peerIds] - Liste des IDs des pairs qui recevront la clé
  /// [sessionId] - ID de session optionnel (si non fourni, un ID est généré)
  /// [preGeneratedSegments] - Segments déjà générés à inclure
  KeyExchangeSession createSourceSession({
    required int totalBits,
    required List<String> peerIds,
    required String sourceId,
    String? sessionId,
    List<KeySegmentQrData>? preGeneratedSegments,
  }) {
    // Inclure le source dans la liste des peers
    final allPeers = [sourceId, ...peerIds]..sort();
    
    final session = KeyExchangeSession(
      sessionId: sessionId ?? _generateSessionId(),
      role: KeyExchangeRole.source,
      totalBits: totalBits,
      peerIds: allPeers,
      localPeerId: sourceId,
    );

    // Injecter les segments pré-générés si disponibles
    if (preGeneratedSegments != null) {
      for (final segment in preGeneratedSegments) {
        // Attention: il faut s'assurer que l'ID de session correspond
        // Si les segments viennent d'une pré-génération avec un ID différent,
        // on doit recréer le QR data avec le bon ID de session final
        if (segment.sessionId != session.sessionId) {
          // On garde les données de clé mais on met à jour l'ID de session
          final updatedSegment = KeySegmentQrData(
            sessionId: session.sessionId,
            segmentIndex: segment.segmentIndex,
            startBit: segment.startBit,
            endBit: segment.endBit,
            keyData: segment.keyData,
          );
          // On injecte directement dans la session sans régénérer
          _injectSegmentIntoSession(session, updatedSegment);
        } else {
          _injectSegmentIntoSession(session, segment);
        }
      }
    }

    return session;
  }

  /// Injecte un segment manuellement dans la session (usage interne pour pré-génération)
  void _injectSegmentIntoSession(KeyExchangeSession session, KeySegmentQrData segment) {
    session.addSegmentData(segment.startBit, segment.keyData);
  }

  /// Crée une session d'échange de clé (côté lecteur).
  /// 
  /// [sessionId] - ID de la session partagé par la source
  /// [localPeerId] - ID local de ce lecteur
  KeyExchangeSession createReaderSession({
    required String sessionId,
    required String localPeerId,
    required List<String> peerIds,
    required int totalBits,
  }) {
    return KeyExchangeSession(
      sessionId: sessionId,
      role: KeyExchangeRole.reader,
      totalBits: totalBits,
      peerIds: peerIds,
      localPeerId: localPeerId,
    );
  }

  /// Génère le prochain segment de clé à afficher (côté source).
  KeySegmentQrData generateNextSegment(KeyExchangeSession session) {
    if (session.role != KeyExchangeRole.source) {
      throw StateError('Only source can generate segments');
    }
    
    // Capturer l'index AVANT de modifier la session
    final segmentIndex = session.currentSegmentIndex;
    final startBit = segmentIndex * segmentSizeBits;
    final endBit = min(startBit + segmentSizeBits, session.totalBits);
    
    if (startBit >= session.totalBits) {
      throw StateError('All segments have been generated');
    }
    
    // Générer les bits aléatoires pour ce segment
    final segmentBits = endBit - startBit;
    final keyData = _keyGenerator.generateKey(segmentBits);
    
    // Stocker le segment dans la session (ceci incrémente currentSegmentIndex)
    session.addSegmentData(startBit, keyData);
    
    return KeySegmentQrData(
      sessionId: session.sessionId,
      segmentIndex: segmentIndex, // Utiliser l'index capturé avant l'incrémentation
      startBit: startBit,
      endBit: endBit,
      keyData: keyData,
    );
  }

  /// Parse un QR code contenant un segment de clé (côté lecteur).
  KeySegmentQrData parseQrCode(String qrData) {
    return KeySegmentQrData.fromQrString(qrData);
  }

  /// Enregistre un segment lu depuis un QR code (côté lecteur).
  void recordReadSegment(KeyExchangeSession session, KeySegmentQrData segment) {
    if (session.role != KeyExchangeRole.reader) {
      throw StateError('Only readers record segments');
    }
    
    session.addSegmentData(segment.startBit, segment.keyData);
    session.markSegmentAsRead(segment.segmentIndex);
  }

  /// Génère la confirmation d'un segment lu.
  /// Contient SEULEMENT l'index, jamais les bits de clé.
  KeySegmentConfirmation createReadConfirmation(
    KeyExchangeSession session,
    int segmentIndex,
  ) {
    return KeySegmentConfirmation(
      sessionId: session.sessionId,
      peerId: session.localPeerId,
      segmentIndex: segmentIndex,
      timestamp: DateTime.now(),
    );
  }

  /// Enregistre une confirmation reçue d'un lecteur (côté source).
  void recordConfirmation(
    KeyExchangeSession session,
    KeySegmentConfirmation confirmation,
  ) {
    session.markPeerHasSegment(confirmation.peerId, confirmation.segmentIndex);
  }

  /// Vérifie si tous les peers ont lu tous les segments.
  bool isExchangeComplete(KeyExchangeSession session) {
    return session.isComplete;
  }

  /// Finalise l'échange et crée la clé partagée.
   /// [force] permet de forcer la finalisation même si tous les peers n'ont pas confirmé localement
  /// (utile quand la vérification est faite via Firestore)
  SharedKey finalizeExchange(KeyExchangeSession session, {String? conversationName, bool force = false}) {
    if (!force && !session.isComplete && session.role == KeyExchangeRole.source) {
      throw StateError('Exchange is not complete, not all peers confirmed');
    }
    
    return session.buildSharedKey(conversationName: conversationName);
  }

  /// Permet d'agrandir une clé existante avec de nouveaux segments.
  KeyExtensionSession createExtensionSession({
    required SharedKey existingKey,
    required int additionalBits,
  }) {
    return KeyExtensionSession(
      sessionId: _generateSessionId(),
      existingKey: existingKey,
      additionalBits: additionalBits,
    );
  }

  String _generateSessionId() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'session_$random';
  }

  int min(int a, int b) => a < b ? a : b;
}

/// Rôle dans l'échange de clé
enum KeyExchangeRole {
  /// Source qui génère et affiche les QR codes
  source,
  
  /// Lecteur qui scanne les QR codes
  reader,
}

/// Session d'échange de clé en cours
class KeyExchangeSession {
  final String sessionId;
  final KeyExchangeRole role;
  final int totalBits;
  final List<String> peerIds;
  final String localPeerId;
  
  /// Segments de clé déjà générés/lus (index -> données)
  final Map<int, Uint8List> _segmentData = {};
  
  /// Segments lus par chaque peer (peerId -> set de segmentIndex)
  final Map<String, Set<int>> _peerReadSegments = {};
  
  /// Index du segment courant (côté source)
  int _currentSegmentIndex = 0;

  KeyExchangeSession({
    required this.sessionId,
    required this.role,
    required this.totalBits,
    required this.peerIds,
    required this.localPeerId,
  }) {
    for (final peer in peerIds) {
      _peerReadSegments[peer] = {};
    }
  }

  int get currentSegmentIndex => _currentSegmentIndex;
  
  /// Nombre de segments lus (pour le reader)
  int get readSegmentsCount => _peerReadSegments[localPeerId]?.length ?? 0;

  int get totalSegments => (totalBits + KeyExchangeService.segmentSizeBits - 1) ~/
                           KeyExchangeService.segmentSizeBits;

  /// Accède aux données d'un segment par son index (pour le mode torrent)
  Uint8List? getSegmentData(int segmentIndex) => _segmentData[segmentIndex];

  void addSegmentData(int startBit, Uint8List data) {
    final segmentIndex = startBit ~/ KeyExchangeService.segmentSizeBits;
    _segmentData[segmentIndex] = data;
    if (role == KeyExchangeRole.source) {
      _currentSegmentIndex = segmentIndex + 1;
      // La source a automatiquement tous les segments qu'elle génère
      _peerReadSegments[localPeerId]?.add(segmentIndex);
    }
  }

  void markSegmentAsRead(int segmentIndex) {
    _peerReadSegments[localPeerId]?.add(segmentIndex);
    // Pour le reader, mettre à jour currentSegmentIndex
    if (role == KeyExchangeRole.reader) {
      _currentSegmentIndex = _peerReadSegments[localPeerId]?.length ?? 0;
    }
  }

  /// Vérifie si le participant local a déjà scanné un segment donné
  bool hasScannedSegment(int segmentIndex) {
    return _peerReadSegments[localPeerId]?.contains(segmentIndex) ?? false;
  }

  void markPeerHasSegment(String peerId, int segmentIndex) {
    _peerReadSegments[peerId]?.add(segmentIndex);
  }

  /// Vérifie si l'échange est complet
  bool get isComplete {
    for (final peer in peerIds) {
      final readSegments = _peerReadSegments[peer] ?? {};
      if (readSegments.length < totalSegments) {
        return false;
      }
    }
    return true;
  }

  /// Construit la clé partagée finale
  SharedKey buildSharedKey({String? conversationName}) {
    // Assembler tous les segments dans l'ordre
    final sortedIndexes = _segmentData.keys.toList()..sort();
    
    // Calculer la taille totale
    int totalBytes = 0;
    for (final index in sortedIndexes) {
      totalBytes += _segmentData[index]!.length;
    }
    
    // Assembler la clé
    final keyData = Uint8List(totalBytes);
    int offset = 0;
    for (final index in sortedIndexes) {
      final segment = _segmentData[index]!;
      keyData.setRange(offset, offset + segment.length, segment);
      offset += segment.length;
    }
    
    return SharedKey(
      id: sessionId,
      keyData: keyData,
      peerIds: List.from(peerIds),
      conversationName: conversationName,
    );
  }

  /// Retourne les peers qui n'ont pas encore confirmé un segment
  List<String> getPeersMissingSegment(int segmentIndex) {
    return peerIds.where((peer) {
      return !(_peerReadSegments[peer]?.contains(segmentIndex) ?? false);
    }).toList();
  }
}

/// Données d'un segment de clé pour QR code
class KeySegmentQrData {
  final String sessionId;
  final int segmentIndex;
  final int startBit;
  final int endBit;
  final Uint8List keyData;

  KeySegmentQrData({
    required this.sessionId,
    required this.segmentIndex,
    required this.startBit,
    required this.endBit,
    required this.keyData,
  });

  /// Convertit en chaîne pour QR code
  String toQrString() {
    final json = {
      's': sessionId,
      'i': segmentIndex,
      'a': startBit,
      'b': endBit,
      'k': base64Encode(keyData),
    };
    return jsonEncode(json);
  }

  /// Parse depuis une chaîne QR
  factory KeySegmentQrData.fromQrString(String qrString) {
    final json = jsonDecode(qrString) as Map<String, dynamic>;
    return KeySegmentQrData(
      sessionId: json['s'] as String,
      segmentIndex: json['i'] as int,
      startBit: json['a'] as int,
      endBit: json['b'] as int,
      keyData: base64Decode(json['k'] as String),
    );
  }

  /// Taille estimée en caractères pour le QR
  int get estimatedQrSize => toQrString().length;
}

/// Confirmation de lecture d'un segment (envoyée sur le réseau)
class KeySegmentConfirmation {
  final String sessionId;
  final String peerId;
  final int segmentIndex;
  final DateTime timestamp;

  KeySegmentConfirmation({
    required this.sessionId,
    required this.peerId,
    required this.segmentIndex,
    required this.timestamp,
  });

  /// Sérialise pour envoi réseau (NE CONTIENT PAS les bits de clé)
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'peerId': peerId,
      'segmentIndex': segmentIndex,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory KeySegmentConfirmation.fromJson(Map<String, dynamic> json) {
    return KeySegmentConfirmation(
      sessionId: json['sessionId'] as String,
      peerId: json['peerId'] as String,
      segmentIndex: json['segmentIndex'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Session d'extension de clé existante
class KeyExtensionSession {
  final String sessionId;
  final SharedKey existingKey;
  final int additionalBits;
  final List<Uint8List> newSegments = [];

  KeyExtensionSession({
    required this.sessionId,
    required this.existingKey,
    required this.additionalBits,
  });

  /// Ajoute un nouveau segment
  void addSegment(Uint8List segment) {
    newSegments.add(segment);
  }

  /// Vérifie si assez de bits ont été ajoutés
  bool get isComplete {
    int totalNewBits = 0;
    for (final seg in newSegments) {
      totalNewBits += seg.length * 8;
    }
    return totalNewBits >= additionalBits;
  }

  /// Crée la clé étendue
  SharedKey buildExtendedKey() {
    // Concaténer tous les nouveaux segments
    int totalNewBytes = 0;
    for (final seg in newSegments) {
      totalNewBytes += seg.length;
    }
    
    final additionalData = Uint8List(totalNewBytes);
    int offset = 0;
    for (final seg in newSegments) {
      additionalData.setRange(offset, offset + seg.length, seg);
      offset += seg.length;
    }
    
    return existingKey.extend(additionalData);
  }
}
