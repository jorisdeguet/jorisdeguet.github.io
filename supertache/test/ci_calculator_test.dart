import 'package:flutter_test/flutter_test.dart';
import 'package:supertache/models/groupe.dart';
import 'package:supertache/services/ci_calculator_service.dart';

void main() {
  final ciCalc = CICalculatorService();

  test('CI simple pour un groupe 5h (3T+2P) avec 30 étudiants', () {
    final g = Groupe(
      id: 'g1',
      cours: 'C5',
      numeroGroupe: '101',
      nombreEtudiants: 30,
      heuresTheorie: 3.0,
      heuresPratique: 2.0,
      tacheId: 't1',
    );

    final ci = ciCalc.calculateCI([g]);

    print('DEBUG CI single group: $ci (expected ~16.5)');

    // Calcul attendu:
    // HC = (3+2)*1.2 = 6.0
    // HP = (3+2) * 0.9 = 4.5 (une seule préparation)
    // PES = 30 * 5 * 0.04 = 6.0
    // NES = 0 (nes < 75)
    // CI total = 6.0 + 4.5 + 6.0 = 16.5

    expect(ci, closeTo(16.5, 1e-3));
  });

  test('CI pour deux groupes du même cours (5h) avec 30 et 25 étudiants', () {
    final g1 = Groupe(
      id: 'g1',
      cours: 'C5',
      numeroGroupe: '101',
      nombreEtudiants: 30,
      heuresTheorie: 3.0,
      heuresPratique: 2.0,
      tacheId: 't1',
    );

    final g2 = Groupe(
      id: 'g2',
      cours: 'C5',
      numeroGroupe: '102',
      nombreEtudiants: 25,
      heuresTheorie: 3.0,
      heuresPratique: 2.0,
      tacheId: 't1',
    );

    final ci = ciCalc.calculateCI([g1, g2]);

    print('DEBUG CI two groups: $ci (expected ~27.5)');

    // Calcul attendu:
    // HC = (5+5)*1.2 = 12.0
    // HP = (une préparation unique) => (5) * 0.9 = 4.5
    // PES = (30*5 + 25*5) * 0.04 = 275 * 0.04 = 11.0
    // NES = 0 (55 < 75)
    // CI total = 12.0 + 4.5 + 11.0 = 27.5

    expect(ci, closeTo(27.5, 1e-3));
  });
}
