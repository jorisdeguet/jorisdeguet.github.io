# Quelques trucs pour faire de l'algorithmique


## Ne pas essayer de faire un algorithmique pour un truc qu'on ne sait pas faire.

- Nous savons résoudre plein de problèmes
- Un algorithmique est une solution pour résoudre un problème
- Qui a été rendu ultra explicite
- Pour qu'un ordinateur ou quelqu'un qui n'y connait rien
- Puisse résoudre le problème

> Du coup, si on ne sait pas résoudre le problème nous mêmes,
on va avoir du mal à expliquer à quelqu'un comment faire.

Par exemple, on ne peut pas écrire un algorithme pour résoudre
un cube Rubik mélangé si on ne sait pas nous-mêmes comment le faire.

## Voir si ça existe déjà

- librairie
- StackOverflow
- littérature scientifique
- ChatGPT

Juste pour être clair, pendant qu'on apprend, on va sans doute souvent refaire des choses déjà faites.

On veut juste le faire en toute connaissance de cause.

## Connaitre ses outils

Un algorithme est une suite d'instructions qu'on donne à l'ordinateur pour 
résoudre un problème. Il faut savoir ce que l'ordinateur sait déjà faire
pour savoir jusqu'à quel niveau descendre.

Par exemple, est-ce que je dois travailler avec 
- python
- python et toutes les librairies disponibles gratuitement en ligne
- python plus une librairie interne à l'entreprise etc.

Concrètement, à chaque fois qu'on écrit un algorithme, on ajoute un nouvel outil
qu'on n'a plus besoin de programmer

## Identifier ce qu'on doit fournir, ce qu'on obtient

- Qu'est-ce qu'on doit fournir à l'ordinateur pour qu'il puisse résoudre le problème?
- Qu'est-ce qu'on obtient en retour?

## Une recette dans ta langue

> Ecrire en français comment tu fais pour résoudre le problème, détaille jusqu'à ce
qu'un ami qui n'y connait rien pourrait sans doute le faire.

Essaie d'appliquer la "recette" sur quelques exemples.

## Déterminer des sous-problèmes et en faire des sous-algorithmes

Il se peut qu'en écrivant notre algorithme, on identifie des sous-problèmes bien identifiés.

Si on essaie de faire la solution en décrivant toutes les étapes, ça peut devenir lourd. 

Ne pas hésiter à identifier des sous-problèmes et les adresser plus tard ou même chercher des
algorithmes existants.


La suite de ce document est une suite d'exemples. On peut les lire, on peut essayer de les
résoudre par soi-même. Pour comprendre, pour apprendre.


## Trouver les traitements répétitifs

Un algorithmique requiert souvent de faire un même traitement plusieurs fois. En programmation
impérative, notre outil principal pour cela est la boucle. On aura tendance à choisir entre:
- Tant que **quelque chose est vrai** faire **tout un traitement**
- Pour tous les **un ensemble de trucs** faire **un traitement sur le truc**

En général, on utilise la première solution quand on ne sait pas combien de fois on va faire le traitement.

La seconde solution on sait combien il y a de trucs, on veut juste tous les traiter.

## Ecrire tout dans un langage bizarre, en code ou les deux

Pour commencer un algorithme, il faut savoir ce qu'on vise:
- expliquer à des gens, pour cela on a des langages
- expliquer / programmer pour une machine, pour ça on a des langages de programmation

Le but final est d'avoir un langage sans ambiguité, pas toujours le même:
- pour les humains, 
  - on peut utiliser un langage naturel
  - on peut utiliser un langage pseudo-code
- pour les machines, on peut utiliser un langage de programmation

------------



## Exemple 0 : faire cuire des pâtes

### Est-ce que je sais faire?
Oui je sais faire cuire des pâtes!

### Quels outils j'ai à ma disposition?
Il me faudrait un robot humanoïde pour faire des pâtes pour moi.

Je vais imaginer qu'il existe et qu'il a des opérations de base:
- prendre
- verser
- détecter de l'eau bouillante
- régler le four

### Comment l'exprimer en français

On commence avec la version 1:
```
Mettre beaucoup d'eau dans une casserole
Ajouter 3 grosses poignées de sel
Faire bouillir
Quand l'eau bouille ajouter les pâtes
Remuer de temps en temps
Vérifier la cuisson puis égoutter les pâtes
Servir
```

Il y a pas mal de choses vagues: 
- "beaucoup" d'eau
- des "grosses" poignées
- "de temps en temps"

Essayons d'être plus précis dans une version 2
```
Mettre 5 litres d'eau dans une casserole d'une contenance de 10 litres
Ajouter 150 grammes de sel dans la casserole
Placer sur un appareil chauffant de 1500W au réglage maximum
Tant que l'eau ne bouille pas, revenir voir si l'eau frémit toutes les minutes
Ajouter les pâtes dans la casserole
Remuer en faisant 3 mouvements circulaires avec une cuillère en bois
Vérifier que l'eau revient à ébulition toutes les 20 secondes jusqu'à ébulition
Baisser l'élément chauffant à 40% de sa puissance
Tant que le temps de cuisson n'a pas atteint 10 minutes, remuer en faisant 
3 mouvements curculaires avec une cuillère en bois toutes les 2 minutes
Baisser l'élément chauffant à 0% de sa puissance
Verser le contenu de la casserole dans une passoire
Servir
```

### Est-ce que je vois des sous-problèmes?

Il semble qu'il va falloir remuer les pâtes plusieurs fois. Je le vois parce
que je me retrouve avec des répétitions dans le texte.

Je vais sans doute avoir un sous algorithme de mélange des pâtes dans la casserole

### Trouver les traitements répétitifs

"Tant que", "répéter", "jusqu'à", "tous les ..." sont des indices de répétitions, de boucles.
- Tant que l'eau ne bouille pas. 
  - Ici on ne sait pas quand elle va bouillir, 
  - ce sera un **tant que** qui quitte dès que l'eau bouille
- Vérifier que l'eau revient à ébulition. 
  - Pareil, on ne sait pas combien de fois il faudra retourner voir
  - un **tant que** qui quitte quand l'eau bouille
- Remuer en faisant 3 mouvements circulaires
  - Ici on sait que c'est 3 fois.
  - On ira avec un for qui garantit 3 passages
- Tant que le temps de cuisson n'a pas atteint 10 minutes. 
  - Ici c'est moins clair. 
  - La phrase dit "Tant que" 
  - mais on sait qu'il faut y aller toutes les 2 minutes jusqu'à 10 minutes
  - Il faut donc remuer à 120 secondes (2 minutes), à 240, à 360, à 480 et à 600 secondes
  - Donc ce sera plutôt un "pour tous les 2 minutes de 1 à 5"

### Expression dans un langage

Ici je vais imaginer que mon robot humanoïde est livré avec une librairie de fonctions en Python
- "verser(élément, contenant)"
- "transverser(contenant1, contenant2)"
- "placerSur(objet1, objet2)"
- "tournerObjet(objet)"
- "regler(chauffant, pourcentage)"
- "detecterEtat(contenant)"
- "attendre(secondes)"

```python
def cuireLesPages(pates):
    casserole = casserole10Litres()
    chauffant = elementChauffant1500W()
    passoire = passoire()
    verser( eauEnLitres(5), casserole)                  #Mettre 5 litres d'eau dans une casserole d'une contenance de 10 litres
    verser( selEnGrammes(150), casserole)               #Ajouter 150 grammes de sel dans la casserole
    placerSur(casserole, chauffant)                     #Placer sur un appareil chauffant de 1500W 
    regler(chauffant, 100)                              #au réglage maximum
    while detecterEtat(casserole) != "bouillant":       #Tant que l'eau ne bouille pas
        attendre(60)                                    # , revenir voir si l'eau frémit toutes les minutes
    verser(pates, casserole)                            # Ajouter les pâtes dans la casserole
    melanger(casserole)                                 # melanger n'existe pas, je m'en occuperai plus tard
    while detecterEtat(casserole) != "bouillant":       # Vérifier que l'eau revient à ébulition    
        attendre(20)                                    # toutes les 20 secondes jusqu'à ébulition
    regler(chauffant, 40)                               # Baisser l'élément chauffant à 40% de sa puissance
    for temps in range(1, 6):                           # Tant que le temps de cuisson n'a pas atteint 10 minutes, remuer en faisant 
        attendre(120)
        melanger(casserole)                             #3 mouvements curculaires avec une cuillère en bois toutes les 2 minutes
    regler(chauffant, 0)                                #Baisser l'élément chauffant à 0% de sa puissance
    transverser(casserole, passoire)                    #Verser le contenu de la casserole dans une passoire       
    return pates                                        #Servir
```

Ici on a poussé un sous-algorithme plus loin:
```python
def melanger(contenant):
    cuillere = obtenirCuillere()
    placerSur(cuillere, contenant)
    for fois in range(1,4):                             # 3 fois
        tournerObjet(cuillere)
```


## Exemple 1 : trouver les anagrammes de mon prénom

Personne n'a dit qu'on devait écrire des algorithmes utiles.

### est-ce que je sais faire?
Si je regarde dans le dictionnaire:
- Mot formé en changeant de place les lettres d'un autre mot

Je comprends que
- il faut que ce soit un mot mettons un mot du dictionnaire en français, ça semble raisonnable
- il me semble que j'ai 2 approches:
  - regarder chaque mot du dictionnaire et voir si c'est un réarrangement des lettres de mon nom
  - regarder tous les réarrangements de mon nom et voir si c'est un mot du dictionnaire

Arrrrgggggghhhhhh, il n'y pas forcément qu'un seul algorithme pour résoudre un problème.

En tout cas, je sais faire et même sans doute de 2 manière différente

### Quels outils j'ai à ma disposition?
Alors j'ai python, avec des boucles, des variables de type texte (string).

Il me faudrait aussi un moyen d'avoir les mots du dictionnaire.

### Exprimer en français

```

```


## Ecrire un nombre en toutes lettres en français
https://bescherelle.ca/ecriture-des-nombres/

On va commencer par clarifier qu'on veut pouvoir écrire un nombre entier en toutes lettres

https://numbertext.github.io

## Trouver la date 


