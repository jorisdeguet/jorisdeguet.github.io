import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/repartition.dart';
import '../../models/groupe.dart';
import '../../models/enseignant.dart';
import '../../services/repartition_service.dart';
import '../../services/groupe_service.dart';
import '../../services/enseignant_service.dart';
import '../../services/tache_service.dart';
import '../../services/ci_calculator_service.dart';

class ManualRepartitionScreen extends StatefulWidget {
  final String tacheId;
  final String repartitionId;

  ManualRepartitionScreen({
    required this.tacheId,
    required this.repartitionId,
  });

  @override
  _ManualRepartitionScreenState createState() => _ManualRepartitionScreenState();
}

class _ManualRepartitionScreenState extends State<ManualRepartitionScreen> {
  final RepartitionService _repartitionService = RepartitionService();
  final GroupeService _groupeService = GroupeService();
  final EnseignantService _enseignantService = EnseignantService();
  final TacheService _tacheService = TacheService();
  final CICalculatorService _ciCalculator = CICalculatorService();

  Repartition? _repartition;
  List<Groupe> _groupes = [];
  List<Enseignant> _enseignants = [];
  bool _isLoading = true;

  Map<String, List<String>> _currentAllocations = {};
  List<String> _currentNonAlloues = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repartition = await _repartitionService.getRepartition(widget.repartitionId);
    final groupes = await _groupeService.getGroupesForTacheFuture(widget.tacheId);
    final tache = await _tacheService.getTache(widget.tacheId);
    
    if (tache != null) {
      final enseignantsFromDb = await _enseignantService.getEnseignantsByEmails(tache.enseignantEmails);
      
      // Créer une liste complète avec tous les emails de la tâche
      final enseignants = tache.enseignantEmails.map((email) {
        final enseignant = enseignantsFromDb.firstWhere(
          (e) => e.email == email,
          orElse: () => Enseignant(
            id: 'temp_${email.hashCode}', // ID temporaire unique basé sur l'email
            email: email,
          ),
        );
        return enseignant;
      }).toList();
      
      setState(() {
        _repartition = repartition;
        _groupes = groupes;
        _enseignants = enseignants;
        
        // Initialiser les allocations (toujours mutables et complètes)
        if (repartition != null) {
          // Copier en profondeur pour obtenir des listes mutables
          _currentAllocations = repartition.allocations.map((k, v) =>
              MapEntry(k, List<String>.from(v)));
          _currentNonAlloues = List<String>.from(repartition.groupesNonAlloues);
        } else {
          _currentAllocations = {};
          _currentNonAlloues = groupes.map((g) => g.id).toList();
        }
        // S'assurer que chaque enseignant a une entrée
        for (var enseignant in enseignants) {
          _currentAllocations.putIfAbsent(enseignant.id, () => <String>[]);
        }
        // Recalcule des non alloués pour couvrir les cas incohérents
        final allAllocated = _currentAllocations.values
            .expand((ids) => ids)
            .toSet();
        _currentNonAlloues = groupes
            .where((g) => !allAllocated.contains(g.id))
            .map((g) => g.id)
            .toList();
        
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Répartition manuelle')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Répartition manuelle'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveRepartition,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Row(
        children: [
          // Colonne de gauche: Enseignants
          Expanded(
            flex: 3,
            child: ListView(
              padding: EdgeInsets.all(16),
              children: _buildEnseignantCards(),
            ),
          ),
          // Colonne de droite: Groupes non alloués
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Groupes disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      children: _buildAvailableGroupes(),
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Accueil'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Mon profil'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.school),
            title: Text('Catalogue des cours'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/cours');
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Déconnexion'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEnseignantCards() {
    return _enseignants.map((enseignant) {
      final groupeIds = _currentAllocations[enseignant.id] ?? [];
      final groupes = _groupes.where((g) => groupeIds.contains(g.id)).toList();
      final ci = _ciCalculator.calculateCI(groupes);
      
      // Calculer le nombre total d'étudiants
      final totalEtudiants = groupes.fold(0, (sum, g) => sum + g.nombreEtudiants);
      
      // Calculer les heures totales
      final totalHeuresTheorie = groupes.fold(0.0, (sum, g) => sum + g.heuresTheorie);
      final totalHeuresPratique = groupes.fold(0.0, (sum, g) => sum + g.heuresPratique);

      return Card(
        margin: EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      enseignant.email,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'CI: ${ci.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: ci >= 35 && ci <= 47 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$totalEtudiants ét. • ${totalHeuresTheorie.toInt()}T/${totalHeuresPratique.toInt()}P',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              DragTarget<Groupe>(
                onWillAccept: (groupe) => groupe != null,
                onAccept: (groupe) {
                  _addGroupeToEnseignant(enseignant.id, groupe.id);
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: 60),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: candidateData.isNotEmpty 
                            ? Colors.blue 
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: groupes.isEmpty
                        ? Center(
                            child: Text(
                              'Glissez un groupe ici',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: groupes.map((groupe) {
                              return Draggable<Groupe>(
                                data: groupe,
                                feedback: Material(
                                  elevation: 4,
                                  child: _buildGroupeChip(groupe),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.5,
                                  child: _buildGroupeChip(groupe),
                                ),
                                child: _buildGroupeChip(groupe, onDelete: () {
                                  _removeGroupeFromEnseignant(enseignant.id, groupe.id);
                                }),
                              );
                            }).toList(),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildAvailableGroupes() {
    final groupes = _groupes
        .where((g) => _currentNonAlloues.contains(g.id))
        .toList();

    if (groupes.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Tous les groupes sont alloués',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ];
    }

    // Grouper par cours
    final Map<String, List<Groupe>> groupesByCours = {};
    for (var groupe in groupes) {
      groupesByCours.putIfAbsent(groupe.cours, () => []).add(groupe);
    }

    // Trier les cours alphabétiquement
    final sortedCours = groupesByCours.keys.toList()..sort();

    return sortedCours.map((cours) {
      final coursGroupes = groupesByCours[cours]!;
      
      return Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                cours,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: coursGroupes.map((groupe) {
                return Draggable<Groupe>(
                  data: groupe,
                  feedback: Material(
                    elevation: 4,
                    child: _buildGroupeChip(groupe),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _buildGroupeChip(groupe),
                  ),
                  child: _buildGroupeChip(groupe),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildGroupeChip(Groupe groupe, {VoidCallback? onDelete}) {
    return Chip(
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            groupe.nomComplet,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${groupe.nombreEtudiants} ét. - ${groupe.heuresTheorie.toInt()}T/${groupe.heuresPratique.toInt()}P',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
      deleteIcon: onDelete != null ? Icon(Icons.close, size: 18) : null,
      onDeleted: onDelete,
    );
  }

  void _addGroupeToEnseignant(String enseignantId, String groupeId) {
    setState(() {
      // Retirer des non alloués
      _currentNonAlloues.remove(groupeId);
      
      // Retirer d'un autre enseignant si déjà alloué
      _currentAllocations.forEach((key, value) {
        value.remove(groupeId);
      });
      
      // Ajouter à l'enseignant
      if (!_currentAllocations.containsKey(enseignantId)) {
        _currentAllocations[enseignantId] = [];
      }
      if (!_currentAllocations[enseignantId]!.contains(groupeId)) {
        _currentAllocations[enseignantId]!.add(groupeId);
      }
    });
  }

  void _removeGroupeFromEnseignant(String enseignantId, String groupeId) {
    setState(() {
      _currentAllocations[enseignantId]?.remove(groupeId);
      if (!_currentNonAlloues.contains(groupeId)) {
        _currentNonAlloues.add(groupeId);
      }
    });
  }

  Future<void> _saveRepartition() async {
    // Vérifier la validité
    bool estValide = true;
    for (var enseignant in _enseignants) {
      final groupeIds = _currentAllocations[enseignant.id] ?? [];
      final groupes = _groupes.where((g) => groupeIds.contains(g.id)).toList();
      final ci = _ciCalculator.calculateCI(groupes);
      
      if (ci < 35 || ci > 47) {
        estValide = false;
        break;
      }
    }

    final updatedRepartition = _repartition!.copyWith(
      allocations: _currentAllocations,
      groupesNonAlloues: _currentNonAlloues,
      estValide: estValide,
    );

    await _repartitionService.updateRepartition(updatedRepartition);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          estValide
              ? 'Répartition valide enregistrée!'
              : 'Répartition enregistrée (non optimale)',
        ),
        backgroundColor: estValide ? Colors.green : Colors.orange,
      ),
    );

    Navigator.pop(context);
  }
}
