# Swipe War

Jeu de combat tactique au tour par tour, jouable entièrement au swipe (glissement du doigt), développé sous Godot 4.6 en GDScript. Le jeu est pensé pour mobile (format portrait) et exporté à la fois en version web (GitHub Pages) et en APK Android via CI/CD.

## Principe du jeu

Chaque joueur compose une équipe de véhicules (tank, voiture, avion) dans la limite d'un budget, puis affronte son adversaire sur une carte géante de 64x64 cases. À chaque tour, on sélectionne une unité et on fait un swipe pour la déplacer ou tirer. La puissance du mouvement dépend du timing du relâchement (mini jeu de précision avec une zone "Perfect Launch").

Trois modes de jeu sont disponibles : joueur contre IA, deux joueurs sur le même appareil (J1 vs J2), ou IA contre IA en mode démonstration autonome.

## Fonctionnalités techniques

- Déplacement physique continu basé sur la masse et la force de chaque véhicule (tank lourd et court, avion léger et long), avec le moteur Jolt Physics.
- Détection de collision par balayage pixel par pixel (sweep check) pour éviter les effets tunnel à travers les murs et obstacles.
- Rendu vectoriel procédural : tous les véhicules sont dessinés directement en code via `_draw()`, sans aucun sprite ou image externe.
- Caméra avec zoom et déplacement libre sur la carte (molette ou pincement à deux doigts sur mobile).
- Génération procédurale des cartes selon plusieurs presets (classique, croix, piliers, couloir).
- IA autonome capable de jouer seule ou contre un joueur humain.

## Stack technique

- Moteur : Godot Engine 4.6
- Langage : GDScript
- Physique : Jolt Physics
- Tests : GUT (Godot Unit Test), tests unitaires et smoke tests
- Déploiement : GitHub Actions vers GitHub Pages (web) et export Android (APK)

## Structure du projet

```
ui/
  ui_test_scene.gd        cœur du gameplay (grille, tours, swipe, tir, IA, rendu)
  ui_manager.gd            routeur d'écrans (menu, config, HUD, victoire)
  common/                  classe de base des écrans, composants réutilisables
  screens/                 menu principal, configuration de partie, HUD, écran de victoire
test/
  unit/                    tests unitaires (règles de jeu, grille, budget)
  smoke/                   tests de chargement des scènes
web_extra/                 page de présentation et de téléchargement (GitHub Pages)
```

## Lancer le projet

1. Installer Godot 4.6 ou une version plus récente compatible.
2. Ouvrir le dossier du projet dans Godot (`project.godot`).
3. Lancer la scène principale (`ui/ui_test_scene.tscn` est le point d'entrée du jeu).

## Tests

Le projet utilise l'addon GUT pour les tests unitaires et les smoke tests, exécutables directement depuis l'éditeur Godot ou en ligne de commande.

## Contexte

Projet réalisé dans le cadre d'un cursus BUT Informatique (SAE), avec une chaîne de déploiement continue vers le web et Android.
