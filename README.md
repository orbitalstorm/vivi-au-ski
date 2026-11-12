# VIVI AU SKI : Descente Royale 3D (`v1.5.1+7`)

Application mobile **Android & iOS** développée en **Flutter / Dart (Sound Null Safety strict, moteur Impeller 60–120 FPS)** mettant en scène les **3 figurines 3D officielles Vivienne** du studio [`orbitalstorm/BLENDER_LAB`](https://github.com/orbitalstorm/BLENDER_LAB) rendues par un **vrai moteur 3D volumétrique temps réel & rig squelettique articulé 22+ os (`lib/painters/vivienne_3d_volumetric_rig.dart`)**.

## Nouveautés Majeures (`v1.5.1+7`)

- **Identifiant Store** : `cloud.orbital8.vivi_au_ski` (`version: 1.5.1+7`, Portrait Android & iOS).
- **Suppression Totale des Microbosses en « Dos d'Âne » & Bosses 3D Larges Intégrées à la Piste (`v1.5.1`)** :
  - Suppression intégrale de l'overlay strié `_paintMogul3D` (`_DepthActorKind.mogul`) et des micro-ondulations courtes qui ressemblaient à des ralentisseurs routiers.
  - Conservation exclusive de **`8` / `12` / `16` larges bosses alpines progressives** (`radiusX = 7.5..10.3 m`, `radiusZ = 14.6..19.6 m`, profil `C²` en `cos⁴`) directement sculptées dans le maillage 3D à `16` colonnes transversales avec ombrage continu de la neige de piste (`<= 0.16`), ainsi que des **3 tailles de tremplins bien intégrés** (`small`, `medium`, `large`) à talus latéraux de neige et jupe d'entrée fondue.
- **Vivienne Toujours Au-Dessus des Rampes d'Accélération / Saut (`Ski3DPainter` & `SkiGameEngine`)** :
  - Invariant de tri de profondeur garantissant qu'aucune rampe (`jumpRamp`) n'est jamais dessinée par-dessus Vivienne, appui physique continu sur toute l'étendue du tablier incliné (`rampDeckElevationAt`, `playerGroundY`) et projection de l'ombre et des traces de skis directement sur la rampe.
- **Protections Matelassées Orange Devant les Sapins de Piste & Collision 3D Intégrale** :
  - Matelas de sécurité cylindriques orange matelassés (`#FF6D00` / `#FFAB40` / sangles jaune & noir) devant chaque sapin planté sur la piste (`isOnPiste: true`), et détection de collision 3D intégrale déclenchant la chute boule de neige (`snowballCrash`) au contact du **matelas orange**, des **branches basses/intermédiaires** ou de la **cime du sapin en plein saut** (`PineCollisionZone`).
- **Village Alpin d'Arrivée Étoffé (`16` Bâtiments & `3` Architectures)** :
  - Hameau alpin complet encadrant les `85` derniers mètres de piste et formant une place en amphithéâtre derrière l'arche d'`ARRIVÉE` : **Chalet traditionnel en bois sculpté** avec balcon et cheminée fumante, **Hôtel-refuge alpin à 2 étages** coiffé d'un clocheton d'horloge enneigé, et **Chalet boutique après-ski** à store rayé `LV_NEO`, vitrine cintrée illuminée et guirlandes dorées.
- **Télésièges Strictement Bornés entre `2` et `5` Max par Piste (`cableCarCount`)** :
  - `3` télésièges sur la Piste Verte, `4` sur la Piste Bleue et `5` sur la Piste Noire Or, régulièrement espacés pour dégager la vue panoramique sur le massif alpin.
- **2 Modes de Jeu Complets (`DESCENTE & BOSSES` & `SLALOM COMPLET`) & Posture Parallèle Authentique** :
  - Sélecteur de mode dès l'accueil (`SkiGameMode`), parcours Slalom Complet (`28`, `38` et `50` portes alternant strictement **Gauche Rouge/Or** et **Droite Bleu/Azur**), spectateurs Vivienne 3D animés et contrôle accéléromètre natif 60 Hz (`MainActivity.kt` / `AppDelegate.swift`).
- **3 Pistes Alpines Complètes (`SkiTrackId`)** :
  1. **Vallée Blossom Ensoleillée** (*Piste Verte* • `1 200 m` • `-535 m` (`24°`) • `8` larges bosses intégrées • `6` tremplins • `28` portes Slalom)
  2. **Forêt des Sapins d'Asnières** (*Piste Bleue* • `1 800 m` • `-980 m` (`34°`) • `12` larges bosses intégrées • `9` tremplins • `38` portes Slalom)
  3. **Cimes Étoilées Vendôme** (*Piste Noire Or* • `2 500 m` • `-1 650 m` (`45°`) • `16` larges bosses intégrées • `12` tremplins *Big Air* • `50` portes Slalom)
- **Contrôle Accéléromètre Natif 60 Hz** (`MainActivity.kt` Android / `AppDelegate.swift` iOS) + calibrage instantané et contrôles tactiles/clavier.

## Commandes de Validation

```bash
/tmp/flutter-sdk/flutter/bin/flutter analyze
/tmp/flutter-sdk/flutter/bin/flutter test
/tmp/flutter-sdk/flutter/bin/flutter build apk --release
```
