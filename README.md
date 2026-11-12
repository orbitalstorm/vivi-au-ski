# VIVI AU SKI : Descente Royale 3D (`v1.3.0+4`)

Application mobile **Android & iOS** développée en **Flutter / Dart (Sound Null Safety strict, moteur Impeller 60–120 FPS)** mettant en scène les **3 figurines 3D officielles Vivienne** du studio [`orbitalstorm/BLENDER_LAB`](https://github.com/orbitalstorm/BLENDER_LAB) rendues par un **vrai moteur 3D volumétrique temps réel & rig squelettique articulé 22+ os (`lib/painters/vivienne_3d_volumetric_rig.dart`)**.

## Nouveautés Majeures (`v1.3.0+4`)

- **Identifiant Store** : `cloud.orbital8.vivi_au_ski` (`version: 1.3.0+4`, Portrait Android & iOS).
- **Moteur de Rendu 3D Volumétrique & Squelettique 22+ Os (`Vivienne3DVolumetricRig` + `Vivienne3DViewport`)** :
  - Zéro sprite 2D plat ni écrasement `cos(yaw)` : maillages 3D fermés triangulés (`ui.Vertices.raw(ui.VertexMode.triangles, ...)`), tri Z en profondeur, élimination des faces cachées, éclairage PBR Studio 3 points + spéculaire Blinn-Phong et contour silhouette 3D *Inverted Hull* `#2B1105`.
  - Tête 3D ellipsoïdale en bois (`0.56 m` d'épaisseur Y) avec yeux 3D en relief sur `-Y`, 4 pétales 3D épais (`thickness = 0.072`) à tranches rouge carmin `#8B1E24` / indigo `#1D3557`, jambes/genoux/pieds/sneakers et skis paraboliques 3D indépendants, bras articulés à tranches carmin, bâtons de ski 3D et accessoires 3D volumétriques animés.
- **Dénivelés Vertigineux & Haute Vitesse** :
  1. **Vallée Blossom Ensoleillée** (*Piste Verte* • `1 200 m` • Dénivelé `-535 m` (`24°`) • `62–108 km/h` • 4 tremplins)
  2. **Forêt des Sapins d'Asnières** (*Piste Bleue* • `1 800 m` • Dénivelé `-980 m` (`34°`) • `84–142 km/h` • 7 tremplins)
  3. **Cimes Étoilées Vendôme** (*Piste Noire Or* • `2 500 m` • Dénivelé `-1 650 m` (`45°`) • `108–185 km/h` • Aurore boréale & 10 méga-tremplins *Big Air*)
- **3 Modèles 3D Volumétriques `BLENDER_LAB` Jouables (`VivienneSkiEdition`)** :
  - **Vivienne Speedy v03** (`models/vivienne_speedy_v03.blend`) : Chêne clair, pétales Vachetta `#E3A17B` à tranche rouge carmin `#8B1E24` & Mini Sac Speedy LV 3D oscillant à la main gauche.
  - **Vivienne Wonderland** (`models/vivienne_wonderland.blend`) : Toile Monogram Ébène `#2B1D14`, Petit Lapin Blanc 3D à longues oreilles rebondissantes sur le pétale supérieur & Ballon Cœur 3D double-lobe `#D91E48` sur tige dorée.
  - **Vivienne Giant Denim** (`models/vivienne_giant_denim.blend`) : Denim Bleu Indigo Jacquard `#3B6291`, Sneakers 3D fuchsia/blanc/argent aux pieds, Étiquette Porte-Adresse 3D flottante & Skateboard LV 3D à 4 roues cylindriques crème.
- **Sauts Bonus 3D `Saut 360°` (`+250 pts`) & `Saut Périlleux` (`+300 pts`)** :
  - Vrilles `360°` en vraie 3D autour de l'axe vertical (bras levés en V 3D + jambes/skis en ciseaux 3D) et saltos arrière `Périlleux` complets en vrai tangage 3D (`pitch` `0° -> -360°` + perspective latérale 3D).
- **Télésièges Obliques Infinis, Parallaxe Continue & Banderoles `LV_NEO`** :
  - Lignes de télésièges/télécabines obliques traversant tout le domaine d'un bord à l'autre de l'écran (`-220 m .. +220 m`, 6 pylônes treillis 3D et 10 cabines/sièges animés), parallaxe continue sans saccade sur les sommets alpins, banderoles latérales 3D `LV_NEO`, chute cartoon en boule de neige sur sapin et menu Pause en course.
- **Contrôle Accéléromètre Natif 60 Hz** (`MainActivity.kt` Android / `AppDelegate.swift` iOS) + calibrage instantané et contrôles tactiles/clavier.

## Commandes de Validation

```bash
/tmp/flutter-sdk/flutter/bin/flutter analyze
/tmp/flutter-sdk/flutter/bin/flutter test
/tmp/flutter-sdk/flutter/bin/flutter build apk --release
```
