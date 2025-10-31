# Authentification par lien email - SuperTâche

## 🔐 Vue d'ensemble

SuperTâche utilise l'authentification **passwordless** (sans mot de passe) via Firebase Email Link Authentication. Cette méthode est plus simple et plus sécurisée qu'une authentification traditionnelle par mot de passe.

## ✨ Avantages

- **Simplicité** : Pas besoin de mémoriser un mot de passe
- **Sécurité** : Pas de mot de passe à stocker ou à oublier
- **Rapidité** : Connexion en 2 clics depuis l'email
- **Création automatique** : Le compte est créé automatiquement lors de la première connexion

## 🚀 Comment ça fonctionne

### Pour l'utilisateur

1. **Entrer son courriel** sur la page de connexion
2. **Cliquer sur "Envoyer le lien de connexion"**
3. **Vérifier sa boîte mail** et ouvrir l'email de SuperTâche
4. **Cliquer sur le lien** dans l'email
5. **Compléter son profil** (prénom et nom) si c'est la première connexion
6. **Accéder à l'application** immédiatement

### Techniquement

```
Utilisateur entre email
    ↓
Firebase envoie un email avec un lien sécurisé
    ↓
Utilisateur clique sur le lien
    ↓
Firebase valide le lien et authentifie l'utilisateur
    ↓
Si nouveau : Créer profil enseignant avec email
    ↓
Si profil incomplet : Demander prénom/nom
    ↓
Rediriger vers l'application
```

## 📋 Configuration Firebase

### 1. Activer Email Link Authentication

Dans Firebase Console :

1. Allez dans **Authentication** > **Sign-in method**
2. Activez **Email/Password**
3. Activez **Email link (passwordless sign-in)**

### 2. Configurer les domaines autorisés

Dans Firebase Console > Authentication > Settings :

1. Ajoutez votre domaine dans **Authorized domains** :
   - `localhost` (pour développement)
   - `supertache-36df7.firebaseapp.com` (automatique)
   - Votre domaine personnalisé si vous en avez un

### 3. Templates d'email

Firebase envoie automatiquement les emails. Vous pouvez personnaliser le template dans :

Firebase Console > Authentication > Templates > Email address verification

Exemple de customisation :
```
Objet : Connexion à SuperTâche
Corps : 
Bonjour,

Cliquez sur le lien ci-dessous pour vous connecter à SuperTâche :

%LINK%

Ce lien est valide pendant 1 heure.

Si vous n'avez pas demandé cette connexion, ignorez cet email.

L'équipe SuperTâche
```

## 🔧 Code implémenté

### AuthService

```dart
// Envoyer le lien
Future<void> sendSignInLinkToEmail(String email)

// Vérifier si l'URL est un lien de connexion
bool isSignInWithEmailLink(String emailLink)

// Se connecter avec le lien
Future<User?> signInWithEmailLink(String email, String emailLink)

// Mettre à jour le profil (prénom/nom)
Future<void> updateEnseignantProfile(String nom, String prenom)
```

### Écrans

1. **LoginScreen** : Saisie de l'email et envoi du lien
2. **VerifyEmailScreen** : Instructions pour vérifier l'email
3. **CompleteProfileScreen** : Saisie du prénom/nom pour nouveaux utilisateurs
4. **AuthWrapper** : Gestion automatique de la redirection

## 🎨 Flux utilisateur

### Première connexion

```
LoginScreen
    ↓ (entre email)
VerifyEmailScreen
    ↓ (affiche instructions)
[Utilisateur clique sur lien dans email]
    ↓
CompleteProfileScreen
    ↓ (entre prénom/nom)
HomeScreen
```

### Connexions suivantes

```
LoginScreen
    ↓ (entre email)
VerifyEmailScreen
    ↓ (affiche instructions)
[Utilisateur clique sur lien dans email]
    ↓
HomeScreen (directement)
```

## 💡 Gestion de l'email stocké

Pour que le lien fonctionne correctement sur Web, l'email est :

1. **Sauvegardé localement** après l'envoi du lien
2. **Récupéré automatiquement** quand l'utilisateur clique sur le lien
3. **Utilisé pour finaliser** l'authentification

### Sur Web (navigateur)

```dart
// Détection automatique du lien dans l'URL
final url = html.window.location.href;
if (authService.isSignInWithEmailLink(url)) {
  await signInWithEmailLink(savedEmail, url);
}
```

## ⚠️ Points importants

### Validité du lien

- Le lien est **valide pendant 1 heure**
- Un seul lien peut être utilisé à la fois
- Si un nouveau lien est demandé, l'ancien devient invalide

### Sécurité

- Le lien contient un **token unique** et sécurisé
- Firebase vérifie que l'email correspond au token
- Le lien ne peut être utilisé qu'**une seule fois**

### Limitations

- **Nécessite un accès à l'email** de l'utilisateur
- Peut être bloqué par certains **filtres anti-spam**
- L'utilisateur doit avoir accès à ses emails

## 🐛 Dépannage

### L'email n'arrive pas

1. Vérifiez les **courriels indésirables/spam**
2. Vérifiez que Email Link est **activé dans Firebase**
3. Vérifiez les **domaines autorisés** dans Firebase Console
4. Attendez quelques minutes (délai possible)

### Le lien ne fonctionne pas

1. Vérifiez que le lien n'a **pas expiré** (1 heure)
2. Assurez-vous d'utiliser le **même navigateur**
3. Vérifiez que l'email correspond à celui utilisé pour la demande
4. Demandez un **nouveau lien**

### Profil non sauvegardé

1. Vérifiez les **règles Firestore**
2. Vérifiez la **connexion internet**
3. Consultez la **console Firebase** pour les erreurs

## 📱 Support multiplateforme

### Web ✅
- Détection automatique du lien dans l'URL
- Redirection automatique après connexion

### Mobile (iOS/Android) ✅
- Deep linking configuré dans firebase_options.dart
- Redirection vers l'app après clic sur le lien
- Nécessite configuration des App Links/Universal Links

## 🔄 Migration depuis l'ancienne méthode

Si vous aviez l'ancienne authentification par mot de passe :

1. Les utilisateurs existants peuvent **continuer à se connecter** avec mot de passe
2. Ou demander un **lien email** pour passer à la nouvelle méthode
3. Firebase gère les deux méthodes simultanément

Pour forcer la migration :
- Désactivez Email/Password dans Firebase Console
- Gardez uniquement Email Link activé
- Les utilisateurs devront utiliser le lien

## 📊 Statistiques

Firebase Analytics vous permet de suivre :
- Nombre d'emails envoyés
- Taux de clics sur les liens
- Taux de complétion des profils
- Temps moyen de connexion

Consultez Firebase Console > Analytics pour plus de détails.

## 🎯 Bonnes pratiques

1. **Personnalisez l'email** dans Firebase Console
2. **Ajoutez votre logo** dans le template d'email
3. **Testez régulièrement** le flux de connexion
4. **Informez les utilisateurs** de vérifier leurs spams
5. **Offrez un support** pour les problèmes de connexion

---

**Note** : Cette méthode d'authentification est recommandée par Firebase pour sa simplicité et sa sécurité. Elle élimine les risques liés aux mots de passe faibles ou réutilisés.
