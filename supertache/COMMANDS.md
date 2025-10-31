# Commandes utiles - SuperTâche

## 🚀 Configuration initiale

```bash
# Installer les dépendances
flutter pub get

# Configurer Firebase (obligatoire avant le premier lancement)
dart pub global activate flutterfire_cli
flutterfire configure

# Vérifier l'installation Flutter
flutter doctor
```

## 🏃 Lancer l'application

```bash
# Web (Chrome)
flutter run -d chrome

# Android (émulateur ou appareil)
flutter run -d android

# iOS (macOS uniquement)
flutter run -d ios

# Lister les appareils disponibles
flutter devices
```

## 🔍 Développement

```bash
# Analyser le code
flutter analyze

# Formater le code
flutter format lib/

# Voir les logs en temps réel
flutter run -v

# Hot reload (pendant l'exécution)
# Tapez 'r' dans le terminal

# Hot restart (pendant l'exécution)
# Tapez 'R' dans le terminal
```

## 🧹 Maintenance

```bash
# Nettoyer le projet
flutter clean

# Réinstaller les dépendances
flutter pub get

# Mettre à jour les dépendances
flutter pub upgrade

# Vérifier les dépendances obsolètes
flutter pub outdated
```

## 🔥 Firebase

```bash
# Reconfigurer Firebase
flutterfire configure

# Voir les logs Firebase (si déployé)
firebase login
firebase projects:list

# Déployer sur Firebase Hosting (pour le web)
flutter build web
firebase deploy --only hosting
```

## 📱 Build production

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (macOS uniquement)
flutter build ios --release

# Web
flutter build web --release
```

## 🐛 Debug

```bash
# Lancer en mode debug avec logs détaillés
flutter run --debug -v

# Activer le debug visuel
# Dans l'app, tapez 'p' pour debug painting
# ou 'i' pour l'inspecteur de widgets

# Profiler les performances
flutter run --profile

# Analyser la taille de l'app
flutter build apk --analyze-size
```

## 📊 Tests (à implémenter)

```bash
# Lancer les tests unitaires
flutter test

# Lancer les tests avec couverture
flutter test --coverage

# Lancer les tests d'intégration
flutter test integration_test/
```

## 🔧 Configuration

```bash
# Voir la configuration Flutter
flutter config

# Configurer le JDK (si problème Android)
flutter config --jdk-dir=/path/to/jdk

# Activer/désactiver le web
flutter config --enable-web
flutter config --no-enable-web
```

## 📦 Dépendances

```bash
# Ajouter une dépendance
flutter pub add package_name

# Ajouter une dépendance de développement
flutter pub add --dev package_name

# Supprimer une dépendance
flutter pub remove package_name

# Voir l'arbre des dépendances
flutter pub deps
```

## 🌐 Firebase spécifique à SuperTâche

```bash
# Voir le projet Firebase actuel
cat .firebaserc

# Voir les règles Firestore locales (si configurées)
cat firestore.rules

# Déployer uniquement les règles Firestore
firebase deploy --only firestore:rules
```

## 💡 Astuces

### Hot Reload rapide
Pendant que l'app tourne :
- `r` : Hot reload (rapide, garde l'état)
- `R` : Hot restart (redémarre l'app)
- `p` : Toggle debug painting
- `i` : Ouvrir l'inspecteur
- `q` : Quitter

### Résoudre les problèmes courants

```bash
# Problème de cache
flutter clean && flutter pub get

# Problème de version
flutter upgrade

# Problème Gradle (Android)
cd android && ./gradlew clean
cd .. && flutter clean && flutter pub get

# Problème Pods (iOS)
cd ios && rm -rf Pods Podfile.lock
pod install
cd .. && flutter clean && flutter pub get
```

### Optimiser les performances

```bash
# Build en mode release
flutter run --release

# Analyser les performances
flutter run --profile

# Voir la taille du bundle
flutter build apk --analyze-size --target-platform android-arm64
```

## 📝 Workflow de développement recommandé

1. **Démarrer le développement**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d chrome
   ```

2. **Faire des modifications**
   - Modifier le code
   - Sauvegarder (hot reload automatique)
   - Tester

3. **Avant de commit**
   ```bash
   flutter analyze
   flutter format lib/
   flutter test  # si tests disponibles
   ```

4. **Build de production**
   ```bash
   flutter clean
   flutter pub get
   flutter build web --release
   ```

## 🎯 Commandes spécifiques au projet

```bash
# Voir tous les fichiers Dart
find lib -name "*.dart" | wc -l

# Compter les lignes de code
find lib -name "*.dart" -exec wc -l {} + | tail -1

# Chercher dans le code
grep -r "TacheIndividuelle" lib/

# Voir la structure du projet
tree lib/
# ou
find lib -type d
```

## 📚 Liens utiles

- Flutter docs : https://docs.flutter.dev/
- Firebase console : https://console.firebase.google.com/
- Dart packages : https://pub.dev/
- Flutter samples : https://flutter.github.io/samples/

---

**Note** : Assurez-vous toujours d'avoir configuré Firebase avec `flutterfire configure` avant le premier lancement de l'application.
