# VIVI AU SKI : Descente Royale 3D (`v1.2.0+3`)

Application mobile **Android & iOS** développée en **Flutter / Dart (Sound Null Safety strict, moteur Impeller 60–120 FPS)** mettant en scène les **3 figurines 3D Cycles officielles Vivienne** du studio [`orbitalstorm/BLENDER_LAB`](https://github.com/orbitalstorm/BLENDER_LAB) dans une simulation de ski alpin haute vitesse en **3D Cartoon vue de derrière**.

## Nouveautés Majeures (`v1.2.0+3`)

- **Identifiant Store** : `cloud.orbital8.vivi_au_ski` (`version: 1.2.0+3`, Portrait Android & iOS).
- **Dénivelés Vertigineux & Haute Vitesse** :
  1. **Vallée Blossom Ensoleillée** (*Piste Verte* • `1 200 m` • Dénivelé `-535 m` (`24°`) • `62–108 km/h` • 4 tremplins)
  2. **Forêt des Sapins d'Asnières** (*Piste Bleue* • `1 800 m` • Dénivelé `-980 m` (`34°`) • `84–142 km/h` • 7 tremplins)
  3. **Cimes Étoilées Vendôme** (*Piste Noire Or* • `2 500 m` • Dénivelé `-1 650 m` (`45°`) • `108–185 km/h` • Aurore boréale & 10 méga-tremplins *Big Air*)
- **3 Modèles 3D Cycles Officiels `BLENDER_LAB` Jouables (`VivienneSkiEdition`)** :
  - **Vivienne Speedy v03** (`models/vivienne_speedy_v03.blend`) : Chêne clair, pétales Vachetta `#E3A17B` & Mini Sac Speedy LV attaché à la main gauche (poses Cycles `180°` dos & `0°` face).
  - **Vivienne Wonderland** (`models/vivienne_wonderland.blend`) : Toile Monogram Ébène `#2B1D14`, Petit Lapin Blanc perché au sommet du pétale supérieur & Ballon Cœur Rouge Laqué `#D91E48` sur tige dorée passant devant le pétale.
  - **Vivienne Giant Denim** (`models/vivienne_giant_denim.blend`) : Denim Bleu Indigo Jacquard `#3B6291`, Sneakers streetwear 3D sur les skis, Étiquette `LOUIS VUITTON` & Grand Skateboard LV à 4 roues blanches.
- **Sauts Bonus `Saut 360°` (`+250 pts`) & `Saut Périlleux` (`+300 pts`)** :
  - Alternance automatique sur les tremplins et bosses rapides entre vrilles `360°` (bascule fluide entre rendus Cycles `180°` dos et `0°` face + halo doré) et saltos `Périlleux` complets (`0 -> 2π` avec ruban d'étoiles).
- **Télésièges Obliques Infinis, Parallaxe Continue & Banderoles `LV_NEO`** :
  - Lignes de télésièges/télécabines obliques traversant tout le domaine d'un bord à l'autre de l'écran (`-220 m .. +220 m`, 6 pylônes treillis 3D et 10 cabines/sièges animés), parallaxe continue sans saccade sur les sommets alpins, banderoles latérales 3D `LV_NEO`, chute cartoon en boule de neige sur sapin et menu Pause en course.
- **Contrôle Accéléromètre Natif 60 Hz** (`MainActivity.kt` Android / `AppDelegate.swift` iOS) + calibrage instantané et contrôles tactiles/clavier.

## Commandes de Validation

```bash
/tmp/flutter-sdk/flutter/bin/flutter analyze
/tmp/flutter-sdk/flutter/bin/flutter test
/tmp/flutter-sdk/flutter/bin/flutter build apk --release
```
