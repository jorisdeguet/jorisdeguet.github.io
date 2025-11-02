import 'package:flutter/material.dart';
import '../../models/tache.dart';
import '../../models/bloc_ci_fixe.dart';
import '../../services/tache_service.dart';

class ManageBlocsCIScreen extends StatefulWidget {
  final String tacheId;

  const ManageBlocsCIScreen({
    Key? key,
    required this.tacheId,
  }) : super(key: key);

  @override
  State<ManageBlocsCIScreen> createState() => _ManageBlocsCIScreenState();
}

class _ManageBlocsCIScreenState extends State<ManageBlocsCIScreen> {
  final TacheService _tacheService = TacheService();
  Tache? _tache;
  bool _isLoading = true;
  List<BlocCIFixe> _blocs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tache = await _tacheService.getTache(widget.tacheId);
    if (tache != null) {
      setState(() {
        _tache = tache;
        _blocs = List.from(tache.blocsCIFixes);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _tache == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Blocs de CI fixes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocs de CI fixes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveBlocs,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gérer les blocs de CI fixes pour ${_tache!.nom}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ces blocs (PVRTT, coordination, etc.) seront automatiquement ajoutés à la CI de chaque enseignant dans toutes les répartitions.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _blocs.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun bloc de CI fixe configuré',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _blocs.length,
                      itemBuilder: (context, index) {
                        final bloc = _blocs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.lock, color: Colors.blue),
                            title: Text(bloc.description),
                            subtitle: Text(
                              '${bloc.enseignantEmail} • ${bloc.ci.toStringAsFixed(1)} CI',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteBloc(index),
                            ),
                            onTap: () => _editBloc(index),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBloc,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un bloc'),
      ),
    );
  }

  void _addBloc() async {
    final result = await _showBlocDialog(context, null);
    if (result != null) {
      setState(() {
        _blocs.add(result);
      });
    }
  }

  void _editBloc(int index) async {
    final result = await _showBlocDialog(context, _blocs[index]);
    if (result != null) {
      setState(() {
        _blocs[index] = result;
      });
    }
  }

  void _deleteBloc(int index) {
    setState(() {
      _blocs.removeAt(index);
    });
  }

  Future<BlocCIFixe?> _showBlocDialog(
      BuildContext context, BlocCIFixe? existing) async {
    final emailController =
        TextEditingController(text: existing?.enseignantEmail ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final ciController =
        TextEditingController(text: existing?.ci.toString() ?? '');

    // Liste des emails disponibles
    final availableEmails = _tache!.enseignantEmails;

    String? selectedEmail = existing?.enseignantEmail;
    if (selectedEmail == null && availableEmails.isNotEmpty) {
      selectedEmail = availableEmails.first;
      emailController.text = selectedEmail;
    }

    return showDialog<BlocCIFixe>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Ajouter un bloc' : 'Modifier le bloc'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedEmail,
                decoration: const InputDecoration(
                  labelText: 'Enseignant',
                  border: OutlineInputBorder(),
                ),
                items: availableEmails
                    .map((email) => DropdownMenuItem(
                          value: email,
                          child: Text(email),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedEmail = value;
                  emailController.text = value ?? '';
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (ex: PVRTT, Coordination)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ciController,
                decoration: const InputDecoration(
                  labelText: 'Valeur de CI',
                  border: OutlineInputBorder(),
                  suffixText: 'CI',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              final description = descriptionController.text.trim();
              final ci = double.tryParse(ciController.text) ?? 0.0;

              if (email.isEmpty || description.isEmpty || ci <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez remplir tous les champs'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final bloc = BlocCIFixe(
                id: existing?.id ?? 'bloc_${DateTime.now().millisecondsSinceEpoch}',
                enseignantEmail: email,
                description: description,
                ci: ci,
              );

              Navigator.pop(context, bloc);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBlocs() async {
    final updatedTache = _tache!.copyWith(blocsCIFixes: _blocs);
    await _tacheService.updateTache(updatedTache);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blocs de CI fixes sauvegardés avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }
}

