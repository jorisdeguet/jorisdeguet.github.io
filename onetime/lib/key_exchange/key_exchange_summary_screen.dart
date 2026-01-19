import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../convo/conversation.dart';
import '../convo/conversation_detail_screen.dart';
import '../services/app_logger.dart';
import '../services/format_service.dart';
import 'kex_firestore.dart';
import 'shared_key.dart';

/// Screen showing detailed summary of a key exchange
class KeyExchangeSummaryScreen extends StatelessWidget {
  final KexSessionModel session;
  final SharedKey? previousKey;
  final SharedKey newKey;
  final Conversation conversation;
  final String currentUserId;

  const KeyExchangeSummaryScreen({
    super.key,
    required this.session,
    required this.previousKey,
    required this.newKey,
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final summary = _generateSummary();
    final _log = AppLogger();

    // Also print to console
    _log.d('KeyExchangeSummary', '═══════════════════════════════════════════════════');
    _log.i('KeyExchangeSummary', 'KEY EXCHANGE SUMMARY');
    _log.d('KeyExchangeSummary', '═══════════════════════════════════════════════════');
    _log.d('KeyExchangeSummary', summary);
    _log.d('KeyExchangeSummary', '═══════════════════════════════════════════════════');

    // if you are here, the key exchange is complete
    // add this conversation to the ones watched by the background service

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résumé de l\'échange'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  summary,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: summary));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Résumé copié dans le presse-papiers'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copier le résumé'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationDetailScreen(
                              conversation: conversation,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Vers la conversation'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
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

  String _generateSummary() {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('           RÉSUMÉ D\'ÉCHANGE DE CLÉ');
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln();
    
    // Session info
    buffer.writeln('📋 Session: ${session.id.substring(0, 16)}...');

    // Key sizes
    buffer.writeln('🔑 TAILLE DES CLÉS');
    buffer.writeln('───────────────────────────────────────────────────');
    if (previousKey != null) {
      final prevBytes = previousKey!.lengthInBytes;
      final addedBytes = newKey.lengthInBytes - prevBytes;
      buffer.writeln('Clé avant échange:     ${FormatService.formatBytes(prevBytes)}');
      buffer.writeln('Nouvelle clé ajoutée:  ${FormatService.formatBytes(addedBytes)}');
      buffer.writeln('Clé totale après:      ${FormatService.formatBytes(newKey.lengthInBytes)}');
    } else {
      buffer.writeln('Clé avant échange:     0 B (nouvelle conversation)');
      buffer.writeln('Nouvelle clé créée:    ${FormatService.formatBytes(newKey.lengthInBytes)}');
    }
    
    // Calculate actually available bytes for current user
    final availableBytes = newKey.countAvailableBytes();
    buffer.writeln('Octets disponibles:     ${FormatService.formatBytes(availableBytes)}');
    buffer.writeln();
    
    // Segment scan status
    buffer.writeln('📊 ÉTAT DES SEGMENTS (${ session.totalSegments} segments)');
    buffer.writeln('───────────────────────────────────────────────────');

    buffer.writeln();
    
    // Per-participant progress
    buffer.writeln('👤 PROGRESSION PAR PARTICIPANT');
    buffer.writeln('───────────────────────────────────────────────────');

    
    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('Échange terminé le ${_formatDateTime(DateTime.now())}');
    buffer.writeln('═══════════════════════════════════════════════════');
    
    return buffer.toString();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

}
