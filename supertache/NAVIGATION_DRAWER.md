# Menu de navigation (Drawer)

## Modifications effectuées

Le menu hamburger (drawer) est maintenant disponible dans **tous les écrans** de l'application, remplaçant la flèche de retour standard.

### Widget créé

- **`lib/widgets/app_drawer.dart`** : Widget réutilisable contenant le drawer avec :
  - En-tête avec le nom et l'email de l'utilisateur connecté
  - Menu "Accueil" - retourne à l'écran d'accueil (liste des tâches)
  - Menu "Catalogue des cours" - accès au catalogue
  - Menu "Mon profil" - accès au profil utilisateur
  - Bouton de déconnexion

### Écrans modifiés

Les écrans suivants ont été mis à jour pour inclure le drawer :

1. **`home_screen.dart`** - Écran d'accueil
2. **`view_tache_screen.dart`** - Détails d'une tâche
3. **`create_tache_screen.dart`** - Création d'une tâche
4. **`cours_list_screen.dart`** - Liste des cours
5. **`import_cours_screen.dart`** - Import de cours
6. **`edit_cours_screen.dart`** - Modification d'un cours
7. **`profile_screen.dart`** - Profil utilisateur

### Implémentation

Pour chaque écran, l'AppBar a été modifié pour :
1. Remplacer le bouton de retour par défaut par le menu hamburger
2. Ajouter le drawer

```dart
appBar: AppBar(
  leading: Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () => Scaffold.of(context).openDrawer(),
    ),
  ),
  title: const Text('Titre de l\'écran'),
  // ... actions
),
drawer: const AppDrawer(),
```

### Navigation

- L'option "Accueil" utilise `Navigator.popUntil` pour retourner à l'écran principal
- Les autres options vérifient qu'on n'est pas déjà sur l'écran avant de naviguer
- Les routes sont nommées pour faciliter la détection

### Avantages

- Navigation cohérente dans toute l'application
- Accès rapide aux fonctionnalités principales depuis n'importe quel écran
- Meilleure expérience utilisateur
- Code réutilisable et maintenable
