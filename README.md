# VIVI AU SKI : Descente Royale 3D (`v1.1.0+2`)

Application mobile **Android & iOS** développée en **Flutter / Dart (Sound Null Safety strict, moteur Impeller 60–120 FPS)** mettant en scène les figurines 3D officielles **Vivienne** du studio [`orbitalstorm/BLENDER_LAB`](https://github.com/orbitalstorm/BLENDER_LAB) dans une simulation de ski alpin haute vitesse en **3D Cartoon vue de derrière**.

## Nouveautés Majeures (`v1.1.0+2`)

- **Identifiant Store** : `cloud.orbital8.vivi_au_ski` (`version: 1.1.0+2`, Portrait Android & iOS).
- **Dénivelés Vertigineux & Haute Vitesse** :
  1. **Vallée Blossom Ensoleillée** (*Piste Verte* • `1 200 m` • Dénivelé `-535 m` (`24°`) • `62–108 km/h` • 4 tremplins)
  2. **Forêt des Sapins d'Asnières** (*Piste Bleue* • `1 800 m` • Dénivelé `-980 m` (`34°`) • `84–142 km/h` • 7 tremplins)
  3. **Cimes Étoilées Vendôme** (*Piste Noire Or* • `2 500 m` • Dénivelé `-1 650 m` (`45°`) • `108–185 km/h` • Aurore boréale & 10 méga-tremplins *Big Air*)
- **4 Modèles Officiels `BLENDER_LAB` Jouables (`VivienneSkiEdition`)** :
  - **Vivienne Speedy v03** (`models/vivienne_speedy_v03.blend`) : Chêne clair, pétales Vachetta `#E3A17B` & Mini Sac Speedy LV.
  - **Vivienne Wonderland** (`models/vivienne_wonderland.blend`) : Toile Monogram Ébène `#2B1D14`, Petit Lapin Blanc perché au sommet du pétale supérieur & Ballon Cœur Rouge Laqué `#D91E48` sur tige dorée.
  - **Vivienne Giant Denim** (`models/vivienne_giant_denim.blend`) : Denim Bleu Indigo Jacquard `#3B6291`, Sneakers streetwear fuchsia/blanc sur les skis, Étiquette `LOUIS VUITTON` & Grand Skateboard LV à 4 roues blanches.
  - **Vivienne LV_NEO Blossom** (`models/vivienne_lv_neo_blossom.blend`) : Corolle Rose Sakura `#F3B7C3`, écharpe et skis bleu cobalt `LV_NEO` `#1638E8`.
- **Chute Cartoon en Boule de Neige sur Sapin (`VivienneSkiAnimState.snowballCrash`)** :
  - Percuter un sapin déclenche une chute burlesque en boule de neige bosselée 3D grossissante (`1.1x -> 1.55x`, `3` tours complets) d'où dépassent les skis, baskets, pétales et accessoires de Vivienne avec projection d'aiguilles de sapin et de poudreuse.
- **Banderoles 3D `LV_NEO` & Décors Alpins Vivants** :
  - Banderoles latérales 3D `LV_NEO` (`assets/sprites/lv_neo_banner.png`) tout le long des deux côtés de la piste, télécabines alpines animées sur câble aérien, bonhommes de neige qui saluent, canons à neige actifs, mâts à fanions/supporters, chalets éclairés à mi-piste et montgolfières LV Blossom.
- **Contrôle Accéléromètre Natif 60 Hz** (`MainActivity.kt` Android / `AppDelegate.swift` iOS) + calibrage instantané et contrôles tactiles/clavier.

## Commandes de Validation

```bash
/tmp/flutter-sdk/flutter/bin/flutter analyze
/tmp/flutter-sdk/flutter/bin/flutter test
/tmp/flutter-sdk/flutter/bin/flutter build apk --release
```
