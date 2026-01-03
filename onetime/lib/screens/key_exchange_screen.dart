import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/random_key_generator_service.dart';
import '../services/key_exchange_service.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import 'conversation_detail_screen.dart';

/// Écran d'échange de clé via QR codes.
class KeyExchangeScreen extends StatefulWidget {
  final List<String> peerIds;
  final Map<String, String> peerNames;
  final String? conversationName;

  const KeyExchangeScreen({
    super.key,
    required this.peerIds,
    required this.peerNames,
    this.conversationName,
  });

  @override
  State<KeyExchangeScreen> createState() => _KeyExchangeScreenState();
}

class _KeyExchangeScreenState extends State<KeyExchangeScreen> {
  final AuthService _authService = AuthService();
  final RandomKeyGeneratorService _keyGenerator = RandomKeyGeneratorService();
  late final KeyExchangeService _keyExchangeService;
  
  KeyExchangeSession? _session;
  KeyExchangeRole _role = KeyExchangeRole.source;
  int _currentStep = 0;
  KeySegmentQrData? _currentQrData;
  bool _isScanning = false;
  String? _errorMessage;
  
  // Taille de clé à générer (en bits)
  int _keySizeBits = 8192 * 8; // 8 KB par défaut

  final List<int> _keySizeOptions = [
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

  void _startAsSource() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() {
      _role = KeyExchangeRole.source;
      _session = _keyExchangeService.createSourceSession(
        totalBits: _keySizeBits,
        peerIds: widget.peerIds,
        sourceId: currentUser.uid,
      );
      _currentStep = 1;
      _generateNextSegment();
    });
  }

  void _startAsReader() {
    setState(() {
      _role = KeyExchangeRole.reader;
      _currentStep = 1;
      _isScanning = true;
    });
  }

  void _generateNextSegment() {
    if (_session == null) return;

    try {
      _currentQrData = _keyExchangeService.generateNextSegment(_session!);
      setState(() {});
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  void _onQrScanned(String qrData) {
    try {
      final segment = _keyExchangeService.parseQrCode(qrData);
      
      if (_session == null) {
        // Créer la session reader avec les infos du QR
        final currentUser = _authService.currentUser;
        if (currentUser == null) return;

        _session = _keyExchangeService.createReaderSession(
          sessionId: segment.sessionId,
          localPeerId: currentUser.uid,
          peerIds: [...widget.peerIds, currentUser.uid],
          totalBits: _keySizeBits,
        );
      }

      _keyExchangeService.recordReadSegment(_session!, segment);
      
      setState(() {
        _isScanning = false;
      });

      // Vérifier si on a lu tous les segments
      if (_keyExchangeService.isExchangeComplete(_session!)) {
        _finalizeExchange();
      } else {
        // Continuer à scanner
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _isScanning = true);
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'QR code invalide: $e');
    }
  }

  Future<void> _finalizeExchange() async {
    if (_session == null) return;

    try {
      final sharedKey = _keyExchangeService.finalizeExchange(
        _session!,
        conversationName: widget.conversationName,
      );

      // Créer la conversation dans Firebase
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final conversationService = ConversationService(localUserId: currentUser.uid);
      
      final conversation = await conversationService.createConversation(
        peerIds: sharedKey.peerIds,
        peerNames: widget.peerNames,
        totalKeyBits: sharedKey.lengthInBits,
        name: widget.conversationName,
      );

      // TODO: Sauvegarder la clé localement en binaire

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationDetailScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.data_usage),
            ),
            items: _keySizeOptions.map((size) {
              final kb = size ~/ 8 ~/ 1024;
              final messages = size ~/ 8 ~/ 100; // ~100 bytes par message
              return DropdownMenuItem(
                value: size,
                child: Text('$kb KB (~$messages messages)'),
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
    final progress = (session.currentSegmentIndex / session.totalSegments);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progression
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text(
            'Segment ${session.currentSegmentIndex} / ${session.totalSegments}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),

          // QR Code
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _currentQrData!.toQrString(),
                  version: QrVersions.auto,
                  size: 280,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Instructions
          const Text(
            'Faites scanner ce QR code par les autres appareils',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Bouton suivant
          if (session.currentSegmentIndex < session.totalSegments)
            ElevatedButton.icon(
              onPressed: _generateNextSegment,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Segment suivant'),
            )
          else
            ElevatedButton.icon(
              onPressed: _finalizeExchange,
              icon: const Icon(Icons.check),
              label: const Text('Terminer'),
            ),
        ],
      ),
    );
  }

  Widget _buildReaderView() {
    return Column(
      children: [
        if (_session != null) ...[
          LinearProgressIndicator(
            value: _session!.currentSegmentIndex / _session!.totalSegments,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Segments lus: ${_session!.currentSegmentIndex} / ${_session!.totalSegments}',
            ),
          ),
        ],

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
                      const Icon(Icons.check_circle, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text('Segment reçu!'),
                      const SizedBox(height: 16),
                      if (_session != null && 
                          _session!.currentSegmentIndex < _session!.totalSegments)
                        const Text('Attendez le prochain segment...')
                      else
                        ElevatedButton(
                          onPressed: _finalizeExchange,
                          child: const Text('Terminer'),
                        ),
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
