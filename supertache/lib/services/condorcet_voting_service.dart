import '../models/tache_vote.dart';

/// Service pour analyser les votes préférentiels et déterminer le gagnant de Condorcet
class CondorcetVotingService {
  /// Analyse les votes et détermine s'il y a un gagnant de Condorcet
  /// 
  /// Un gagnant de Condorcet est une alternative qui bat toutes les autres
  /// alternatives dans des comparaisons paires (duel)
  CondorcetResult analyzeVotes(List<TacheVote> votes, List<String> tacheIds) {
    if (votes.isEmpty || tacheIds.isEmpty) {
      return CondorcetResult(
        gagnantId: null,
        scores: {},
        comparaisons: {},
      );
    }

    // Initialiser la matrice des comparaisons paires
    // comparaisons[A][B] = nombre de votes où A est préféré à B
    final comparaisons = <String, Map<String, int>>{};
    for (var tacheId in tacheIds) {
      comparaisons[tacheId] = {};
      for (var autreTacheId in tacheIds) {
        if (tacheId != autreTacheId) {
          comparaisons[tacheId]![autreTacheId] = 0;
        }
      }
    }

    // Pour chaque vote, comparer les paires
    for (var vote in votes) {
      final ordrePreferences = vote.tachesOrdonnees;
      
      // Comparer chaque paire de tâches selon l'ordre du vote
      for (int i = 0; i < ordrePreferences.length; i++) {
        final tacheA = ordrePreferences[i];
        
        for (int j = i + 1; j < ordrePreferences.length; j++) {
          final tacheB = ordrePreferences[j];
          
          // Dans ce vote, tacheA est préférée à tacheB
          if (comparaisons[tacheA]?.containsKey(tacheB) ?? false) {
            comparaisons[tacheA]![tacheB] = (comparaisons[tacheA]![tacheB] ?? 0) + 1;
          }
        }
      }
    }

    // Déterminer le gagnant de Condorcet
    String? gagnant;
    final scores = <String, int>{};

    for (var tacheId in tacheIds) {
      int victoires = 0;
      
      // Pour chaque adversaire
      for (var autreTacheId in tacheIds) {
        if (tacheId == autreTacheId) continue;
        
        // Compter combien de votes préfèrent cette tâche à l'autre
        final votesPourtacheId = comparaisons[tacheId]?[autreTacheId] ?? 0;
        final votesPourAutre = comparaisons[autreTacheId]?[tacheId] ?? 0;
        
        // Si cette tâche bat l'autre
        if (votesPourtacheId > votesPourAutre) {
          victoires++;
        }
      }
      
      scores[tacheId] = victoires;
      
      // Gagnant de Condorcet: bat toutes les autres alternatives
      if (victoires == tacheIds.length - 1) {
        gagnant = tacheId;
      }
    }

    return CondorcetResult(
      gagnantId: gagnant,
      scores: scores,
      comparaisons: comparaisons,
    );
  }

  /// Calcule le score de Borda comme alternative si pas de gagnant de Condorcet
  /// Plus le score est élevé, mieux c'est
  Map<String, int> calculateBordaScores(List<TacheVote> votes, List<String> tacheIds) {
    final scores = <String, int>{};
    
    for (var tacheId in tacheIds) {
      scores[tacheId] = 0;
    }

    for (var vote in votes) {
      final nbTaches = vote.tachesOrdonnees.length;
      
      for (int i = 0; i < vote.tachesOrdonnees.length; i++) {
        final tacheId = vote.tachesOrdonnees[i];
        // Score de Borda: (n-1) points pour le premier, (n-2) pour le deuxième, etc.
        final points = nbTaches - 1 - i;
        scores[tacheId] = (scores[tacheId] ?? 0) + points;
      }
    }

    return scores;
  }

  /// Retourne la tâche avec le meilleur score de Borda
  String? getBordaWinner(List<TacheVote> votes, List<String> tacheIds) {
    final scores = calculateBordaScores(votes, tacheIds);
    
    if (scores.isEmpty) return null;
    
    var meilleureTache = scores.keys.first;
    var meilleurScore = scores[meilleureTache] ?? 0;
    
    for (var entry in scores.entries) {
      if (entry.value > meilleurScore) {
        meilleurScore = entry.value;
        meilleureTache = entry.key;
      }
    }
    
    return meilleureTache;
  }

  /// Analyse complète avec Condorcet et Borda en fallback
  Map<String, dynamic> analyzeComplet(List<TacheVote> votes, List<String> tacheIds) {
    final condorcet = analyzeVotes(votes, tacheIds);
    final bordaScores = calculateBordaScores(votes, tacheIds);
    final bordaWinner = getBordaWinner(votes, tacheIds);

    return {
      'condorcetResult': condorcet,
      'bordaScores': bordaScores,
      'bordaWinner': bordaWinner,
      'recommendedWinner': condorcet.hasGagnant ? condorcet.gagnantId : bordaWinner,
      'method': condorcet.hasGagnant ? 'Condorcet' : 'Borda',
    };
  }
}
