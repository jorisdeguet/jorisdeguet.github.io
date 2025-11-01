import 'package:flutter/material.dart';
import '../models/groupe.dart';
import '../services/ci_calculator_service.dart';

class CIExplanationScreen extends StatelessWidget {
  final List<Groupe> groupes;
  final String? enseignantEmail;

  const CIExplanationScreen({
    Key? key,
    required this.groupes,
    this.enseignantEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ciCalculator = CICalculatorService();
    final ci = ciCalculator.calculateCI(groupes);

    // Utiliser les fonctions publiques du service
    final hp = ciCalculator.calculateHP(groupes);
    final hc = ciCalculator.calculateHC(groupes);
    final pes = ciCalculator.calculatePES(groupes);
    final nes1 = ciCalculator.calculateNES1(groupes);
    final nes2 = ciCalculator.calculateNES2(groupes);
    final nes = ciCalculator.calculateNES(groupes);
    final nbCoursDifferents = ciCalculator.calculateNbCoursDifferents(groupes);
    
    // Facteur HP selon le nombre de cours différents
    final facteurHP = ciCalculator.getHPCoefficient(nbCoursDifferents);

    // Calcul des composantes
    final ciHP = ciCalculator.calculatePondHP(groupes);
    final ciHC = ciCalculator.calculatePondHC(groupes);
    final ciPES = ciCalculator.calculatePondPES(groupes);
    final ciNES = ciCalculator.calculatePondNES(groupes);

    final cipTotal = ciHP + ciHC + ciPES + ciNES;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explication du calcul de la CI'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Card(
            color: ci >= 35 && ci <= 47 ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (enseignantEmail != null) ...[
                    Text(
                      enseignantEmail!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Charge Individuelle (CI)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ci.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: ci >= 35 && ci <= 47 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ci >= 35 && ci <= 47
                        ? 'CI valide (entre 35 et 47)'
                        : 'CI non valide (doit être entre 35 et 47)',
                    style: TextStyle(
                      color: ci >= 35 && ci <= 47 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Formule générale
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formule générale',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'CI = CIp + CIs + CId + CIL + CIf + CIcp + CIcp\'',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dans cette application, nous calculons principalement CIp (prestation de cours et laboratoires).',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Détail du calcul CIp
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calcul de la CIp (Prestation de cours)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // HP - Heures de préparation
                  _buildCalculationRow(
                    'HP (Heures de préparation)',
                    'Somme des heures des cours différents à préparer',
                    hp,
                    facteurHP,
                    ciHP,
                    info: nbCoursDifferents == 1
                        ? '1 cours différent (${hp.toStringAsFixed(1)}h) → facteur 0.9'
                        : nbCoursDifferents == 2
                            ? '2 cours différents (${hp.toStringAsFixed(1)}h total) → facteur 0.9'
                            : nbCoursDifferents == 3
                                ? '3 cours différents (${hp.toStringAsFixed(1)}h total) → facteur 1.1'
                                : '≥4 cours différents (${hp.toStringAsFixed(1)}h total) → facteur 1.75',
                  ),
                  const Divider(),
                  
                  // HC - Heures de prestation
                  _buildCalculationRow(
                    'HC (Heures de prestation)',
                    'Nombre de périodes de prestation par semaine',
                    hc,
                    1.2,
                    ciHC,
                  ),
                  const Divider(),
                  
                  // PES
                  _buildPESCalculation(groupes, pes, ciPES),
                  const Divider(),
                  
                  // NES
                  _buildNESCalculation(groupes, nes1, nes2, nes, ciNES),
                  const Divider(),
                  
                  // Total CIp
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total CIp',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          cipTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Liste des groupes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Groupes assignés (${groupes.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...groupes.map((g) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${g.cours} - ${g.numeroGroupe}'),
                            ),
                            Text(
                              '${g.nombreEtudiants} ét. • ${g.heuresTheorie.toInt()}T/${g.heuresPratique.toInt()}P',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contraintes
          _buildContraintesCard(context),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String description,
    double value,
    double facteur,
    double result, {
    String? info,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (info != null) ...[
            const SizedBox(height: 4),
            Text(
              info,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${value.toStringAsFixed(1)} × ${facteur.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                '= ${result.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPESCalculation(List<Groupe> groupes, double pes, double ciPES) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PES (Paramètre Étudiantes/Étudiants)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Somme du nombre d\'étudiants de tous les groupes',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ...groupes.map((g) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 2),
                child: Text(
                  'N${groupes.indexOf(g) + 1}: ${g.nombreEtudiants} étudiants',
                  style: const TextStyle(fontSize: 12),
                ),
              )),
          const SizedBox(height: 8),
          const Text(
            'Facteur: 0.04 pour les 415 premières PES, 0.07 pour le reste',
            style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total PES: ${pes.toStringAsFixed(0)}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                '= ${ciPES.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNESCalculation(
      List<Groupe> groupes, double nes1, double nes2, double nes, double ciNES) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NES (Nombre d\'Étudiants Simplifiés)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'NES = NES1 + (0.8 × NES2)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NES1: ${nes1.toStringAsFixed(0)} (cours pondération ≥ 3)',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'NES2: ${nes2.toStringAsFixed(0)} (cours pondération < 3 et ≥ 2)',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'NES = ${nes1.toStringAsFixed(0)} + (0.8 × ${nes2.toStringAsFixed(0)}) = ${nes.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Si NES ≥ 75: NES × 0.01',
            style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
          ),
          const Text(
            'Si NES > 160: (NES - 160)² × 0.1',
            style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calcul NES',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                '= ${ciNES.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContraintesCard(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Contraintes de validité de la CI',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildConstraintItem('35 ≤ CI ≤ 47', 'La CI doit être entre 35 et 47 unités'),
            _buildConstraintItem(
              'Facteur HP variable',
              '• 1 ou 2 cours différents: HP × 0.9\n'
              '• 3 cours différents: HP × 1.1\n'
              '• ≥4 cours différents: HP × 1.75',
            ),
            _buildConstraintItem(
              'Facteur PES progressif',
              '• 0.04 pour les 415 premières PES\n'
              '• 0.07 pour les PES > 415',
            ),
            _buildConstraintItem(
              'Bonus NES',
              '• Si NES ≥ 75: ajouter NES × 0.01\n'
              '• Si NES > 160: ajouter (NES - 160)² × 0.1',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstraintItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
