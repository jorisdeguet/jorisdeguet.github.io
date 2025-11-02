import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tache.dart';
import '../../models/repartition.dart';
import '../../models/tache_vote.dart';
import '../../models/groupe.dart';
import '../../services/firestore_service.dart';
import '../../services/repartition_service.dart';
import '../../services/groupe_service.dart';
import '../../services/ci_calculator_service.dart';
import '../../widgets/app_drawer.dart';

class VoteRepartitionsScreen extends StatefulWidget {
  final String tacheId;
  final String generationId; // ID de la génération (group de répartitions à voter)

  const VoteRepartitionsScreen({
    Key? key,
    required this.tacheId,
    required this.generationId,
  }) : super(key: key);

  @override
  State<VoteRepartitionsScreen> createState() => _VoteRepartitionsScreenState();
}

class _VoteRepartitionsScreenState extends State<VoteRepartitionsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _tacheExpanded = false;

  Tache? _tache;
  List<Repartition> _repartitions = [];
  List<Groupe> _groupes = [];
  List<String> _orderedRepartitionIds = [];
  
  String? _currentEnseignantId;
  String? _currentEnseignantEmail;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final repartitionService = RepartitionService();
    final groupeService = GroupeService();

    final tache = await firestoreService.getTache(widget.tacheId);
    if (tache == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Charger toutes les répartitions automatiques de cette tâche
    final allRepartitions = await repartitionService.getRepartitionsForTacheFuture(widget.tacheId);
    final autoRepartitions = allRepartitions
        .where((r) => r.estAutomatique)
        .toList();

    final groupes = await groupeService.getGroupesForTacheFuture(widget.tacheId);
    
    // Récupérer l'enseignant courant
    final enseignantsList = await firestoreService.getEnseignantsByEmails([user.email!]);
    final enseignant = enseignantsList.isNotEmpty ? enseignantsList.first : null;

    setState(() {
      _tache = tache;
      _repartitions = autoRepartitions;
      _groupes = groupes;
      _orderedRepartitionIds = autoRepartitions.map((r) => r.id).toList();
      _currentEnseignantId = enseignant?.id;
      _currentEnseignantEmail = user.email;
      _isLoading = false;
    });
  }

  Future<void> _saveVote() async {
    if (_currentEnseignantId == null || _currentEnseignantEmail == null) return;

    setState(() => _isSaving = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      
      final vote = TacheVote(
        enseignantId: _currentEnseignantId!,
        enseignantEmail: _currentEnseignantEmail!,
        tacheGenerationId: widget.generationId,
        tachesOrdonnees: _orderedRepartitionIds,
        dateVote: DateTime.now(),
      );

      await firestoreService.saveTacheVote(vote);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote enregistré avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voter')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_tache == null || _repartitions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voter')),
        body: const Center(
          child: Text('Aucune répartition disponible pour voter'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Votez pour votre préférence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveVote,
            tooltip: 'Soumettre mon vote',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Section dépliable pour les détails de la tâche
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _tacheExpanded = !_tacheExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _tacheExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tache?.nom ?? 'Tâche',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cliquez pour voir les détails',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_tacheExpanded && _tache != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        _buildTacheInfoRow(
                          Icons.calendar_today,
                          'Session',
                          '${_tache!.type == SessionType.automne ? "Automne" : "Hiver"} ${_tache!.year}',
                        ),
                        const SizedBox(height: 8),
                        _buildTacheInfoRow(
                          Icons.people,
                          'Enseignants',
                          '${_tache!.enseignantEmails.length}',
                        ),
                        const SizedBox(height: 8),
                        _buildTacheInfoRow(
                          Icons.class_,
                          'Groupes',
                          '${_groupes.length}',
                        ),
                        const SizedBox(height: 8),
                        _buildTacheInfoRow(
                          Icons.analytics,
                          'Plage CI cible',
                          '${_tache!.ciMin.toStringAsFixed(1)} - ${_tache!.ciMax.toStringAsFixed(1)}',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Instructions
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primary.withAlpha(26),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ordonnez les répartitions de votre préférée (en haut) à votre moins préférée (en bas). '
                  'Maintenez et glissez pour réorganiser.',
                ),
                const SizedBox(height: 4),
                Text(
                  '${_repartitions.length} répartitions à classer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Liste réordonnab le
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orderedRepartitionIds.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _orderedRepartitionIds.removeAt(oldIndex);
                  _orderedRepartitionIds.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final repartitionId = _orderedRepartitionIds[index];
                final repartition = _repartitions.firstWhere((r) => r.id == repartitionId);
                
                return _buildRepartitionCard(
                  key: ValueKey(repartitionId),
                  index: index,
                  repartition: repartition,
                );
              },
            ),
          ),

          // Bouton de soumission
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveVote,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.how_to_vote),
              label: Text(_isSaving ? 'Enregistrement...' : 'Soumettre mon vote'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepartitionCard({
    required Key key,
    required int index,
    required Repartition repartition,
  }) {
    final ciCalculator = CICalculatorService();
    final groupeMap = {for (var g in _groupes) g.id: g};
    
    // Calculer la CI pour l'enseignant courant
    double? maCi;
    if (_currentEnseignantId != null) {
      final mesGroupeIds = repartition.allocations[_currentEnseignantId] ?? [];
      final mesGroupes = mesGroupeIds
          .map((id) => groupeMap[id])
          .whereType<Groupe>()
          .toList();
      maCi = ciCalculator.calculateCI(mesGroupes);
    }

    // Badge de position
    Color badgeColor;
    String badgeText;
    if (index == 0) {
      badgeColor = Colors.green;
      badgeText = '1er choix';
    } else if (index == _orderedRepartitionIds.length - 1) {
      badgeColor = Colors.red;
      badgeText = 'Dernier choix';
    } else {
      badgeColor = Colors.orange;
      badgeText = 'Choix ${index + 1}';
    }

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: index == 0 ? 4 : 2,
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: badgeColor,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          repartition.nom,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(51),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 12,
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (maCi != null) ...[
              const SizedBox(height: 4),
              Text(
                'Votre CI: ${maCi.toStringAsFixed(2)}',
                style: TextStyle(
                  color: maCi >= _tache!.ciMin && maCi <= _tache!.ciMax
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flèche pour monter
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              iconSize: 20,
              onPressed: index > 0
                  ? () {
                      setState(() {
                        final item = _orderedRepartitionIds.removeAt(index);
                        _orderedRepartitionIds.insert(index - 1, item);
                      });
                    }
                  : null,
              tooltip: 'Monter',
              color: index > 0 ? Colors.blue : Colors.grey,
            ),
            // Flèche pour descendre
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              iconSize: 20,
              onPressed: index < _orderedRepartitionIds.length - 1
                  ? () {
                      setState(() {
                        final item = _orderedRepartitionIds.removeAt(index);
                        _orderedRepartitionIds.insert(index + 1, item);
                      });
                    }
                  : null,
              tooltip: 'Descendre',
              color: index < _orderedRepartitionIds.length - 1 ? Colors.blue : Colors.grey,
            ),
            // Icône pour voir les détails
            IconButton(
              icon: const Icon(Icons.visibility),
              iconSize: 20,
              onPressed: () {
                _showRepartitionDetails(repartition);
              },
              tooltip: 'Voir détails',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTacheInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        Text(value),
      ],
    );
  }

  void _showRepartitionDetails(Repartition repartition) {
    Navigator.pushNamed(
      context,
      '/repartition/detail',
      arguments: repartition.id,
    );
  }
}
