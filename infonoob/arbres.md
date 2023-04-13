
## Python vue ensemble

Quoi faire quand ça compile pas?
Quoi faire quand ça marche pas?
Comprendre les messages d'erreur?
Optimisation : intro quand en faire, quand on a un problème de performance

Quoi faire quand je suis bloqué?
 - commencer simple et espérer que ça me met dedans
 - demander à quelqu'un qui en fait du Python
 - regarder sur Google / stackoverflow
 - demander à ChatGPT

Est-ce qu'on peut mettre un continue dans une fonction? Ça fait quoi? ca arrete la boucle englobante?

for i in range(10):
    print('in boucle 1', i)
    for j in range(10):
        print('in boucle 2', i, j)
        if j == 5:
            continue
        print('out boucle 2')
    print('out boucle 1')

```mermaid
flowchart LR;
    core(Python fondamentaux)
    objet(Python orienté objet)
    fichiers(Python et les fichiers)
    web(Python pour un serveur web)
    sciences(Python pour les sciences)
    admin(Python pour l'administration système)
    data(Python pour les données)
    ai(Python pour l'intelligence artificielle)
    ui(Python et interface graphique utilisateur)
    mobile(Python pour les applications mobiles)
    core-->fichiers-->admin
    core-->sciences
    core-->web
    core-->objet
    fichiers-->sciences
    core-->sciences-->ai
    core-->data
    core-->ui
    core-->mobile
```

## Python fondamentaux

```mermaid
flowchart LR;
    execInter(Python interactif)
    execScript(Python script)
    execJupyter(Python Jupyter)
    execModule(Python module et multifichier)
    expr1(Constante, valeur et type)
    expr2(Expression et opérateur)
    expr3(Tableaux, tuples, dictionnaires)
    expr4(Variables)
    flowSeq(Flot d'exécution séquence )
    flowIf(Flot d'exécution alternative)
    flowFor(Flot d'exécution répétition)
    flowError(Flot d'exécution erreur, lance et attrape)
    flowRec(Flot d'exécution 4 récursion)
    fonction1(Appel fonction existante)
    fonction2(Définition d'une fonction syntaxe, type)
    fonction3(Définition d'une fonction syntaxe, type)
    fonction4(Récursivité)
    
    expr1-->expr2-->expr3
    execInter-->execScript-->execJupyter
    execScript-->execModule
    flowSeq-->flowIf-->flowFor
    flowSeq-->flowError
    fonction1-->fonction2-->fonction3-->fonction4
    execScript-->np1
    flowFunction-->np1
```

## Python : librairies pour les sciences

```mermaid
flowchart LR;
    pandas1(Pandas 1 import export)
    pandas2(Pandas 2 dataframe et modif)
    pandas3(Pandas 3 interaction avec autres librairies)
    np1(Numpy 1 tableaux)
    matplotlib1(MatPlotLib 1 graphique de base)
    matplotlib2(MatPlotLib 2 graphique depuis une formule)
    matplotlib3(MatPlotLib 3 graphique depuis des données)
    
    matplotlib1-->matplotlib2-->matplotlib3
    np1-->matplotlib2
    pandas1-->pandas2-->pandas3
```

## Info : binaire et représentations

```mermaid
flowchart LR;
    binaire(Binaire 0 1 et la base 2)
    caractere(Lettres et caractères)
    texte(Un texte en binaire)
    image(Couleurs et pixels)
    video(Vidéo)
    son(Son)
    compressionVideo(Compression d'images et de vidéos)
    encryption(Chiffrement, encryption)
    
    binaire-->caractere-->texte
    texte-->encryption
    
    binaire-->son-->video-->compressionVideo
    binaire-->image-->video-->film
```

## Info : web

URL relative et absolue


```mermaid

Distinguer les lessons et les projets qui nécessitent les leçons.

## Info : algorithme et résolution de problème

```mermaid
flowchart LR;
    algoBase(Fondamentaux de l'algorithmique)
    algoStructure(Algorithme et structures de données)
    algoOuML(Choisir entre algorithmique et apprentissage artificiel)
    mlBase(Fondamentaux de l'apprentissage artificiel)
    mlTransformer(Apprentissage et transformers)
    mlRenforcement(Apprentissage par renforcement)
    mlReseauxNeurones(Apprentissage de réseaux de neurones)
    
    algoBase-->algoStructure
    algoBase-->algoOuML
    mlBase-->algoOuML
    mlBase-->mlReseauxNeurones-->mlTransformer
    mlBase-->mlRenforcement
```

## Gestion de versions fichiers textes : Git et Github

```mermaid
flowchart LR;
    gitBase(Fondamentaux de git, dossier, commit)
    gitLocalRemote(Repo local et distant, push et pull)
    gitBranches(Git et les branches)
    gitPourNonDev(Git pour tout le monde)
    gitBase-->gitLocalRemote
    gitBase-->gitPourNonDev
    gitBase-->gitBranches
```


