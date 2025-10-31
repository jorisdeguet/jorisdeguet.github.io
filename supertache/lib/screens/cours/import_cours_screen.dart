import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/cours.dart';
import '../../widgets/app_drawer.dart';

class ImportCoursScreen extends StatefulWidget {
  const ImportCoursScreen({super.key});

  @override
  State<ImportCoursScreen> createState() => _ImportCoursScreenState();
}

class _ImportCoursScreenState extends State<ImportCoursScreen> {
  final _csvController = TextEditingController();
  List<Cours> _parsedCours = [];
  bool _isLoading = false;

  // Données pré-remplies basées sur le tableau fourni
  final String _exampleData = '''A	420-1B3	1B3	Bureautique	1	2
A	420-1P6	1P6	Introduction à la programmation	2	4
A	420-1X6	1X6	Systèmes d'exploitation	2	4
A	420-1C5	1C5	Réseaux locaux	2	3
H	420-2P6	2P6	Programmation orientée objet	2	4
H	420-2T6	2T6	Programmation objet en TI	2	4
H	420-2D5	2D5	Introduction aux bases de données	2	3
H	420-2X5	2X5	Serveurs Intranet	2	3
H	420-2W6	2W6	Programmation Web serveur	2	4
A	420-3U4	3U4	Introduction à la cybersécurité	1	3
A	420-3N5	3N5	Programmation 3	2	3
A-É	420-3W6	3W6	Programmation Web transactionnelle	2	4
A	420-3R5	3R5	Commutation et routage	2	3
A	420-3S6	3S6	Serveurs 2 : Services Internet	2	4
A	420-3T5	3T5	Automatisation de tâches	2	3
H	420-4M3	4M3	Méthodologie	1	2
H	420-4E4	4E4	Solutions technologiques en programmation	1	3
H	420-4N6	4N6	Applications mobiles	2	4
A-H	420-4W6	4W6	Programmation Web orientée services	2	4
H	420-4D5	4D5	Bases de données et programmation Web	2	3
H	420-4T4	4T4	Solutions technologiques en réseautique	1	3
H	420-4U5	4U5	Cybersécurité 2 : Architecture	2	3
H	420-4R5	4R5	Réseaux étendus	2	3
H	420-4S6	4S6	Serveurs 3 : Administration centralisée	3	3
A	420-5L4	5L4	Professions et soutien aux utilisateurs	1	3
A-É	420-5N6	5N6	Applications mobiles avancées	2	4
A-H	420-5W5	5W5	Programmation Web Avancée	2	3
A	420-5Y5	5Y5	Analyse et conception d'applications	1	4
A	420-5U5	5U5	Cybersécurité 3 : Surveillance	2	3
A	420-5V6	5V6	Infrastructure virtuelle	2	4
A	420-5S6	5S6	Serveurs 4 : Communication et collaboration	3	3
A-H	420-SN1	SN1	Programmation en sciences	1	2
A-H	420-4A4	4A4	Réseaux de neurones et sciences	2	2
A-H	360-4A3	4A3	Projet scientifique de fin d'études	0	3
A	420-905	905	Introduction à la programmation	1	4
H	420-964	964	Programmation serveur et bases de données	1	3
A	420-943	943	Assurance Qualité	1	2
A-H	420-973	973	Tableur en gestion administrative	1	2
A-H	420-Z03	Z03	Introduction à la programmation WEB	1	2''';

  @override
  void initState() {
    super.initState();
    _csvController.text = _exampleData;
    _parseCSV();
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  void _parseCSV() {
    final lines = _csvController.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final List<Cours> coursList = [];

    for (var i = 0; i < lines.length; i++) {
      final cours = Cours.fromCSVLine(lines[i], i);
      if (cours != null) {
        coursList.add(cours);
      }
    }

    setState(() {
      _parsedCours = coursList;
    });
  }

  Future<void> _importCours() async {
    if (_parsedCours.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun cours à importer')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.createCoursList(_parsedCours);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_parsedCours.length} cours importés avec succès')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _replaceAllCours() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remplacer tous les cours'),
        content: const Text(
          'Attention ! Cela va supprimer TOUS les cours existants et les remplacer par ceux du CSV. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.deleteAllCours();
      await firestoreService.createCoursList(_parsedCours);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_parsedCours.length} cours importés avec succès')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Importer des cours'),
        actions: [
          if (_parsedCours.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'import') {
                  _importCours();
                } else if (value == 'replace') {
                  _replaceAllCours();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 20),
                      SizedBox(width: 8),
                      Text('Ajouter aux cours existants'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'replace',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Remplacer tous les cours'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Format CSV',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Format : Session, Code complet, Code simple, Titre, Heures théorie, Heures labo',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Exemple : A	420-1P6	1P6	Introduction à la programmation	2	4',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sessions : A (Automne), H (Hiver), A-H (Toute l\'année), A-É (Automne et Été)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Zone de texte CSV
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Données CSV',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Chip(
                              label: Text('${_parsedCours.length} cours'),
                              avatar: const Icon(Icons.book, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _csvController,
                          maxLines: 15,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Collez vos données CSV ici...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => _parseCSV(),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _parseCSV,
                          icon: const Icon(Icons.preview),
                          label: const Text('Analyser le CSV'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Aperçu des cours
                if (_parsedCours.isNotEmpty)
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Aperçu (${_parsedCours.length} cours)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _parsedCours.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final cours = _parsedCours[index];
                            return ListTile(
                              dense: true,
                              leading: Container(
                                width: 50,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  cours.codeSimple,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              title: Text(
                                cours.titre,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${cours.code} • ${cours.heuresTheorie}h-${cours.heuresLaboratoire}h • ${cours.sessionsDisplay}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _replaceAllCours,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Remplacer tous'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _importCours,
                                  icon: const Icon(Icons.upload),
                                  label: const Text('Ajouter'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
