# tuto-trace

Exécution pas à pas de petits programmes **Python, C# et Dart** pour l'enseignement :
chemins possibles des structures (flèches sur le code), explications FR / EN / ES,
pile d'appels, trace, console et erreurs de compilation.

Publié sur https://jorisdeguet.github.io/tuto-trace/

## Développer

```sh
npm install
npm run dev      # serveur de développement
npm test         # tests du moteur (sorties comparées au vrai Python / Dart)
npm run deploy   # vérifie les types et construit dans ../tuto-trace/ (à commiter)
```

## Organisation

- `src/engine/` : moteur sans dépendance à Vue. Un parser par langage (`lang/python.ts`,
  `lang/clike.ts` pour C# et Dart) produit un AST commun ; `check.ts` fait la vérification
  de types (C# / Dart) ; `interpreter.ts` est un générateur qui produit un pas par instruction
  avec un instantané de la pile ; `flow.ts` calcule les arcs dessinés sur le code.
- `src/examples/<langage>/` : la bibliothèque d'exemples (même série pour les trois langages),
  déclarée dans `src/examples/index.ts`.
- `src/i18n/` : textes FR / EN / ES (`en.ts` et `es.ts` sont typés sur `fr.ts`) et
  `real.ts`, les messages authentiques des compilateurs / environnements d'exécution.
- `tests/expected-real.json` : sorties produites par `python3` et `dart run` pour chaque exemple.
  Après ajout d'un exemple, régénérer ce fichier pour garder la comparaison.

## Lien et intégration (sans base de données)

Tout est dans le hash de l'URL : `#lang=python&ui=fr&ex=while-counter` ou `#lang=dart&code=<lz-string>`.
Options : `embed=1`, `readonly=1`, `autoplay=1`, `speed=3`, `step=5`, `src=<code en clair>`.

Intégration avec hauteur automatique : voir `public/demo-embed.html` (`embed.js`).
