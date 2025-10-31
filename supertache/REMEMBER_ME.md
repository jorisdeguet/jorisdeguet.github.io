# Fonctionnalité "Se souvenir de moi" - SuperTâche

## ✅ Implémenté

La fonctionnalité "Se souvenir de moi" permet aux utilisateurs de rester connectés même après avoir fermé leur navigateur.

## 🔐 Comment ça fonctionne

### Sur l'écran de connexion

Une case à cocher "Se souvenir de moi" est maintenant présente avec deux modes :

**✅ Coché (par défaut)** :
- La session persiste dans le stockage local du navigateur
- L'utilisateur reste connecté même après fermeture du navigateur
- Idéal pour un ordinateur personnel

**☐ Décoché** :
- La session est temporaire (session du navigateur)
- L'utilisateur est déconnecté à la fermeture du navigateur
- Recommandé pour un ordinateur partagé

### Persistance Firebase Auth

Firebase Auth offre deux modes de persistance :

1. **`Persistence.LOCAL`** (Se souvenir de moi activé)
   - Stockage : localStorage du navigateur
   - Durée : Illimitée jusqu'à déconnexion manuelle
   - Survit à : Fermeture du navigateur, redémarrage de l'ordinateur

2. **`Persistence.SESSION`** (Se souvenir de moi désactivé)
   - Stockage : sessionStorage du navigateur
   - Durée : Jusqu'à la fermeture de l'onglet/navigateur
   - Survit à : Rafraîchissement de la page

## 📝 Code implémenté

### AuthService
```dart
// Configurer la persistance
Future<void> setPersistence(bool rememberMe) async {
  await _auth.setPersistence(
    rememberMe ? Persistence.LOCAL : Persistence.SESSION,
  );
}

// Connexion avec option
Future<User?> signInWithEmailAndPassword(
  String email,
  String password,
  bool rememberMe,
) async {
  await setPersistence(rememberMe);
  // ... connexion
}
```

### LoginScreen
```dart
bool _rememberMe = true; // Activé par défaut

CheckboxListTile(
  value: _rememberMe,
  onChanged: (value) {
    setState(() => _rememberMe = value ?? true);
  },
  title: const Text('Se souvenir de moi'),
)
```

## 🎯 Comportement

### Scénario 1 : "Se souvenir de moi" activé
1. Utilisateur se connecte avec la case cochée
2. Ferme le navigateur
3. Rouvre le navigateur et va sur l'application
4. ✅ Toujours connecté automatiquement

### Scénario 2 : "Se souvenir de moi" désactivé
1. Utilisateur se connecte avec la case décochée
2. Ferme le navigateur
3. Rouvre le navigateur et va sur l'application
4. ❌ Doit se reconnecter

### Scénario 3 : Changement d'appareil
- L'utilisateur doit se reconnecter (normal)
- La session est liée au navigateur/appareil

## 🔒 Sécurité

**Recommandations** :
- ✅ Activez "Se souvenir de moi" sur votre ordinateur personnel
- ❌ Désactivez-le sur un ordinateur public/partagé
- 🔐 Utilisez toujours "Se déconnecter" sur un appareil partagé

**Sécurité Firebase** :
- Les tokens sont stockés de manière sécurisée
- Les tokens expirent et sont automatiquement renouvelés
- Utilise HTTPS pour toutes les communications
- Conforme aux standards de sécurité Web

## 🗑️ Pour se déconnecter complètement

1. Cliquez sur le menu (tiroir de navigation)
2. Cliquez sur "Se déconnecter"
3. Toutes les données de session sont effacées

## 🌐 Support des plateformes

| Plateforme | Support | Stockage |
|------------|---------|----------|
| Web (Chrome) | ✅ | localStorage |
| Web (Firefox) | ✅ | localStorage |
| Web (Safari) | ✅ | localStorage |
| Web (Edge) | ✅ | localStorage |
| Mobile (iOS) | ✅ | Keychain |
| Mobile (Android) | ✅ | SharedPreferences |

## ⚙️ Configuration additionnelle

Aucune configuration Firebase Console n'est nécessaire. La persistance est gérée côté client par Firebase Auth SDK.

## 🐛 Dépannage

### Problème : "Je suis déconnecté à chaque fois"
**Solutions** :
- Vérifiez que "Se souvenir de moi" est coché
- Vérifiez que les cookies ne sont pas bloqués
- Vérifiez que le localStorage n'est pas désactivé
- Vérifiez qu'il n'y a pas de mode "Navigation privée"

### Problème : "La case ne fait rien"
**Cause** : Sur certaines plateformes Web, `setPersistence` peut échouer silencieusement
**Solution** : Firebase Auth garde généralement la session par défaut même sans `setPersistence`

### Problème : "Je veux rester connecté indéfiniment"
**Réponse** : C'est déjà le cas avec "Se souvenir de moi" activé. Firebase renouvelle automatiquement les tokens.

## 📊 Statistiques

Firebase Auth garde automatiquement un historique des connexions dans la Console Firebase :
- Nombre de connexions
- Dernière connexion
- Appareil/navigateur utilisé

Consultez Firebase Console > Authentication > Users pour voir ces détails.

---

**Note** : Par défaut, Firebase Auth sur Web garde déjà la session active. Cette fonctionnalité ajoute une option explicite pour l'utilisateur et améliore la sécurité sur les appareils partagés.
