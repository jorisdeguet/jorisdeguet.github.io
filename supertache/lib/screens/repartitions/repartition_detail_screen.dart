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

import 'manual_repartition_screen.dart';
class RepartitionDetailScreen extends StatefulWidget {
  final String tacheId;
  final String repartitionId;

  RepartitionDetailScreen({
    required this.tacheId,
    required this.repartitionId,
  });

  @override
  _RepartitionDetailScreenState createState() => _RepartitionDetailScreenState();
}

class _RepartitionDetailScreenState extends State<RepartitionDetailScreen> {
  final RepartitionService _repartitionService = RepartitionService();
  final GroupeService _groupeService = GroupeService();
  final EnseignantService _enseignantService = EnseignantService();
  final TacheService _tacheService = TacheService();
  final CICalculatorService _ciCalculator = CICalculatorService();

  Repartition? _repartition;
  List<Groupe> _groupes = [];
  List<Enseignant> _enseignants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repartition = await _repartitionService.getRepartition(widget.repartitionId);
    final groupes = await _groupeService.getGroupesForTache(widget.tacheId).first;
    final tache = await _tacheService.getTache(widget.tacheId);
    
    if (tache != null) {
      final enseignants = await _enseignantService.getEnseignantsByEmails(tache.enseignantEmails);
      
      setState(() {
        _repartition = repartition;
        _groupes = groupes;
        _enseignants = enseignants;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Répartition')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_repartition == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Répartition')),
        body: Center(child: Text('Répartition non trouvée')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_repartition!.nom),
        actions: [
          if (_repartition!.methode == 'manuelle')
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _editRepartition,
              tooltip: 'Modifier',
            ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          SizedBox(height: 16),
          ..._buildEnseignantSections(),
          if (_repartition!.groupesNonAlloues.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildGroupesNonAllouesSection(),
          ],
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

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _repartition!.estValide ? Icons.check_circle : Icons.warning,
                  color: _repartition!.estValide ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  _repartition!.estValide ? 'Répartition valide' : 'Répartition non optimale',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _repartition!.estValide ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Méthode: ${_repartition!.methode ?? "inconnue"}'),
            Text('Créée le: ${_formatDate(_repartition!.dateCreation)}'),
            Text('Groupes non alloués: ${_repartition!.groupesNonAlloues.length}'),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEnseignantSections() {
    return _enseignants.map((enseignant) {
      final groupeIds = _repartition!.allocations[enseignant.id] ?? [];
      final groupes = _groupes.where((g) => groupeIds.contains(g.id)).toList();
      final ci = _ciCalculator.calculateCI(groupes);

      return Card(
        margin: EdgeInsets.only(bottom: 16),
        child: ExpansionTile(
          title: Text(
            enseignant.email,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'CI: ${ci.toStringAsFixed(2)} (${ci >= 35 && ci <= 47 ? "✓" : "✗"})',
            style: TextStyle(
              color: ci >= 35 && ci <= 47 ? Colors.green : Colors.red,
            ),
          ),
          children: groupes.isEmpty
              ? [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun groupe alloué'),
                  ),
                ]
              : groupes.map((groupe) {
                  return ListTile(
                    title: Text(groupe.nomComplet),
                    subtitle: Text(
                      '${groupe.nombreEtudiants} étudiants - '
                      '${groupe.heuresTheorie.toInt()}T/${groupe.heuresPratique.toInt()}P',
                    ),
                    trailing: Text(
                      '${groupe.heuresTheorie}h théo. + ${groupe.heuresPratique}h prat.',
                      style: TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
        ),
      );
    }).toList();
  }

  Widget _buildGroupesNonAllouesSection() {
    final groupes = _groupes
        .where((g) => _repartition!.groupesNonAlloues.contains(g.id))
        .toList();

    return Card(
      child: ExpansionTile(
        title: Text(
          'Groupes non alloués (${groupes.length})',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        children: groupes.map((groupe) {
          return ListTile(
            title: Text(groupe.nomComplet),
            subtitle: Text(
              '${groupe.nombreEtudiants} étudiants - '
              '${groupe.heuresTheorie.toInt()}T/${groupe.heuresPratique.toInt()}P',
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editRepartition() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualRepartitionScreen(
          tacheId: widget.tacheId,
          repartitionId: widget.repartitionId,
        ),
      ),
    );
  }
}
