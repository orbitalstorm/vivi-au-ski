# Changelog — Vivi au Ski 3D (`cloud.orbital8.vivi_au_ski`)

## [1.0.0+1] - 2026-11-12

### Added
- Initialisation Store-Ready **Android & iOS** (`cloud.orbital8.vivi_au_ski`, Portrait, `EventChannel` + `MethodChannel` accéléromètre matériel 60 Hz dans `MainActivity.kt` et `AppDelegate.swift`).
- Modèles immuables stricts (`lib/models/ski_models.dart`) : 3 pistes complètes (`SkiTrackId`), 4 éditions Haute Couture (`VivienneSkiEdition`), 8 états d'animation 3D (`VivienneSkiAnimState`), 5 figures aériennes (`SkiAerialTrickKind`) et entités 3D du monde.
- Moteur physique de ski 3D (`lib/engine/ski_game_engine.dart`) : carving accéléromètre filtré, absorption des bosses en *Squash*, impulsion tremplin en *Stretch*, sauts aériens *Big Air* bras levés en V, portes de slalom, collecte Blossom et Tableau des Scores pré-peuplé et persistant en session.
- Rendu 3D perspective vue de derrière (`lib/painters/ski_3d_painter.dart`) avec tri Z complet, traces de ski persistantes, sapins enneigés, bosses, tremplins, chalets et rig hybride Blender Cycles (`vivienne_speedy_v03.blend` / `vivienne_turntable_00..23.png`).
- Contrats vectoriels Cartoon (`lib/painters/vivi_ski_cartoon_assets.dart` + 8 SVG initiaux dans `assets/cartoon/`), Menu d'Accueil Cartoon, HUD 60–120 FPS isolé par `RepaintBoundary`, Galerie 360° et suite de tests automatisés (`test/widget_test.dart`).
