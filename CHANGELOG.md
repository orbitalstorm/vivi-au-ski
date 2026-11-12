# Changelog — Vivi au Ski 3D (`cloud.orbital8.vivi_au_ski`)

## [v1.2.0] (`1.2.0+3`) - 2026-11-12

### Added, Changed & Fixed
- **3 Figurines Officielles Vivienne 3D Cycles de Dos & de Face (`ORB-68` / `ORB-67` — @Carbon)** :
  - Conservation stricte des **3 modèles officiels `BLENDER_LAB`** dans `VivienneSkiEdition` : `Vivienne Speedy v03` (`speedyV03`), `Vivienne Wonderland` (`wonderland`) et `Vivienne Giant Denim` (`giantDenim`) ; retrait de la variante `neoBlossom` (tout en conservant les banderoles de piste `LV_NEO`).
  - Suppression intégrale du rendu vectoriel plat de personnage (`_paintRearSkiGogglesAndScarf`, `_paintProceduralRearVivienneRig`, `_paintArticulatedSkiPolesAndVArms`, `_paintEditionSignatureAccessories3D`, `_paintSwingingSpeedyBagOverlay`), éliminant définitivement le bug du rectangle jaune au dos de la tête, les bras/écharpe 2D et tout doublon d'accessoire.
  - Intégration des 30 sprites 3D Cycles pré-rendus (`rear_pose_1..5.png` à `180°` et `front_pose_1..5.png` à `0°`) avec alignement exact de la semelle des pieds (`soleCenterXFraction`), sac Speedy attaché à la main gauche de `Speedy v03`, tige dorée du ballon cœur passant devant le pétale de `Wonderland`, et sneakers/skateboard 3D natifs sur `Giant Denim`.
- **Sauts Bonus `Saut 360°` (`+250 pts`) & `Saut Périlleux` (`+300 pts`)** :
  - Impulsion Big Air renforcée sur les tremplins et les bosses à haute vitesse avec alternance entre `SkiAerialTrickKind.saut360` (rotation hélicoptère `0 -> 2π` autour de l'axe Y basculant dynamiquement entre poses Cycles de dos et de face + halo doré 3D) et `SkiAerialTrickKind.sautPerilleux` (salto complet `0 -> 2π` tête-bêche avec skis solidaires + ruban d'étoiles dorées).
  - Affichage temps réel du bonus dans le HUD (`"SAUT 360° +250"`, `"SAUT PÉRILLEUX +300"`) et en callouts flottants.
- **Télésièges & Télécabines Obliques Infinis (`_paintCableCarSystem3D`)** :
  - Remplacement du court segment local par une ligne de remontée mécanique diagonale infinie (`skewSlope = ±0.52`, traversée `-220 m .. +220 m` d'un bord à l'autre de l'écran avec clipping 3D propre au plan proche `camZ + 5.2`), 6 pylônes treillis métalliques 3D hors-piste et 10 cabines/sièges animés (5 montants, 5 descendants).
- **Correction de la Parallaxe des Montagnes & Modale de Pause (`pause_modal_overlay`)** :
  - Suppression totale du modulo `% step` dans `_paintMountainRange` au profit d'un indexage entier continu des sommets et d'amplitudes de parallaxe réalistes (`-camWorldX * 0.14` / `0.26` / `0.06`), éliminant tout saut visuel en virage.
  - Ajout du bouton Pause dans le HUD (`hud_pause_button`) et de la modale Cartoon **Course en Pause** (`pause_modal_overlay`).

## [v1.1.0] (`1.1.0+2`) - 2026-11-12

### Added & Changed
- **Dénivelés Accrus, Pentes Plongeantes & Sensation de Haute Vitesse (`ORB-66` — @Carbon)** :
  - **Piste Verte (`greenBlossomValley`)** : pente `24.0°`, dénivelé `-535 m`, vitesse `62–108 km/h` (`1 200 m • Dénivelé -535 m (24°) • 4 Tremplins`).
  - **Piste Bleue (`blueAsnieresForest`)** : pente `34.0°`, dénivelé `-980 m`, vitesse `84–142 km/h` (`1 800 m • Dénivelé -980 m (34°) • 7 Tremplins`).
  - **Piste Noire Or (`blackVendomePeaks`)** : pente `45.0°`, dénivelé `-1 650 m`, vitesse `108–185 km/h` (`2 500 m • Dénivelé -1 650 m (45°) • 10 Méga-Sauts`).
  - Intégration de `slopeDegrees` et de ruptures de pente (*crests*) dans `Ski3DPainter.project(...)`, bandes de neige damée resserrées à `5.0 m`, et filets de vent alpin / lignes de vitesse radiales à haute vélocité.
- **Chute Cartoon en Boule de Neige sur Sapin (`VivienneSkiAnimState.snowballCrash`)** :
  - Lors d'une collision avec un sapin (`alpinePineTree` ou `giantSnowPine`, sur piste ou en bordure), déclenchement de `CHUTE BOULE DE NEIGE !` (`1.15 s`, `3` tours complets `6π`, callout `'BOUM ! BOULE DE NEIGE !'`, gerbe de 26 flocons et aiguilles de sapin).
  - Rendu 3D d'une boule de neige bosselée croissante (`1.1x -> 1.55x`) d'où dépassent les skis paraboliques LV, les pieds/sneakers, les pétales de la corolle et les accessoires de Vivienne tournant à `360°`.
- **Banderoles Latérales 3D Officielle `LV_NEO` (`assets/sprites/lv_neo_banner.png`)** :
  - Bordure bilatérale continue (`SkiPropKind.lvBannerPost` à `±(halfW + 0.9 m)`, toutes les `~26 m`) avec maillage trapézoïdal 3D tendu entre mâts cobalt `#1638E8` & or `#FFD700` surmontés de sphères dorées (`ui.Vertices` + `ui.ImageShader` avec fallback vectoriel haute précision).
- **Décors Alpins Vivants & Animés (`SkiPropKind`)** :
  - Télécabines alpines animées (`cableCarPylon`) traversant la piste sur câble aérien, bonhommes de neige cartoon saluant les skieurs (`cartoonSnowman`), mâts à fanions flottants & supporters (`flutteringPennantPost`), canons à neige actifs projetant un jet continu de cristaux (`snowCannon`), chalets alpins éclairés à mi-piste avec fumée de cheminée, et montgolfières LV Blossom en parallaxe.
- **4 Modèles Officiels `orbitalstorm/BLENDER_LAB` Jouables (`VivienneSkiEdition`)** :
  - `Vivienne Speedy v03` (`models/vivienne_speedy_v03.blend`), `Vivienne Wonderland` (`models/vivienne_wonderland.blend` — Toile Monogram Ébène, Petit Lapin Blanc sur le pétale supérieur & Ballon Cœur Rouge sur tige dorée), `Vivienne Giant Denim` (`models/vivienne_giant_denim.blend` — Denim Indigo Jacquard, Sneakers Fuchsia/Blanc, Étiquette `LOUIS VUITTON` & Grand Skateboard LV à 4 roues blanches), et `Vivienne LV_NEO Blossom` (`models/vivienne_lv_neo_blossom.blend`).

## [v1.0.0] (`1.0.0+1`) - 2026-11-12

### Added
- **Architecture & Packaging Store-Ready Android/iOS (`ORB-63` — @Carbon)** :
  - `cloud.orbital8.vivi_au_ski` (`1.0.0+1`), orientation Portrait verrouillée, `EventChannel("cloud.orbital8.vivi_au_ski/accelerometer")` et `MethodChannel("cloud.orbital8.vivi_au_ski/device")` 60 Hz natifs dans `MainActivity.kt` (Android) et `AppDelegate.swift` (iOS `CMMotionManager` + `NSMotionUsageDescription`).
  - Intégration du modèle 3D officiel [`models/vivienne_speedy_v03.blend`](https://github.com/orbitalstorm/BLENDER_LAB/blob/main/models/vivienne_speedy_v03.blend), des 24 rendus Cycles turntable (`assets/turntable/vivienne_turntable_00..23.png`, dont `180° Dos` pour la glisse vue de derrière et `135°..225°` pour le carving) et des 6 poses clés (`assets/sprites/vivienne_pose_1..6.png`).
- **Moteur Physique Ski 3D Cartoon & Rendu Perspective Vue de Derrière (`ORB-63` — @Carbon)** :
  - **3 Pistes de Ski Complètes (`SkiTrackId`)**, **4 Éditions Jouables (`VivienneSkiEdition`)**, projection 3D perspective vue de derrière (`lib/painters/ski_3d_painter.dart`), tri Z intégral (*Painter's Algorithm*), doubles traces de ski persistantes, bosses (*moguls*) et tremplins de saut *Big Air*.
- **Illustration Vectorielle Haute Précision SVG & CustomPainter (`ORB-64` — @Leonardo)** :
  - 8 emblèmes vectoriels Cartoon en `<svg>` (`assets/cartoon/ski_*.svg`, `viewBox="0 0 512 512"`) et rendu vectoriel multi-calques dans `lib/painters/vivi_ski_cartoon_assets.dart` (`SkiCartoonEmblemBadge`).
- **Interface Mobile Cartoon, Game Juice 60-120fps & Tableau des Scores (`ORB-65` — @Miyamoto)** :
  - Menu d'Accueil Cartoon (`main_menu_overlay`), boutons 3D tactiles `JuicySki3DButton`, HUD de glisse isolé par `RepaintBoundary`, Modale Tableau des Scores par piste (`highscores_modal_overlay`) et Galerie 3D (`vivienne_gallery_panel`).
