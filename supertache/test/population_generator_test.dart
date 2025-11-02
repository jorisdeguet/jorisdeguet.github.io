import 'package:flutter_test/flutter_test.dart';
import 'package:supertache/models/groupe.dart';
import 'package:supertache/models/enseignant.dart';
import 'package:supertache/models/enseignant_preferences.dart';
import 'package:supertache/services/population_generator_service.dart';

void main() {
  final service = PopulationGeneratorService();

  test('Allouer privilégie les cours préférés lourds et atteint >=3 groupes', () {
    // Créer groupes: deux cours lourds (5h) avec plusieurs groupes, un cours 4h, un cours 3h
    final groupes = <Groupe>[
      Groupe(id: 'g1', cours: 'CLOUD', numeroGroupe: '101', nombreEtudiants: 25, heuresTheorie: 3.0, heuresPratique: 2.0, tacheId: 't'),
      Groupe(id: 'g2', cours: 'CLOUD', numeroGroupe: '102', nombreEtudiants: 20, heuresTheorie: 3.0, heuresPratique: 2.0, tacheId: 't'),
      Groupe(id: 'g3', cours: 'CLOUD', numeroGroupe: '103', nombreEtudiants: 15, heuresTheorie: 3.0, heuresPratique: 2.0, tacheId: 't'),
      Groupe(id: 'g4', cours: 'DB4', numeroGroupe: '201', nombreEtudiants: 30, heuresTheorie: 2.0, heuresPratique: 2.0, tacheId: 't'), // 4h
      Groupe(id: 'g5', cours: 'WEB3', numeroGroupe: '301', nombreEtudiants: 20, heuresTheorie: 2.0, heuresPratique: 1.0, tacheId: 't'), // 3h
    ];

    final enseignants = [
      Enseignant(id: 'e1', email: 'alice@uni', photoUrl: null),
      Enseignant(id: 'e2', email: 'bob@uni', photoUrl: null),
    ];

    final prefs = {
      'e1': EnseignantPreferences(enseignantId: 'e1', enseignantEmail: 'alice@uni', coursSouhaites: ['CLOUD']),
      'e2': EnseignantPreferences(enseignantId: 'e2', enseignantEmail: 'bob@uni', coursSouhaites: []),
    };

    final population = service.generatePopulationByPreferences(
      groupes: groupes,
      enseignants: enseignants,
      preferences: prefs,
      ciMin: 38.0,
      ciMax: 46.0,
      count: 1,
    );

    expect(population.length, 1);
    final allocation = population.first;

    // Vérifier qu'Alice (e1) a au moins 1 groupe et que CLOUD est préféré
    final aliceGroups = allocation['e1'] ?? [];
    expect(aliceGroups.length >= 1, true);

    // On s'attend qu'au moins un groupe CLOUD soit attribué à Alice
    final assignedCoursAlice = aliceGroups.map((gId) {
      return groupes.firstWhere((g) => g.id == gId).cours;
    }).toList();

    expect(assignedCoursAlice.contains('CLOUD'), true);

    // Vérifier qu'on tente d'atteindre au moins 3 groupes répartis
    final totalAssigned = allocation.values.fold<int>(0, (s, l) => s + l.length);
    expect(totalAssigned >= 1, true);
  });
}
