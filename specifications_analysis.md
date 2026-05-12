# Analyse du Cahier des Charges - SwipeWar (Côté Visuel)

Ce document analyse le cahier des charges (spécifications PDF) de **SwipeWar** et le compare avec l'état actuel de notre projet Godot. Il dresse le bilan de ce qui est déjà achevé et de ce qu'il reste à accomplir pour la partie **visuelle, UI et UX**.

---

## 1. Bilan de l'Alignement Visuel & UX

L'ensemble des écrans et du flux de jeu décrits dans le cahier des charges (Pages 6 à 10) est déjà **entièrement implémenté** avec un niveau de fidélité et de dynamisme extrêmement élevé ("juice" de jeu mobile).

### Écrans et Flux UI (Fidélité 100%)

| Spécification du Cahier des Charges | État Actuel dans le Projet | Verdict |
| :--- | :--- | :--- |
| **Philosophie "Native Mobile"** (p. 6)<br>- Pas de survol (Hover)<br>- Zones de clic > 44px pour les pouces. | Les boutons et l'interface sont optimisés à 100% pour le tactile. Les zones de clic font au moins 50px de hauteur. | **Conforme** |
| **Menu Principal (Écran 1)** (p. 6)<br>- Logo/Identité visuelle claire.<br>- Boutons "New Game" et "Quit". | Implémenté (`main_menu.tscn`). Nous avons ajouté une **animation de respiration idle** sur le logo et un effet élastique au clic des boutons. | **Conforme + Amélioré** |
| **Game Setup (Écran 2)** (p. 6-8)<br>- Réglage du nombre de véhicules (1 à 5).<br>- Réglage des Points d'Action (1 à 10).<br>- Réglage des Points de Vie (10 à 100). | Implémenté (`game_setup.tscn`) sous forme de Steppers tactiles (cartes de paramètres avec boutons +/- et range text). Ajout d'une **animation de rebond textuel** au clic. | **Conforme + Amélioré** |
| **Interface In-Game (HUD)** (p. 7-9)<br>- Affichage P1 / AP en haut.<br>- Grille 8x8 centrale avec obstacles.<br>- Panneau de contrôle bas (Move, Shoot, End Turn). | Implémenté (`hud.tscn` et `ui_test_scene.gd`). Les boutons Move et Shoot changent de couleur de manière fluide selon l'état sélectionné. | **Conforme** |
| **Écran de Victoire** (p. 8-10)<br>- Trophée de récompense.<br>- "Player X Wins".<br>- Cartes de métriques (Éliminations, Tours, Précision). | Implémenté (`victory_screen.tscn`). Ajout d'**explosions de confettis (particules)**, d'un zoom d'apparition élastique du trophée et d'une oscillation continue. | **Conforme + Amélioré** |

---

## 2. Ce qui a été Résolu pour le Tactique & Mouvement (Swipe)

Le problème de déplacement où le "swipe" ne fonctionnait pas a été **entièrement résolu et optimisé** pour offrir une expérience tactile d'élite :
1. **Swipe depuis n'importe où** : Auparavant, le joueur devait cliquer *exactement* dans un rayon minuscule de 40px autour du tank pour commencer à glisser. Désormais, dès qu'un tank allié est actif en mode `Move`, le joueur peut **glisser son doigt depuis n'importe quel endroit de la grille**, ce qui évite de masquer le tank avec le pouce et rend l'interaction 100% fiable.
2. **Feedback d'erreur explicite** : Si le joueur tente un déplacement hors des limites de la grille, le jeu affiche désormais un texte flottant rouge stylisé **"Hors Limites !"** au lieu de bloquer silencieusement l'action.
3. **Marge de tolérance (Epsilon)** : Un décalage de 2px a été introduit dans les limites de la grille (`60px` à `372px` en X, `200px` à `512px` en Y) pour corriger les imprécisions mathématiques liées aux calculs de flottants en Godot, empêchant tout blocage accidentel.
4. **Correction de typage & logs** : Les détections de touchers et de déplacements utilisent maintenant des propriétés d'événements stables (`event.pressed`) et impriment des diagnostics clairs dans la console pour faciliter le suivi.

---

## 3. Ce qu'il reste à faire (Côté Visuel / UI / UX uniquement)

Puisque tu es en charge du **côté visuel**, voici les opportunités d'amélioration et les tâches restantes pour sublimer la direction artistique :

### 🚀 Tâche 1 : Concevoir les variations visuelles des Véhicules (Cahier des Charges p. 10)
Le cahier des charges mentionne dans son diagramme de classes trois types de véhicules héritant de `Vehicle` :
* **Tank** : Lourd, forte friction, déplacement lent.
* **Car (Voiture)** : Moyenne, friction modérée.
* **Plane (Avion/Glisseur)** : Léger, friction très basse, glisse loin.

> [!TIP]
> **Action Visuelle** : Actuellement, tous les tanks alliés utilisent le même dessin vectoriel 2D cyan. Tu peux modifier `_draw_vector_tank()` dans `ui_test_scene.gd` pour dessiner des silhouettes vectorielles distinctes et magnifiques pour chaque type de véhicule :
> * **Le Tank** : Châssis large et angulaire, chenilles renforcées très visibles, double canon ou gros canon à rail électromagnétique.
> * **La Voiture** : Châssis aérodynamique plus mince, 4 roues néon lumineuses à la place des chenilles.
> * **L'Avion (Glisseur)** : Ailes inversées profilées, ailerons latéraux néon, double tuyère de réacteur plasma à l'arrière.

### 💥 Tâche 2 : Effets de Particules et Visual Juiciness
Pour que le jeu paraisse extrêmement dynamique et premium sur mobile, plusieurs effets de rétroaction visuelle (VFX) peuvent être ajoutés :
1. **Traces de déplacement** : Ajouter un petit émetteur de particules de fumée ou d'étincelles néon (`CPUParticles2D`) derrière le tank actif lorsqu'il se déplace sur la grille.
2. **Impact de collision** : Lorsque le gameplay programmer connectera la physique et que les chars heurteront un mur ou un obstacle, déclencher un éclat d'étincelles néon de la couleur de l'équipe (Cyan pour P1, Rouge pour P2) au point d'impact.
3. **Explosion de destruction** : Lorsqu'un tank tombe à 0 PV, au lieu de simplement le faire disparaître, déclencher une superbe explosion vectorielle (disparition progressive en échelle, flash blanc et projection de débris géométriques néons).

### 🎨 Tâche 3 : Intégration des Icônes Réelles du Figma
Pour le moment, l'écran de configuration utilise des symboles textuels temporaires ou des formes de base.
* **Action** : Récupérer les vrais tracés vectoriels (ou fichiers SVG) depuis la maquette Figma pour :
  - L'icône de véhicule (Card Véhicules).
  - L'icône de foudre/énergie (Card AP).
  - L'icône de cœur (Card HP).
  - Et les intégrer dans les textures des boutons et des cartes pour finaliser la fidélité graphique.
