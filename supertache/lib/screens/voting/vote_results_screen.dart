import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tache.dart';
import '../../models/repartition.dart';
import '../../models/tache_vote.dart';
import '../../services/firestore_service.dart';
import '../../services/repartition_service.dart';
import '../../services/condorcet_voting_service.dart';
import '../../widgets/app_drawer.dart';

class VoteResultsScreen extends StatefulWidget {
  final String tacheId;
  final String generationId;

  const VoteResultsScreen({
    Key? key,
    required this.tacheId,
    required this.generationId,
  }) : super(key: key);

  @override
  State<VoteResultsScreen> createState() => _VoteResultsScreenState();
}

class _VoteResultsScreenState extends State<VoteResultsScreen> {
  bool _isLoading = true;
  
  Tache? _tache;
  List<Repartition> _repartitions = [];
  List<TacheVote> _votes = [];
  Map<String, dynamic>? _results;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final repartitionService = RepartitionService();

    final tache = await firestoreService.getTache(widget.tacheId);
    if (tache == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Charger les répartitions
    final allRepartitions = await repartitionService.getRepartitionsForTacheFuture(widget.tacheId);
    final autoRepartitions = allRepartitions
        .where((r) => r.estAutomatique)
        .toList();

    // Charger les votes depuis Firestore
    final votes = await firestoreService.getTacheVotes(widget.generationId);

    // Analyser les votes
    final votingService = CondorcetVotingService();
    final tacheIds = autoRepartitions.map((r) => r.id).toList();
    
    Map<String, dynamic>? results;
    if (votes.isNotEmpty) {
      results = votingService.analyzeComplet(votes, tacheIds);
    }

    setState(() {
      _tache = tache;
      _repartitions = autoRepartitions;
      _votes = votes;
      _results = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultats du vote')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_tache == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultats du vote')),
        body: const Center(child: Text('Tâche non trouvée')),
      );
    }

    if (_votes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultats du vote')),
        drawer: const AppDrawer(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.how_to_vote,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun vote enregistré',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Les enseignants doivent voter avant de voir les résultats',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final winnerId = _results?['recommendedWinner'];
    final method = _results?['method'] ?? 'Inconnu';
    final condorcetResult = _results?['condorcetResult'] as CondorcetResult?;
    final bordaScores = _results?['bordaScores'] as Map<String, int>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats du vote'),
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, size: 32, color: Colors.amber),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Résultat du vote',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              _tache!.nom,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.how_to_vote, color: Colors.blue),
                          const SizedBox(height: 4),
                          Text(
                            '${_votes.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('Votes'),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.ballot, color: Colors.purple),
                          const SizedBox(height: 4),
                          Text(
                            '${_repartitions.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('Répartitions'),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.analytics, color: Colors.orange),
                          const SizedBox(height: 4),
                          Text(
                            method,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('Méthode'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gagnant
          if (winnerId != null) ...[
            Card(
              color: Colors.amber.shade50,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          'Répartition gagnante',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.star, color: Colors.white),
                      ),
                      title: Text(
                        'Répartition ${_repartitions.indexWhere((r) => r.id == winnerId) + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Text(
                        method == 'Condorcet'
                            ? 'Gagnant de Condorcet - Bat toutes les autres options en duel'
                            : 'Gagnant de Borda - Meilleur score cumulé',
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/repartition/detail',
                            arguments: winnerId,
                          );
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('Voir'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Classement
          Text(
            method == 'Condorcet' ? 'Scores Condorcet' : 'Scores Borda',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: _repartitions.asMap().entries.map((entry) {
                final index = entry.key;
                final repartition = entry.value;
                final score = method == 'Condorcet'
                    ? condorcetResult?.scores[repartition.id] ?? 0
                    : bordaScores[repartition.id] ?? 0;
                
                final isWinner = repartition.id == winnerId;

                return ListTile(
                  tileColor: isWinner ? Colors.amber.shade50 : null,
                  leading: CircleAvatar(
                    backgroundColor: isWinner ? Colors.amber : Colors.grey,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    'Répartition ${index + 1}',
                    style: TextStyle(
                      fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    method == 'Condorcet'
                        ? '$score victoires en duel'
                        : '$score points Borda',
                  ),
                  trailing: isWinner
                      ? const Icon(Icons.emoji_events, color: Colors.amber)
                      : null,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/repartition/detail',
                      arguments: repartition.id,
                    );
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Explication de la méthode
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'À propos de la méthode $method',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    method == 'Condorcet'
                        ? 'Un gagnant de Condorcet est une option qui bat toutes les autres options dans des comparaisons directes (duels). '
                          'C\'est la méthode la plus démocratique quand un tel gagnant existe.'
                        : 'La méthode de Borda est utilisée quand il n\'y a pas de gagnant de Condorcet (paradoxe de Condorcet). '
                          'Chaque position dans le classement donne des points : ${_repartitions.length - 1} points pour le premier choix, '
                          '${_repartitions.length - 2} pour le deuxième, etc. Le gagnant est celui avec le plus de points cumulés.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Matrice de comparaisons (Condorcet seulement)
          if (method == 'Condorcet' && condorcetResult != null) ...[
            const SizedBox(height: 16),
            Text(
              'Matrice des duels',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chaque cellule indique combien de votes préfèrent la ligne à la colonne',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildComparisonMatrix(condorcetResult),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonMatrix(CondorcetResult result) {
    final tacheIds = _repartitions.map((r) => r.id).toList();
    
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      defaultColumnWidth: const FixedColumnWidth(60),
      children: [
        // En-tête
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: [
            const TableCell(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text('', textAlign: TextAlign.center),
              ),
            ),
            ...tacheIds.asMap().entries.map((entry) {
              return TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'R${entry.key + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        ),
        // Lignes de données
        ...tacheIds.asMap().entries.map((rowEntry) {
          final rowId = rowEntry.value;
          final rowIndex = rowEntry.key;
          
          return TableRow(
            decoration: rowIndex.isEven
                ? BoxDecoration(color: Colors.grey.shade50)
                : null,
            children: [
              TableCell(
                child: Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'R${rowIndex + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ...tacheIds.map((colId) {
                if (rowId == colId) {
                  return const TableCell(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                
                final score = result.comparaisons[rowId]?[colId] ?? 0;
                final opponentScore = result.comparaisons[colId]?[rowId] ?? 0;
                final isWinning = score > opponentScore;
                
                return TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      score.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: isWinning ? FontWeight.bold : FontWeight.normal,
                        color: isWinning ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}
