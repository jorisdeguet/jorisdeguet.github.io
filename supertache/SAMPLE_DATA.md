# Exemples de données pour SuperTâche

## Groupes exemple - Session Automne 2024

Copiez-collez ces lignes dans l'écran d'importation :

```
420-SN1-EM, Programmation I, 35, 1.5
420-SN2-EM, Programmation II, 30, 1.5
420-BD1-EM, Bases de données I, 32, 1.2
420-WEB-EM, Développement Web I, 28, 1.3
420-INT-EM, Intégration, 25, 1.8
420-ALG-EM, Algorithmique, 30, 1.4
420-RES-EM, Réseaux, 27, 1.3
420-SYS-EM, Systèmes d'exploitation, 29, 1.6
420-MOB-EM, Développement mobile, 26, 1.7
420-SEC-EM, Sécurité informatique, 24, 1.5
```

## Groupes exemple - Session Hiver 2025

```
420-SN3-EM, Programmation III, 32, 1.5
420-BD2-EM, Bases de données II, 28, 1.3
420-WB2-EM, Développement Web II, 30, 1.4
420-PRO-EM, Projet de fin d'études, 22, 2.0
420-STA-EM, Stage en entreprise, 20, 1.8
420-ANA-EM, Analyse et conception, 25, 1.6
420-QUA-EM, Assurance qualité, 27, 1.4
420-GES-EM, Gestion de projet, 29, 1.3
420-IND-EM, Intelligence d'affaires, 26, 1.5
420-IOT-EM, Internet des objets, 23, 1.7
```

## Scénario de test complet

### Étape 1 : Créer deux sessions

**Session 1:**
- Nom: Automne 2024
- Type: Automne
- Année: 2024

**Session 2:**
- Nom: Hiver 2025
- Type: Hiver
- Année: 2025

### Étape 2 : Importer les groupes

Pour la session Automne 2024, importez les 10 premiers groupes.
Pour la session Hiver 2025, importez les 10 suivants.

### Étape 3 : Tester l'affectation

**Enseignant 1 (vous) - Automne 2024:**
Sélectionnez :
- 420-SN1-EM (CI: 1.5)
- 420-SN2-EM (CI: 1.5)
- 420-BD1-EM (CI: 1.2)
- CI totale attendue: 4.2

**Enseignant 1 (vous) - Hiver 2025:**
Sélectionnez :
- 420-SN3-EM (CI: 1.5)
- 420-BD2-EM (CI: 1.3)
- 420-PRO-EM (CI: 2.0)
- CI totale attendue: 4.8

## Format alternatif (avec tabulations)

Si vous exportez depuis Excel, le format avec tabulations fonctionne aussi :

```
420-SN1-EM	Programmation I	35	1.5
420-SN2-EM	Programmation II	30	1.5
420-BD1-EM	Bases de données I	32	1.2
```

## Format avec espaces multiples

```
420-SN1-EM    Programmation I    35    1.5
420-SN2-EM    Programmation II    30    1.5
420-BD1-EM    Bases de données I    32    1.2
```

## Cas spéciaux

### Groupes avec numéros à 3 chiffres
```
420-123-EM, Cours spécial 123, 30, 1.5
420-456-EM, Cours spécial 456, 28, 1.4
```

### Groupes avec lettres et chiffres
```
420-A1B-EM, Atelier 1B, 25, 1.2
420-C2D-EM, Cours 2D, 27, 1.3
420-X1Y-EM, Projet X1Y, 22, 1.6
```

## Notes sur les CI (Charge Individuelle)

Valeurs typiques :
- Cours théoriques : 1.0 - 1.5
- Cours pratiques : 1.3 - 1.7
- Projets : 1.5 - 2.0
- Stages : 1.8 - 2.5

La CI totale recommandée par enseignant par session : 3.0 - 5.0
