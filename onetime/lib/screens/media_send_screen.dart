import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/encrypted_message.dart';
import '../models/shared_key.dart';
import '../services/media_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
import '../services/conversation_service.dart';
import '../services/message_storage_service.dart';
import '../services/format_service.dart';

/// Écran complet pour l'envoi d'un média avec preview et debug
class MediaSendScreen extends StatefulWidget {
  final MediaPickResult mediaResult;
  final SharedKey sharedKey;
  final String conversationId;
  final String currentUserId;

  const MediaSendScreen({
    super.key,
    required this.mediaResult,
    required this.sharedKey,
    required this.conversationId,
    required this.currentUserId,
  });

  @override
  State<MediaSendScreen> createState() => _MediaSendScreenState();
}

class _MediaSendScreenState extends State<MediaSendScreen> {
  final MediaService _mediaService = MediaService();
  final List<String> _debugLogs = [];
  bool _isProcessing = false;
  bool _isComplete = false;
  String? _errorMessage;
  ImageQuality _selectedQuality = ImageQuality.medium;
  MediaPickResult? _currentResult;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.mediaResult;
    _addLog('Média sélectionné: ${widget.mediaResult.fileName}');
    _addLog('Taille originale: ${FormatService.formatBytes(widget.mediaResult.data.length)}');
    _calculateKeyUsage();
  }

  void _addLog(String message) {
    setState(() {
      _debugLogs.add('[${DateTime.now().toIso8601String().substring(11, 23)}] $message');
    });
    if (AppConfig.verboseCryptoLogs) {
      debugPrint('[MediaSend] $message');
    }
  }

  void _calculateKeyUsage() {
    final availableBits = widget.sharedKey.countAvailableBits(widget.currentUserId);
    final neededBits = _currentResult!.data.length * 8;
    final usagePercent = (neededBits / availableBits * 100).toStringAsFixed(1);
    
    _addLog('Clé disponible: ${_mediaService.formatKeyBits(availableBits)}');
    _addLog('Bits nécessaires: ${_mediaService.formatKeyBits(neededBits)}');
    _addLog('Utilisation: $usagePercent%');
  }

  Future<void> _changeQuality(ImageQuality quality) async {
    if (widget.mediaResult.contentType != MessageContentType.image) return;

    setState(() {
      _selectedQuality = quality;
    });

    _addLog('Changement de qualité sélectionnée: ${quality.label}');
    _addLog('Note: Le redimensionnement sera fait lors de l\'envoi');
  }

  Future<void> _sendMedia() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    _addLog('=== DÉBUT DU CHIFFREMENT ===');

    try {
      final startTime = DateTime.now();
      
      final cryptoService = CryptoService(localPeerId: widget.currentUserId);
      final keyStorageService = KeyStorageService();
      final conversationService = ConversationService(localUserId: widget.currentUserId);
      final messageStorage = MessageStorageService();

      _addLog('Chiffrement en cours...');
      
      final result = cryptoService.encryptBinary(
        data: _currentResult!.data,
        sharedKey: widget.sharedKey,
        contentType: _currentResult!.contentType,
        fileName: _currentResult!.fileName,
        mimeType: _currentResult!.mimeType,
      );

      final encryptTime = DateTime.now().difference(startTime).inMilliseconds;
      _addLog('Chiffré en ${encryptTime}ms');
      _addLog('Données chiffrées: ${FormatService.formatBytes(result.message.ciphertext.length)}');
      _addLog('Segments utilisés: ${result.message.keySegments.length}');

      // Store decrypted message locally FIRST
      _addLog('Sauvegarde locale...');
      await messageStorage.saveDecryptedMessage(
        conversationId: widget.conversationId,
        message: DecryptedMessageData(
          id: result.message.id,
          senderId: result.message.senderId,
          createdAt: result.message.createdAt,
          contentType: result.message.contentType,
          binaryContent: _currentResult!.data,
          fileName: _currentResult!.fileName,
          mimeType: _currentResult!.mimeType,
          isCompressed: result.message.isCompressed,
          deleteAfterRead: result.message.deleteAfterRead,
        ),
      );

      _addLog('Mise à jour du bitmap de bits utilisés...');
      await keyStorageService.updateUsedBits(
        widget.conversationId,
        result.usedSegment.startBit,
        result.usedSegment.endBit,
      );

      final messagePreview = _currentResult!.contentType == MessageContentType.image
          ? '📷 Image'
          : '📎 ${_currentResult!.fileName}';

      _addLog('Envoi vers Firestore...');
      await conversationService.sendMessage(
        conversationId: widget.conversationId,
        message: result.message,
        messagePreview: messagePreview,
      );

      // Mark as transferred immediately
      _addLog('Marquage comme transféré...');
      await conversationService.markMessageAsTransferred(
        conversationId: widget.conversationId,
        messageId: result.message.id,
        allParticipants: (await conversationService.getConversation(widget.conversationId))?.peerIds ?? [],
      );

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      _addLog('=== ENVOI RÉUSSI en ${totalTime}ms ===');

      setState(() {
        _isComplete = true;
        _isProcessing = false;
      });

      // Retourner après 1 seconde
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      _addLog('=== ERREUR ===');
      _addLog('Erreur: $e');
      if (AppConfig.verboseCryptoLogs) {
        _addLog('Stack trace: $stackTrace');
      }
      
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableBits = widget.sharedKey.countAvailableBits(widget.currentUserId);
    final neededBits = _currentResult!.data.length * 8;
    final canSend = neededBits <= availableBits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envoyer un média'),
      ),
      body: Column(
        children: [
          // Preview de l'image/fichier
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: Center(
                child: _currentResult!.contentType == MessageContentType.image
                    ? Image.memory(
                        _currentResult!.data,
                        fit: BoxFit.contain,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.insert_drive_file, size: 64, color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            _currentResult!.fileName,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Sélection de qualité pour images
          if (_currentResult!.contentType == MessageContentType.image && !_isComplete)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Qualité:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ImageQuality.values.map((quality) {
                      return ChoiceChip(
                        label: Text(quality.label),
                        selected: _selectedQuality == quality,
                        onSelected: _isProcessing ? null : (_) => _changeQuality(quality),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Logs de debug
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                reverse: false,
                itemCount: _debugLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _debugLogs[index],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Boutons d'action
          if (!_isComplete)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing || !canSend ? null : _sendMedia,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          canSend
                              ? 'Envoyer (${FormatService.formatBytes(neededBits ~/ 8)})'
                              : 'Pas assez de clé disponible',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: canSend ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isComplete)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.green[100],
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Envoyé avec succès!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
