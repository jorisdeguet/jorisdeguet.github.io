# Changelog - Dernières modifications

## Écrans d'authentification - Largeur limitée

### Modifications du 1er novembre 2025

**Problème**: Sur les grands écrans, les champs de connexion et d'inscription s'étiraient sur toute la largeur, rendant l'interface peu ergonomique.

**Solution**: Ajout d'une contrainte de largeur maximale de 600 pixels pour les formulaires.

### Fichiers modifiés
- `lib/screens/auth/login_screen.dart`
  - Ajout de `ConstrainedBox(constraints: BoxConstraints(maxWidth: 600))`
  - Les champs de connexion ne dépassent plus 600 pixels de largeur
  - Centrage automatique sur les grands écrans

- `lib/screens/auth/signup_screen.dart`
  - Même modification appliquée à l'écran d'inscription
  - Cohérence visuelle entre les deux écrans d'authentification

### Résultat
- ✅ Sur mobile: aucun changement visible (largeur déjà limitée)
- ✅ Sur tablette/desktop: formulaires limités à 600px et centrés
- ✅ Meilleure lisibilité et ergonomie sur grands écrans

## Navigation et Routes

### Problème résolu
- **Erreur**: `Could not find a generator for route RouteSettings("/vote/repartitions", tache_XXX)`
- **Solution**: Ajout de `onGenerateRoute` dans `main.dart` pour gérer les routes dynamiques

### Modifications apportées
- Ajout de l'import `VoteRepartitionsScreen` dans `main.dart`
- Ajout du gestionnaire `onGenerateRoute` pour la route `/vote/repartitions`
- Navigation automatique vers l'écran de comparaison après génération de solutions

## Algorithme Génétique - Nouveau système de score

### Pénalités basées sur le nombre de cours distincts à préparer

Le système de score a été modifié pour pénaliser les enseignants qui ont trop de cours différents à préparer :

| Nombre de cours distincts | Score |
|---------------------------|-------|
| 1 cours                   | 0     |
| 2 cours                   | -10   |
| 3 cours                   | -30   |
| 4+ cours                  | -100  |

### Fichier modifié
- `lib/services/genetic_algorithm_service.dart`
  - Ajout du calcul du nombre de cours distincts par enseignant
  - Application des pénalités selon le tableau ci-dessus
  - Section ajoutée avant les préférences de cours (Section 2 de la fonction `_calculateFitness`)

### Logique
```dart
// Calcul des cours distincts pour un enseignant
final coursDistincts = enseignantGroupes.map((g) => g.cours).toSet();
final nbCoursDistincts = coursDistincts.length;

// Application des pénalités
if (nbCoursDistincts == 1) {
  score += 0;  // Neutre
} else if (nbCoursDistincts == 2) {
  score -= 10;  // Petite pénalité
} else if (nbCoursDistincts == 3) {
  score -= 30;  // Pénalité moyenne
} else if (nbCoursDistincts >= 4) {
  score -= 100; // Forte pénalité
}
```

## Thème 8-bits (modifications précédentes)

### Nouveaux fichiers créés
- `lib/theme/retro_theme.dart` - Thème noir et blanc pixelisé
- `lib/widgets/pixel_card.dart` - Widgets personnalisés pixelisés
- `lib/screens/demo/retro_theme_demo_screen.dart` - Écran de démonstration

### Caractéristiques du thème
- Police rétro "Press Start 2P"
- Couleurs noir et blanc uniquement
- Bordures pixelisées personnalisées
- Composants: PixelCard, PixelButton, PixelSection, PixelBadge, PixelProgressBar

## Enseignant connecté dans les solutions

### Modifications
- `lib/screens/repartitions/generate_repartitions_screen.dart`
  - Vérification que l'enseignant connecté est inclus dans la génération
  - Ajout automatique s'il est absent de la liste de la tâche

- `lib/services/genetic_algorithm_service.dart`
  - Distribution équitable (round-robin) pour 50% de la population initiale
  - Distribution aléatoire pour les 50% restants (diversité génétique)

## Date de modification
1er novembre 2025

