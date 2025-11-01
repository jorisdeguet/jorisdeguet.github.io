# Contraintes pour le calcul de la CI et l'algorithme génétique

## Contrainte principale de validité
- **La CI totale doit être comprise entre 35 et 47 unités**
  - CI < 35 : Charge insuffisante (non valide)
  - 35 ≤ CI ≤ 47 : Charge valide
  - CI > 47 : Surcharge (non valide)

## Composantes de la CI

### CIp (Prestation de cours et laboratoires)
```
CIp = (HP × facteurHP) + (HC × 1.2) + CIPES + CINES
```

#### 1. HP (Heures de Préparation)
- **Définition**: Nombre de cours différents par semaine
- **Facteur variable selon le nombre de cours différents**:
  - 1 ou 2 cours différents: HP × 0.9
  - 3 cours différents: HP × 1.1
  - ≥4 cours différents: HP × 1.75
- **Note importante**: Un cours donné à distance est considéré comme différent du même cours en présence

#### 2. HC (Heures de Cours)
- **Définition**: Nombre total de périodes de prestation par semaine
- **Facteur fixe**: HC × 1.2
- **Exception Soins infirmiers (180.A0 et 180.B0)**: Pour les stages sans Nejk, HC × 1.28

#### 3. PES (Paramètre Étudiantes/Étudiants)
- **Définition**: Somme du nombre d'étudiants inscrits à chaque période de cours (N1 + N2 + N3 + ...)
- **Facteur progressif**:
  - Pour les 415 premières PES: PES × 0.04
  - Pour PES > 415: (PES - 415) × 0.07
- **Formule**: CIPES = min(415, PES) × 0.04 + max(0, PES - 415) × 0.07

#### 4. NES (Nombre d'Étudiants Simplifiés)
- **Calcul de NES1**: Nombre total d'étudiants différents dans les cours de pondération ≥ 3
  - Pondération = nombre total de périodes par semaine (théorie + labo + stages)
  - Cours de pondération < 3: NES1 = 0
  
- **Calcul de NES2**: Nombre total d'étudiants différents dans les cours de pondération < 3
  - Cours de pondération < 2: NES2 = 0
  - Disciplines 550 et 551 (sauf 551.B0): NES2 = 0
  
- **Formule**: NES = NES1 + (0.8 × NES2)

- **Bonus NES**:
  - Si NES ≥ 75: ajouter NES × 0.01
  - Si NES > 160: ajouter (NES - 160)² × 0.1

### CIs (Supervision de stages avec Nejk)
```
CIs = Σ (Nijkl / Nejk) × 40 × 0.89 × R
```
- **Nijkl**: Nombre d'étudiants inscrits au stage supervisé
- **Nejk**: Rapport étudiants/enseignant propre au stage
- **R**: Portion du stage assumée par l'enseignant (R = 1 si seul, R partagé sinon)

### CId (Temps de déplacement)
```
CId = λ × [(D1 / 30) + (D2 / 80)] × (1 / 15)
```
- **λ** = 0.5 (paramètre de conversion)
- **D1**: Distance en km pour déplacement "lent" (30 km/h)
- **D2**: Distance en km pour déplacement "rapide" (80 km/h)

**Déplacements comptabilisés**:
- Déplacements entre pavillons, sous-centres ou locaux extérieurs
- Déplacements pour supervision de stages (soins infirmiers, stages avec Nejk)
- **Non comptabilisés**: Déplacements pendant les heures de cours

### CIL (Libération)
```
CIL = L × 40
```
- **L**: Fraction de charge consacrée à une libération

### CIf (Affectation alinéa J)
```
CIf = F × 40
```
- **F**: Pourcentage d'affectation

### CIcp (Instrument principal/complémentaire - Musique)
```
CIcp = Hcp × 1.8
```
- **Programmes concernés**: 501.A0 (Musique) et 551.A0 (Techniques professionnelles de musique et chanson)
- **Hcp**: Nombre d'heures de cours d'instruments
- **Valeur fixe**: 1.8 unité par heure
- **Note**: Ces cours ne comptent pas dans le calcul du nombre de cours différents

### CIcp' (Laboratoire instrument principal - Musique)
```
CIcp' = Hcp' × 2
```
- **Hcp'**: Nombre d'heures de laboratoire lié à l'instrument principal
- **Valeur fixe**: 2 unités par heure
- **Note**: Ces cours ne comptent pas dans le calcul du nombre de cours différents

## Contraintes pour l'algorithme génétique

### Objectif principal
Minimiser l'écart entre la CI calculée et l'intervalle [35, 47]:
```
fitness = {
  0                           si 35 ≤ CI ≤ 47
  abs(CI - 35)                si CI < 35
  abs(CI - 47)                si CI > 47
}
```

### Contraintes secondaires (à optimiser)
1. **Équilibrage de charge**: Minimiser l'écart-type des CI entre enseignants
2. **Minimiser le nombre de cours différents**: Favoriser 1-2 cours (facteur 0.9) plutôt que 3+ cours
3. **Optimiser le PES**: Essayer de rester sous 415 PES si possible (facteur 0.04 vs 0.07)
4. **Éviter les très hauts NES**: Pénalité quadratique au-delà de 160

### Heuristiques suggérées
1. **Grouper par cours similaires**: Assigner des groupes du même cours au même enseignant (réduit HP)
2. **Distribution équilibrée des étudiants**: Éviter qu'un enseignant ait trop de PES
3. **Respecter les seuils**: 
   - Viser 35-47 CI par enseignant
   - Éviter de dépasser 415 PES si possible
   - Garder NES sous 160 si possible

### Fonction de fitness multi-objectif
```
fitness_total = w1 × |CI - cible|           // cible = 41 (milieu de [35,47])
              + w2 × écart_type(CI_tous)     // équilibrage
              + w3 × pénalité_hors_bornes    // CI < 35 ou CI > 47
              + w4 × nb_cours_différents     // préférer peu de cours
```

Poids suggérés:
- w1 = 100 (priorité absolue sur la plage valide)
- w2 = 10 (équilibrage important)
- w3 = 1000 (pénalité sévère si hors bornes)
- w4 = 1 (optimisation secondaire)

### Opérateurs génétiques
1. **Mutation**: Déplacer un groupe d'un enseignant à un autre
2. **Crossover**: Échanger des ensembles de groupes entre deux solutions
3. **Élitisme**: Conserver les meilleures solutions (CI valides)
4. **Sélection**: Tournoi ou roulette pondérée par fitness

### Critères d'arrêt
- Toutes les CI dans [35, 47] ET écart-type < seuil
- Nombre maximum de générations atteint
- Stagnation de la fitness sur N générations
