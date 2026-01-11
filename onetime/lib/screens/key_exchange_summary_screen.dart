import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/key_exchange_session.dart';
import '../models/shared_key.dart';
import '../models/conversation.dart';
import 'conversation_detail_screen.dart';

/// Screen showing detailed summary of a key exchange
class KeyExchangeSummaryScreen extends StatelessWidget {
  final KeyExchangeSessionModel session;
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
    
    // Also print to console
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('KEY EXCHANGE SUMMARY');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint(summary);
    debugPrint('═══════════════════════════════════════════════════');

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
    buffer.writeln('👥 Participants: ${session.participants.length}');
    for (final p in session.participants) {
      final shortId = p.length > 8 ? p.substring(0, 8) : p;
      final isCurrent = p == currentUserId;
      final role = p == session.sourceId ? 'SOURCE' : 'READER';
      buffer.writeln('   ${isCurrent ? '➤' : ' '} $shortId ($role)${isCurrent ? ' ← Vous' : ''}');
    }
    buffer.writeln();
    
    // Key sizes
    buffer.writeln('🔑 TAILLE DES CLÉS');
    buffer.writeln('───────────────────────────────────────────────────');
    if (previousKey != null) {
      buffer.writeln('Clé avant échange:     ${_formatBits(previousKey!.lengthInBits)}');
      buffer.writeln('Nouvelle clé ajoutée:  ${_formatBits(newKey.lengthInBits - previousKey!.lengthInBits)}');
      buffer.writeln('Clé totale après:      ${_formatBits(newKey.lengthInBits)}');
    } else {
      buffer.writeln('Clé avant échange:     0 bits (nouvelle conversation)');
      buffer.writeln('Nouvelle clé créée:    ${_formatBits(newKey.lengthInBits)}');
    }
    
    // Calculate actually available bits for current user
    final availableBits = newKey.countAvailableBits(currentUserId);
    buffer.writeln('Bits disponibles:      ${_formatBits(availableBits)}');
    buffer.writeln();
    
    // Segment scan status
    buffer.writeln('📊 ÉTAT DES SEGMENTS (${ session.totalSegments} segments)');
    buffer.writeln('───────────────────────────────────────────────────');
    
    int completeSegments = 0;
    final incompleteSegments = <int>[];
    
    for (int i = 0; i < session.totalSegments; i++) {
      final scannedBy = session.scannedBy[i] ?? [];
      final allScanned = session.allParticipantsScannedSegment(i);
      
      if (allScanned) {
        completeSegments++;
      } else {
        incompleteSegments.add(i);
      }
    }
    
    buffer.writeln('✓ Segments complets:    $completeSegments/${session.totalSegments}');
    
    if (incompleteSegments.isNotEmpty) {
      buffer.writeln('⚠ Segments incomplets:  ${incompleteSegments.length}');
      buffer.writeln();
      
      for (final segIdx in incompleteSegments) {
        final scannedBy = session.scannedBy[segIdx] ?? [];
        final missing = session.participants
            .where((p) => !scannedBy.contains(p))
            .map((p) => p.length > 8 ? p.substring(0, 8) : p)
            .toList();
        
        buffer.writeln('   Segment $segIdx: Manquant pour ${missing.join(', ')}');
      }
    }
    
    buffer.writeln();
    
    // Detailed segment-by-segment status (compact)
    buffer.writeln('📈 DÉTAIL PAR SEGMENT');
    buffer.writeln('───────────────────────────────────────────────────');
    
    // Group segments in rows of 10 for compact display
    for (int row = 0; row < (session.totalSegments + 9) ~/ 10; row++) {
      final start = row * 10;
      final end = (start + 10).clamp(0, session.totalSegments);
      
      buffer.write('Seg ${start.toString().padLeft(3)}-${(end - 1).toString().padLeft(3)}: ');
      
      for (int i = start; i < end; i++) {
        final allScanned = session.allParticipantsScannedSegment(i);
        buffer.write(allScanned ? '✓' : '✗');
      }
      
      buffer.writeln();
    }
    
    buffer.writeln();
    
    // Per-participant progress
    buffer.writeln('👤 PROGRESSION PAR PARTICIPANT');
    buffer.writeln('───────────────────────────────────────────────────');
    
    for (final p in session.participants) {
      final shortId = p.length > 8 ? p.substring(0, 8) : p;
      int scanned = 0;
      
      for (int i = 0; i < session.totalSegments; i++) {
        if (session.hasParticipantScannedSegment(p, i)) {
          scanned++;
        }
      }
      
      final percent = (scanned / session.totalSegments * 100).toStringAsFixed(1);
      final progressBar = _createProgressBar(scanned, session.totalSegments, 20);
      final isCurrent = p == currentUserId;
      
      buffer.writeln('${isCurrent ? '➤' : ' '} $shortId: $progressBar $scanned/${session.totalSegments} ($percent%)');
    }
    
    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('Échange terminé le ${_formatDateTime(DateTime.now())}');
    buffer.writeln('═══════════════════════════════════════════════════');
    
    return buffer.toString();
  }

  String _formatBits(int bits) {
    final bytes = bits ~/ 8;
    if (bytes < 1024) {
      return '$bytes B ($bits bits)';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(2);
      return '$kb KB ($bits bits)';
    } else {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
      return '$mb MB ($bits bits)';
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _createProgressBar(int current, int total, int width) {
    final filled = (current / total * width).round();
    final empty = width - filled;
    return '[' + ('█' * filled) + ('░' * empty) + ']';
  }
}
