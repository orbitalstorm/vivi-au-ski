# Changelog — Vivi au Ski 3D (`cloud.orbital8.vivi_au_ski`)

## [v1.5.0] (`1.5.0+6`) - 2026-11-12

### Added, Changed & Fixed
- **Z-Order & Physique des Rampes d'Accélération / Tremplins : Vivienne Toujours Au-Dessus (`ORB-74` / `ORB-73` — @Carbon)** :
  - Extraction et sécurisation de la file de tri Z dans `Ski3DPainter._buildSortedRenderItems` (`lib/painters/ski_3d_painter.dart`) avec vérification publique `debugIsVivienneRenderedAboveAllRamps()`, garantissant qu'**aucune rampe (`_DepthActorKind.jumpRamp`) ni bosse (`_DepthActorKind.mogul`) n'est jamais dessinée après (`par-dessus`) `_DepthActorKind.viviennePlayer`**, que Vivienne aborde la rampe, grimpe le tablier, franchisse la lèvre d'envol ou survole un tremplin.
  - Ajout de `rampDeckElevationAt`, `groundSurfaceHeightAt` et `playerGroundY` dans `SkiGameEngine` (`lib/engine/ski_game_engine.dart`) avec tolérance latérale étendue (`width * 0.68`) : maintien strict `playerY >= deckY` sur tout `[zStart, zEnd]` et projection de l'ombre (`groundPt`) ainsi que des traces de skis sur l'altitude réelle du tablier incliné.
- **Matelas de Sécurité Orange Devant les Sapins de Piste & Collision 3D Intégrale (`lib/painters/ski_3d_painter.dart`, `lib/engine/ski_game_engine.dart`)** :
  - Rendu 3D Cartoon d'un matelas de protection cylindrique orange matelassé (`_paintPineSafetyMattress3D` : dégradé `#E65100 -> #FFAB40 -> #FF6D00 -> #DD2C00`, boudins verticaux surpiqués, doubles sangles jaune sécurité `#FFD600` / noir `#2B1105` et bourrelet de neige au pied) placé devant chaque sapin situé sur la piste (`isOnPiste: true`).
  - Suppression du plafond `playerY < 1.55` et implémentation de `checkPineTreeCollision` (`PineCollisionZone`) déclenchant immédiatement `_triggerSnowballCrash()` lors d'un impact contre **(A)** le matelas orange avant (`orangePad`), **(B)** le volume conique des branches (`branch`, `0 .. 0.82 * treeHeight`) ou **(C)** le haut / la cime du sapin en plein saut (`treetop`, `0.82 * treeHeight .. treeHeight + 0.35`).
- **Village Alpin d'Arrivée Étoffé (`16` Bâtiments & `3` Variantes Architecturales)** :
  - Génération de `16` bâtiments `SkiPropKind.alpineChalet` encadrant l'approche finale (`length - 82 m .. length - 11 m`) et formant un hameau en amphithéâtre derrière l'arche d'`ARRIVÉE` (`length + 13 m .. length + 68 m`), avec seuil de visibilité longue distance abaissé (`s >= 0.36`) et évitement automatique des sapins de bordure.
  - Implémentation de 3 architectures alpines distinctes dans `_paintAlpineChalet3D` : **Chalet traditionnel en bois sculpté** à balcon et cheminée fumante (`variant 0`), **Hôtel-refuge alpin à 2 étages** à crépi crème et clocheton d'horloge enneigé (`variant 1`), et **Chalet boutique après-ski** à store banne rayé `LV_NEO`, vitrine cintrée illuminée et guirlandes lumineuses (`variant 2`).
- **Limitation Stricte des Télésièges Traversant la Piste (`2` à `5` Max)** :
  - Ajout de `SkiTrackId.cableCarCount` limitant le nombre de systèmes de télésièges (`SkiPropKind.cableCarPylon`) à exactement **`3`** sur la Piste Verte, **`4`** sur la Piste Bleue et **`5`** sur la Piste Noire Or (espacés régulièrement entre `155 m` et `length - 145 m`).
- **Intégration Visuelle Organique des Petites Bosses & Tremplins dans la Piste** :
  - Augmentation de la résolution du maillage de piste à `_kPisteCols = 16` colonnes transversales (`_kSliceCount = 88`).
  - Suppression de l'ombre ovale sombre flottante et du contour bleu dur `#3979A8` dans `_paintMogul3D` au profit d'un dôme de neige fondu à `alpha: 0.0` sur son pourtour et de nervures de damage 3D courbées.
  - Ajout de talus latéraux de neige (`snow buttresses`) sur toutes les tailles de tremplins (`small`, `medium`, `large`), d'une jupe de transition neigeuse à l'entrée et suppression du trait noir transversal au pied des rampes dans `_paintJumpRamp3D`.

## [v1.4.0] (`1.4.0+5`) - 2026-11-12

### Added, Changed & Fixed
- **Suppression Totale du Cycle de Marche en Descente & sur les Modes Hors-Glisse (`ORB-72` / `ORB-71` — @Carbon)** :
  - Élimination intégrale de l'alternance longitudinale avant/arrière des jambes (`rhythmLeg = 0.0`) et du balancement de marche des bras (`poleSwing = 0.0`, `stride = 0.0`) dans `VivienneSkeletonPose3D.evaluate` (`lib/painters/vivienne_3d_volumetric_rig.dart`) en glisse (`glidingRearNeutral`, `carvingLeft`, `carvingRight`), en saut, dans le Menu (`showcase360`), en Pause (`pauseInspection`), sur le Podium (`podiumCelebration`) et chez les spectateurs (`spectatorCheer`).
  - Remplacement par une vraie posture de ski alpin **parallèle** : suspension synchrone des deux genoux/chevilles sur le terrain, angulation de carre asymétrique intérieure/extérieure en virage sans cisaillement longitudinal, et bras aérodynamiques profilés tenant les bâtons vers l'arrière.
- **Relief Alpin Prononcé Multi-Sections : Replats / Crêtes Occultant l'Arrière-Plan & Murs Plongeants (`lib/engine/ski_game_engine.dart`, `lib/painters/ski_3d_painter.dart`)** :
  - Profil altimétrique asymétrique multi-sections (`relativeReliefAtZ`, `localReliefGradientAt`, `localSlopeGradientAt`) alternant des **replats et dômes convexes** qui remontent visuellement **au-dessus de `horizonY`** (masquant le bas des montagnes alpines, le ciel et les acteurs 3D situés derrière la cassure de pente) et des **murs de descente plongeants** révélant toute la vallée en contrebas avec accélération physique réelle.
  - Tri Z unifié entre les tranches 3D du maillage de neige (`_DepthActorKind.terrainSlice`) et l'ensemble des acteurs 3D avec élimination des faces arrière derrière les crêtes (*back-face crest culling*).
- **Bosses 3D Intégrées dans le Maillage de Piste (`22 / 34 / 48`) & 3 Tailles de Tremplins (`SkiRampSizeTier`)** :
  - Subdivision transversale du maillage 3D de la piste en `10` colonnes déformées continûment (`C¹`) par `mogulElevationAt(worldX, worldZ)` / `snowSurfaceHeightAt(worldX, worldZ)` avec rainures de neige damée courbées en 3D et ombrage par facette.
  - Ajout de `SkiRampSizeTier` (`small` Mini Tremplin `4.5×6.8×1.05 m`, `medium` Tremplin Blossom `5.8×10.2×1.80 m`, `large` Méga Tremplin Big Air `7.4×14.6×2.80 m` à contreforts de neige 3D et fanions sommitaux) générés sur chaque piste (`6`, `9`, `12` tremplins).
- **Mode `SLALOM COMPLET` (`SkiGameMode.slalomComplet`) & Alternance Stricte Gauche / Droite** :
  - Sélecteur de mode dans le Menu d'accueil (`select_mode_descente` / `select_mode_slalom`) et parcours Slalom dédié (`28`, `38`, `50` portes alternant strictement **Gauche Rouge/Or** `G1, G3...` à `-0.45..0.49 * halfW` et **Droite Bleu/Azur** `D2, D4...` à `+0.45..0.49 * halfW`).
  - Ligne de trajectoire idéale 3D en S et chevrons directionnels peints sur le relief de la neige, piquets articulés sur rotules flexibles (`poleFlex`) s'inclinant au passage, et compteur HUD temps réel (`hud_slalom_counter_badge` : `PORTES X / TOTAL • COMBO ×Y` + indicateur prochaine porte Gauche/Droite).
- **Spectateurs 3D Vivienne Animés sur les Bords de Piste (`SkiPropKind.vivienneSpectator`)** :
  - Foule festive sur les deux bordures de piste composée des **3 modèles 3D officiels `BLENDER_LAB`** (`speedyV03`, `wonderland`, `giantDenim`, sans skis ni bâtons, orientés de 3/4 face vers la piste) avec 3 styles d'encouragement sans aucun cycle de marche (`waveArms`, `jumpAndWave`, `doubleJumpCheer`), cache de poses FK et LOD par distance garantissant `60–120 FPS`.

## [v1.3.0] (`1.3.0+4`) - 2026-11-12

### Added, Changed & Fixed
- **Moteur de Rendu 3D Volumétrique Complet & Rig Squelettique Articulé 22+ Os (`ORB-70` / `ORB-69` — @Carbon)** :
  - Création de `lib/painters/vivienne_3d_volumetric_rig.dart` (`Vivienne3DVolumetricRig`, `VivienneSkeletonPose3D`, `Vivienne3DViewport`, `VivienneProjectedBounds`) remplaçant **intégralement** tous les sprites 2D plats du personnage sur la piste, en saut, dans le Menu d'accueil, la Galerie 3D, la Pause et le Podium d'arrivée.
  - **Maillages 3D fermés triangulés (`ui.Vertices.raw(ui.VertexMode.triangles, ...)`)** fidèles aux générateurs Python `BLENDER_LAB` :
    * `Vivienne_Head` : ellipsoïde 3D en bois veiné (`rx = 0.45, ry = 0.28, rz = 0.45`, profondeur réelle `0.56 m` en Y), œil droit fleur Monogram 3D en relief + clou or, œil gauche clou cylindrique biseauté or `#FFD700`, oreilles Vachetta à tranche carmin, et occultation 3D naturelle vue de dos.
    * **4 Pétales 3D volumétriques** (`Petal_Top/Bottom/Left/Right`, `thickness = 0.072`) à faces bombées, **tranche périmétrique biseautée 3D rouge carmin `#8B1E24`** (ou indigo `#1D3557` sur `Giant Denim`), coutures sellier 3D et motifs Monogram étoilés en relief 3D recto/verso.
    * **Torse & Bassin 3D** (`Pelvis` + `Spine`) et **Jambes, Genoux, Pieds / Sneakers & Skis Paraboliques 3D indépendants** (`Leg_L/R -> Shin_L/R -> Foot_L/R -> Ski_L/R`), incluant les Sneakers 3D complètes (`Giant Denim` : semelle fuchsia `#C9184A`, midsole blanche, empiècements argent et 3 brides framboise).
    * **Bras, Avant-Bras, Mains & Bâtons de Ski 3D indépendants** (`Shoulder_L/R -> Arm_Upper_L/R -> Arm_Lower_L/R -> Hand_Clasp_L/R -> Ski_Pole_L/R`) à tranches carmin `#8B1E24`, mousquetons or 24K et rondelles étoilées 3D.
    * **Accessoires 3D volumétriques animés** : Mini Sac Speedy LV 3D (`Speedy_Bag_Bone`), Petit Lapin Blanc 3D + longues oreilles élastiques (`Bunny_Body_Bone` & `Bunny_Ears_Bone`) & Ballon Cœur 3D double-lobe sur tige or (`Wonderland`), Mini Skateboard LV 3D à 2 trucks chromés & **4 roues cylindriques 3D** + Étiquette porte-adresse 3D (`Giant Denim`).
  - **Éclairage PBR Studio 3 Points + Spéculaire Blinn-Phong + Silhouette Cartoon 3D (*Inverted Hull* `#2B1105`)** avec tri Z par triangle (*Painter's Algorithm*) et élimination des faces cachées.
- **Vraies Rotations 3D (`yaw`, `pitch`, `roll`) & Animations Continues des Membres (`60–120 FPS`)** :
  - Suppression totale de `horizSpinScale` (`cos(yaw)`) et de la rotation 2D d'écran (`canvas.rotate(-flipAngle)`).
  - En **Descente & Carving** : lacet 3D de virage (`yaw = 180° ± 36°`), roulis 3D, flexion asymétrique intérieur/extérieur des genoux, planté de bâtons 3D alterné, ondulation des 4 pétales et pendule 3D des accessoires.
  - En **`SAUT 360°`** : vraie rotation 3D autour de l'axe vertical révélant tout le profil et la face 3D sans aucun écrasement horizontal, bras levés haut en V 3D et battement de jambes/skis en ciseaux 3D.
  - En **`SAUT PÉRILLEUX`** : vrai salto arrière 3D (`pitch` `0° -> -360°` autour de l'axe X + perspective latérale `28°`) projetant en vraie 3D les semelles/sneakers, skis, skateboard et corolle.
  - Intégration de `Vivienne3DViewport` 60 FPS dans le Menu (`main_menu_overlay`), la Galerie 3D interactive (`vivienne_gallery_panel`), l'inspection 3/4-profil (`~58°`) en Pause (`pause_modal_overlay`) et la célébration bras en V sur le Podium (`track_finished_overlay`).

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
