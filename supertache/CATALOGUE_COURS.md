# Gestion du catalogue de cours - SuperTâche

## 📚 Vue d'ensemble

Le catalogue de cours permet de gérer la liste complète des cours offerts par le programme, indépendamment des tâches. Chaque cours a ses propres caractéristiques qui peuvent ensuite être utilisées lors de la création de groupes dans les tâches.

## 🎯 Caractéristiques d'un cours

Chaque cours contient :
- **Code complet** : Ex: `420-1P6`
- **Code simple** : Ex: `1P6`
- **Titre** : Ex: `Introduction à la programmation`
- **Heures théorie** : Nombre d'heures de théorie
- **Heures laboratoire** : Nombre d'heures de pratique/laboratoire
- **Sessions** : Quand le cours est offert (Automne, Hiver, toute l'année)

## 📋 Format CSV pour l'import

### Structure
```
Session	Code complet	Code simple	Titre	Heures théorie	Heures labo
```

### Exemple
```
A	420-1P6	1P6	Introduction à la programmation	2	4
H	420-2P6	2P6	Programmation orientée objet	2	4
A-H	420-4W6	4W6	Programmation Web orientée services	2	4
```

### Sessions possibles
- **A** : Automne seulement
- **H** : Hiver seulement
- **A-H** : Automne et Hiver (toute l'année)
- **A-É** : Automne et Été

## 🚀 Utilisation

### Accéder au catalogue
1. Ouvrir le tiroir de navigation (☰)
2. Cliquer sur "Catalogue des cours"

### Importer des cours

**Méthode 1 : Import CSV pré-rempli**
1. Cliquer sur l'icône d'upload (⬆️) dans la barre d'actions
2. Les données d'exemple sont déjà présentes
3. Cliquer sur "Analyser le CSV" pour prévisualiser
4. Choisir :
   - **"Ajouter"** : Ajoute aux cours existants
   - **"Remplacer tous"** : Supprime tous les cours et importe les nouveaux

**Méthode 2 : Import CSV personnalisé**
1. Cliquer sur l'icône d'upload
2. Effacer le contenu pré-rempli
3. Coller vos données au format CSV (séparées par des tabulations)
4. Cliquer sur "Analyser le CSV"
5. Vérifier l'aperçu
6. Cliquer sur "Ajouter" ou "Remplacer tous"

### Modifier un cours
1. Dans la liste des cours, cliquer sur l'icône ✏️
2. Modifier les informations
3. Cliquer sur "Enregistrer les modifications"

### Supprimer un cours
1. Dans la liste des cours, cliquer sur l'icône 🗑️
2. Confirmer la suppression

## 📊 Statistiques affichées

Le catalogue affiche :
- **Total** : Nombre total de cours
- **Automne** : Cours offerts en automne (incluant toute l'année)
- **Hiver** : Cours offerts en hiver (incluant toute l'année)

## 🔗 Lien avec les tâches

Les cours du catalogue servent de référence mais sont **indépendants** des tâches :
- Vous pouvez créer des groupes basés sur des cours du catalogue
- Vous pouvez aussi créer des groupes pour des cours non catalogués
- Le catalogue facilite la saisie en fournissant des données standardisées

## 📝 Données pré-remplies

L'écran d'import contient **40 cours** pré-remplis basés sur le programme TI :

**Session 1 (Automne)** :
- 420-1B3 : Bureautique (1-2)
- 420-1P6 : Introduction à la programmation (2-4)
- 420-1X6 : Systèmes d'exploitation (2-4)
- 420-1C5 : Réseaux locaux (2-3)

**Session 2 (Hiver)** :
- 420-2P6 : Programmation orientée objet (2-4)
- 420-2T6 : Programmation objet en TI (2-4)
- 420-2D5 : Introduction aux bases de données (2-3)
- 420-2X5 : Serveurs Intranet (2-3)
- 420-2W6 : Programmation Web serveur (2-4)

**Session 3 (Automne)** :
- 420-3U4 : Introduction à la cybersécurité (1-3)
- 420-3N5 : Programmation 3 (2-3)
- 420-3W6 : Programmation Web transactionnelle (2-4)
- 420-3R5 : Commutation et routage (2-3)
- 420-3S6 : Serveurs 2 : Services Internet (2-4)
- 420-3T5 : Automatisation de tâches (2-3)

**Session 4 (Hiver)** :
- 420-4M3 : Méthodologie (1-2)
- 420-4E4 : Solutions technologiques en programmation (1-3)
- 420-4N6 : Applications mobiles (2-4)
- 420-4W6 : Programmation Web orientée services (2-4)
- 420-4D5 : Bases de données et programmation Web (2-3)
- 420-4T4 : Solutions technologiques en réseautique (1-3)
- 420-4U5 : Cybersécurité 2 : Architecture (2-3)
- 420-4R5 : Réseaux étendus (2-3)
- 420-4S6 : Serveurs 3 : Administration centralisée (3-3)

**Session 5 (Automne)** :
- 420-5L4 : Professions et soutien aux utilisateurs (1-3)
- 420-5N6 : Applications mobiles avancées (2-4)
- 420-5W5 : Programmation Web Avancée (2-3)
- 420-5Y5 : Analyse et conception d'applications (1-4)
- 420-5U5 : Cybersécurité 3 : Surveillance (2-3)
- 420-5V6 : Infrastructure virtuelle (2-4)
- 420-5S6 : Serveurs 4 : Communication et collaboration (3-3)

**Cours spéciaux** :
- 420-SN1 : Programmation en sciences (1-2)
- 420-4A4 : Réseaux de neurones et sciences (2-2)
- 360-4A3 : Projet scientifique de fin d'études (0-3)
- 420-905 : Introduction à la programmation (1-4)
- 420-964 : Programmation serveur et bases de données (1-3)
- 420-943 : Assurance Qualité (1-2)
- 420-973 : Tableur en gestion administrative (1-2)
- 420-Z03 : Introduction à la programmation WEB (1-2)

## 🗄️ Structure Firestore

```javascript
Collection: cours
Document ID: cours_1P6
{
  id: "cours_1P6",
  code: "420-1P6",
  codeSimple: "1P6",
  titre: "Introduction à la programmation",
  heuresTheorie: 2,
  heuresLaboratoire: 4,
  sessions: ["A"]
}
```

## 💡 Conseils d'utilisation

### Premier import
1. Utilisez les données pré-remplies pour démarrer rapidement
2. Cliquez sur "Remplacer tous" pour un catalogue propre
3. Modifiez les cours si nécessaire

### Mises à jour annuelles
1. Exportez votre catalogue actuel (copier-coller)
2. Modifiez dans un tableur
3. Importez avec "Remplacer tous"

### Ajout de nouveaux cours
1. Utilisez "Ajouter" pour ne pas perdre l'existant
2. Ou modifiez manuellement avec l'icône ✏️

## 🎯 Cas d'usage

**Scénario 1 : Nouvelle installation**
```
1. Accéder au catalogue
2. Cliquer sur "Importer des cours"
3. Vérifier les données pré-remplies
4. Cliquer sur "Remplacer tous"
✅ Catalogue complet en 4 clics
```

**Scénario 2 : Ajout d'un cours**
```
1. Accéder au catalogue
2. Cliquer sur "Importer des cours"
3. Ajouter une ligne au CSV :
   A	420-XXX	XXX	Nouveau cours	2	3
4. Cliquer sur "Ajouter"
✅ Cours ajouté sans perdre l'existant
```

**Scénario 3 : Modification d'un cours**
```
1. Trouver le cours dans la liste
2. Cliquer sur ✏️
3. Modifier les informations
4. Enregistrer
✅ Cours mis à jour
```

## 🔍 Recherche et filtrage

Actuellement, les cours sont :
- Triés par code alphabétiquement
- Affichés avec leurs sessions

**Améliorations futures possibles** :
- Filtre par session
- Recherche par code ou titre
- Tri par pondération
- Export CSV

## ⚠️ Points d'attention

1. **Tabulations** : Le CSV doit utiliser des tabulations, pas des virgules
2. **Sessions** : Vérifiez que les codes de session sont corrects (A, H, A-H, A-É)
3. **Pondérations** : Les nombres doivent être des entiers
4. **Codes uniques** : Évitez les doublons de codes simples

## 🎉 Résumé

Le catalogue de cours est un outil complet pour gérer votre offre de formation :
- Import CSV facile avec données pré-remplies
- Modification individuelle de chaque cours
- Statistiques par session
- Indépendant des tâches pour plus de flexibilité

---

**Prochaine étape** : Utilisez ces cours comme référence lors de la création de groupes dans vos tâches !
