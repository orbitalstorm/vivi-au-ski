# VIVI AU SKI : Descente Royale 3D (`v1.4.0+5`)

Application mobile **Android & iOS** développée en **Flutter / Dart (Sound Null Safety strict, moteur Impeller 60–120 FPS)** mettant en scène les **3 figurines 3D officielles Vivienne** du studio [`orbitalstorm/BLENDER_LAB`](https://github.com/orbitalstorm/BLENDER_LAB) rendues par un **vrai moteur 3D volumétrique temps réel & rig squelettique articulé 22+ os (`lib/painters/vivienne_3d_volumetric_rig.dart`)**.

## Nouveautés Majeures (`v1.4.0+5`)

- **Identifiant Store** : `cloud.orbital8.vivi_au_ski` (`version: 1.4.0+5`, Portrait Android & iOS).
- **Posture de Ski Alpin Parallèle Authentique (Zéro Cycle de Marche)** :
  - Skis et jambes solidaires parallèles longitudinalement en glisse et en carving (`glidingRearNeutral`, `carvingLeft`, `carvingRight`), suspension synchrone des genoux sur le relief, angulation de carre asymétrique en virage et bras profilés aérodynamiques sans balancement de marche.
- **Relief Alpin Multi-Sections & Cassures de Pente Occultantes** :
  - Alternance de **replats et crêtes convexes** remontant au-dessus de l'horizon pour masquer le bas des montagnes d'arrière-plan et occulter la piste en aval, suivis de **murs de descente plongeants** accélérant Vivienne et dévoilant toute la vallée en contrebas.
- **Bosses 3D Maillées dans la Piste (`22 / 34 / 48`) & 3 Tailles de Tremplins (`SkiRampSizeTier`)** :
  - Maillage 3D de neige subdivisé en `10` colonnes transversales déformées continûment par les bosses (`snowSurfaceHeightAt`) et **3 catégories de tremplins** sur chaque piste (`Mini Tremplin`, `Tremplin Blossom`, `Méga Tremplin Big Air` à contreforts latéraux 3D et fanions).
- **2 Modes de Jeu Complets (`DESCENTE & BOSSES` & `SLALOM COMPLET`)** :
  - Sélecteur de mode dès l'accueil (`SkiGameMode`), parcours Slalom Complet (`28`, `38` et `50` portes alternant strictement **Gauche Rouge/Or** et **Droite Bleu/Azur**), trace idéale 3D en S sur la neige, piquets articulés sur rotules flexibles et compteur HUD Slalom temps réel (`PORTES X / TOTAL • COMBO ×Y`).
- **Spectateurs 3D Vivienne Animés en Bord de Piste (`BLENDER_LAB`)** :
  - Supporters 3D issus des **3 modèles officiels** (`Speedy v03`, `Wonderland`, `Giant Denim`) répartis des deux côtés de la piste, agitant les bras en V et sautant de joie sur place (`waveArms`, `jumpAndWave`, `doubleJumpCheer`, zéro cycle de marche) avec cache FK et LOD 60–120 FPS.
- **3 Pistes Alpines Complètes (`SkiTrackId`)** :
  1. **Vallée Blossom Ensoleillée** (*Piste Verte* • `1 200 m` • `-535 m` (`24°`) • `22` bosses • `6` tremplins • `28` portes Slalom)
  2. **Forêt des Sapins d'Asnières** (*Piste Bleue* • `1 800 m` • `-980 m` (`34°`) • `34` bosses • `9` tremplins • `38` portes Slalom)
  3. **Cimes Étoilées Vendôme** (*Piste Noire Or* • `2 500 m` • `-1 650 m` (`45°`) • `48` bosses • `12` tremplins *Big Air* • `50` portes Slalom)
- **Contrôle Accéléromètre Natif 60 Hz** (`MainActivity.kt` Android / `AppDelegate.swift` iOS) + calibrage instantané et contrôles tactiles/clavier.

## Commandes de Validation

```bash
/tmp/flutter-sdk/flutter/bin/flutter analyze
/tmp/flutter-sdk/flutter/bin/flutter test
/tmp/flutter-sdk/flutter/bin/flutter build apk --release
```
