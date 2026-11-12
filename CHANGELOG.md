# Changelog — Vivi au Ski 3D (`cloud.orbital8.vivi_au_ski`)

## [v1.0.0] (`1.0.0+1`) - 2026-11-12

### Added
- **Architecture & Packaging Store-Ready Android/iOS (`ORB-63` — @Carbon)** :
  - `cloud.orbital8.vivi_au_ski` (`1.0.0+1`), orientation Portrait verrouillée, `EventChannel("cloud.orbital8.vivi_au_ski/accelerometer")` et `MethodChannel("cloud.orbital8.vivi_au_ski/device")` 60 Hz natifs dans `MainActivity.kt` (Android) et `AppDelegate.swift` (iOS `CMMotionManager` + `NSMotionUsageDescription`).
  - Intégration du modèle 3D officiel [`models/vivienne_speedy_v03.blend`](https://github.com/orbitalstorm/BLENDER_LAB/blob/main/models/vivienne_speedy_v03.blend), des 24 rendus Cycles turntable (`assets/turntable/vivienne_turntable_00..23.png`, dont `180° Dos` pour la glisse vue de derrière et `135°..225°` pour le carving) et des 6 poses clés (`assets/sprites/vivienne_pose_1..6.png`).
- **Moteur Physique Ski 3D Cartoon & Rendu Perspective Vue de Derrière (`ORB-63` — @Carbon)** :
  - **3 Pistes de Ski Complètes (`SkiTrackId`)** : *Piste Verte — Vallée Blossom Ensoleillée* (`1 200 m • 14°`), *Piste Bleue — Forêt des Sapins d'Asnières* (`1 800 m • 22°`), *Piste Noire Or — Cimes Étoilées Vendôme* (`2 500 m • 32°`).
  - **4 Éditions Jouables (`VivienneSkiEdition`)** : *Vivienne Speedy v03*, *Vivienne Neo Blossom*, *Vivienne Malle Impériale*, *Vivienne Nuit d'Asnières*.
  - Projection 3D perspective vue de derrière (`lib/painters/ski_3d_painter.dart`), tri Z intégral (*Painter's Algorithm*), doubles traces de ski persistantes, sapins enneigés 3D à 3–4 étages, bosses (*moguls*) avec compression *Squash & Stretch* à volume constant, tremplins de saut *Big Air* avec célébration bras levés en V, portes de slalom et flocons 3D.
- **Illustration Vectorielle Haute Précision SVG & CustomPainter (`ORB-64` — @Leonardo)** :
  - 8 emblèmes vectoriels Cartoon en `<svg>` (`assets/cartoon/ski_*.svg`, `viewBox="0 0 512 512"`) et rendu vectoriel multi-calques dans `lib/painters/vivi_ski_cartoon_assets.dart` (`SkiCartoonEmblemBadge`).
- **Interface Mobile Cartoon, Game Juice 60-120fps & Tableau des Scores (`ORB-65` — @Miyamoto)** :
  - Menu d'Accueil Cartoon (`main_menu_overlay`), sélection des 3 pistes et des 4 éditions Vivienne, boutons 3D tactiles `JuicySki3DButton` (`Curves.elasticOut` + retours haptiques), HUD de glisse isolé par `RepaintBoundary`, jauge accéléromètre + bouton `CALIBRER`, Modale Tableau des Scores par piste (`highscores_modal_overlay`), Galerie 3D Turntable 360° (`vivienne_gallery_panel`) et captures Store Portrait `1080×2400` (`screenshots/01..04_*.png`).
