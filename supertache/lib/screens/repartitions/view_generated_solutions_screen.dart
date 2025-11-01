import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tache.dart';
import '../../models/repartition.dart';
import '../../models/groupe.dart';
import '../../services/firestore_service.dart';
import '../../services/repartition_service.dart';
import '../../services/groupe_service.dart';
import '../../services/ci_calculator_service.dart';
import '../../services/genetic_algorithm_service.dart';

class ViewGeneratedSolutionsScreen extends StatefulWidget {
  final String tacheId;
  final String generationId;

  const ViewGeneratedSolutionsScreen({
    Key? key,
    required this.tacheId,
    required this.generationId,
  }) : super(key: key);

  @override
  State<ViewGeneratedSolutionsScreen> createState() => _ViewGeneratedSolutionsScreenState();
}

class _ViewGeneratedSolutionsScreenState extends State<ViewGeneratedSolutionsScreen> {
  bool _isLoading = true;
  Tache? _tache;
  List<Repartition> _solutions = [];
  List<Groupe> _groupes = [];
  Repartition? _selectedSolution;
  Map<String, double> _solutionScores = {};
  Map<String, Map<String, dynamic>> _solutionDetails = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final repartitionService = RepartitionService();
    final groupeService = GroupeService();

    final tache = await firestoreService.getTache(widget.tacheId);
    if (tache == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Charger toutes les répartitions automatiques
    final allRepartitions = await repartitionService.getRepartitionsForTacheFuture(widget.tacheId);
    final autoRepartitions = allRepartitions
        .where((r) => r.estAutomatique)
        .toList();

    final groupes = await groupeService.getGroupesForTacheFuture(widget.tacheId);

    // Charger les préférences des enseignants
    final enseignantIds = tache.enseignantIds;
    final preferencesMap = await firestoreService.getAllEnseignantPreferences(enseignantIds);
    final preferences = preferencesMap.values.toList();

    // Calculer les scores pour chaque solution
    final geneticService = GeneticAlgorithmService();
    final scores = <String, double>{};
    final details = <String, Map<String, dynamic>>{};

    for (var solution in autoRepartitions) {
      final score = await geneticService.calculateFitnessForRepartition(
        solution,
        tache,
        groupes,
        preferences,
      );
      
      scores[solution.id] = score;
      
      // Calculer les détails du score
      details[solution.id] = await _calculateScoreDetails(
        solution,
        tache,
        groupes,
        preferences,
        geneticService,
      );
    }

    setState(() {
      _tache = tache;
      _solutions = autoRepartitions;
      _groupes = groupes;
      _solutionScores = scores;
      _solutionDetails = details;
      if (autoRepartitions.isNotEmpty) {
        _selectedSolution = autoRepartitions.first;
      }
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>> _calculateScoreDetails(
    Repartition solution,
    Tache tache,
    List<Groupe> groupes,
    List<dynamic> preferences,
    GeneticAlgorithmService geneticService,
  ) async {
    int ciInRangeCount = 0;
    int allWantedCoursCount = 0;
    int allUnwantedCoursCount = 0;
    int allWantedColleguesCount = 0;
    int allUnwantedColleguesCount = 0;
    int unallocatedGroupsCount = solution.groupesNonAlloues.length;

    final ciCalculator = CICalculatorService();
    final enseignantIds = solution.allocations.keys.toList();

    for (var enseignantId in enseignantIds) {
      final groupeIds = solution.allocations[enseignantId] ?? [];
      final enseignantGroupes = groupes.where((g) => groupeIds.contains(g.id)).toList();
      
      final ci = ciCalculator.calculateCI(enseignantGroupes);
      
      // Vérifier plage CI
      final ciMin = tache.ciMin ?? 38;
      final ciMax = tache.ciMax ?? 46;
      if (ci >= ciMin && ci <= ciMax) {
        ciInRangeCount++;
      }

      // Vérifier préférences (simplifié pour l'instant)
      // TODO: implémenter la vérification complète des préférences
    }

    return {
      'ciInRange': ciInRangeCount,
      'allWantedCours': allWantedCoursCount,
      'allUnwantedCours': allUnwantedCoursCount,
      'allWantedCollegues': allWantedColleguesCount,
      'allUnwantedCollegues': allUnwantedColleguesCount,
      'unallocatedGroups': unallocatedGroupsCount,
      'totalEnseignants': enseignantIds.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solutions générées')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_solutions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solutions générées')),
        body: const Center(
          child: Text('Aucune solution générée'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solutions générées'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Row(
        children: [
          // Panneau gauche: Liste des solutions
          SizedBox(
            width: 350,
            child: _buildSolutionsList(),
          ),
          const VerticalDivider(width: 1),
          // Panneau droit: Détails de la solution sélectionnée
          Expanded(
            child: _selectedSolution != null
                ? _buildSolutionDetails(_selectedSolution!)
                : const Center(child: Text('Sélectionnez une solution')),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionsList() {
    // Trier par score décroissant
    final sortedSolutions = List<Repartition>.from(_solutions)
      ..sort((a, b) => (_solutionScores[b.id] ?? 0).compareTo(_solutionScores[a.id] ?? 0));

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solutions générées',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sortedSolutions.length} solution(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Liste
          Expanded(
            child: ListView.builder(
              itemCount: sortedSolutions.length,
              itemBuilder: (context, index) {
                final solution = sortedSolutions[index];
                final score = _solutionScores[solution.id] ?? 0;
                final isSelected = _selectedSolution?.id == solution.id;
                final rank = index + 1;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSolution = solution;
                    });
                  },
                  child: Container(
                    color: isSelected ? Colors.blue.shade100 : null,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Badge de rang
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? Colors.amber
                                : rank == 2
                                    ? Colors.grey.shade400
                                    : rank == 3
                                        ? Colors.brown.shade300
                                        : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '#$rank',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Infos solution
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                solution.nom,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    score.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => _showScoreDetails(solution),
                                    icon: const Icon(Icons.info_outline, size: 16),
                                    label: const Text('Détails', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionDetails(Repartition solution) {
    final ciCalculator = CICalculatorService();
    
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // En-tête de la solution
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solution.nom,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score: ${(_solutionScores[solution.id] ?? 0).toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (solution.groupesNonAlloues.isNotEmpty)
                  Chip(
                    label: Text('${solution.groupesNonAlloues.length} groupe(s) non alloué(s)'),
                    backgroundColor: Colors.orange.shade100,
                    avatar: const Icon(Icons.warning, size: 18, color: Colors.orange),
                  ),
              ],
            ),
          ),
          // Liste des enseignants avec leurs cours
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: solution.allocations.keys.length,
              itemBuilder: (context, index) {
                final enseignantId = solution.allocations.keys.elementAt(index);
                final groupeIds = solution.allocations[enseignantId] ?? [];
                final enseignantGroupes = _groupes.where((g) => groupeIds.contains(g.id)).toList();
                
                return _buildEnseignantCard(enseignantId, enseignantGroupes, ciCalculator);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnseignantCard(String enseignantId, List<Groupe> groupes, CICalculatorService ciCalculator) {
    final ci = ciCalculator.calculateCI(groupes);
    final ciMin = _tache?.ciMin ?? 38;
    final ciMax = _tache?.ciMax ?? 46;
    final isInRange = ci >= ciMin && ci <= ciMax;

    // Regrouper les groupes par cours
    final Map<String, List<Groupe>> groupesByCours = {};
    for (var groupe in groupes) {
      groupesByCours.putIfAbsent(groupe.cours, () => []).add(groupe);
    }

    // Trouver l'email de l'enseignant dans la tâche
    String enseignantEmail = enseignantId;
    if (_tache != null && _tache!.enseignantIds.isNotEmpty) {
      // TODO: améliorer ceci avec une vraie résolution id->email
      // Pour l'instant on utilise l'email correspondant dans enseignantEmails
      final index = _tache!.enseignantIds.indexOf(enseignantId);
      if (index >= 0 && index < _tache!.enseignantEmails.length) {
        enseignantEmail = _tache!.enseignantEmails[index];
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête enseignant
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isInRange ? Colors.green.shade100 : Colors.orange.shade100,
                  child: Icon(
                    Icons.person,
                    color: isInRange ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enseignantEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${groupes.length} groupe(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge CI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isInRange ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CI',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        ci.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isInRange ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Liste condensée des cours
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groupesByCours.entries.map((entry) {
                final cours = entry.key;
                final coursGroupes = entry.value;
                final totalEtudiants = coursGroupes.fold<int>(
                  0,
                  (sum, g) => sum + g.nombreEtudiants,
                );
                
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: Text(
                      '${coursGroupes.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    '$cours ($totalEtudiants ét.)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.blue.shade50,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreDetails(Repartition solution) {
    final details = _solutionDetails[solution.id];
    if (details == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Détails du score'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                solution.nom,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score total: ${(_solutionScores[solution.id] ?? 0).toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildScoreDetailRow(
                '✅ Enseignants dans plage CI',
                details['ciInRange'],
                details['totalEnseignants'],
                '+30 pts par enseignant',
                Colors.green,
              ),
              const SizedBox(height: 8),
              _buildScoreDetailRow(
                '⭐ Tous cours souhaités',
                details['allWantedCours'],
                details['totalEnseignants'],
                '+10 pts',
                Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildScoreDetailRow(
                '❌ Que cours évités',
                details['allUnwantedCours'],
                details['totalEnseignants'],
                '-100 pts',
                Colors.red,
              ),
              const SizedBox(height: 8),
              _buildScoreDetailRow(
                '👥 Tous collègues souhaités',
                details['allWantedCollegues'],
                details['totalEnseignants'],
                '+1 pt',
                Colors.purple,
              ),
              const SizedBox(height: 8),
              _buildScoreDetailRow(
                '🚫 Que collègues évités',
                details['allUnwantedCollegues'],
                details['totalEnseignants'],
                '-5 pts',
                Colors.orange,
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildScoreDetailRow(
                '⚠️ Groupes non alloués',
                details['unallocatedGroups'],
                null,
                '-50 pts par groupe',
                Colors.red,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDetailRow(
    String label,
    int value,
    int? total,
    String scoreText,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                scoreText,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            total != null ? '$value / $total' : '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
