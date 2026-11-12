# VIVI AU SKI : Descente Royale 3D (`v1.0.0+1`)

Application mobile **Android & iOS** développée en **Flutter / Dart (Sound Null Safety strict, moteur Impeller 60–120 FPS)** mettant en scène la figurine officielle **Vivienne** ([`orbitalstorm/BLENDER_LAB`](https://github.com/orbitalstorm/BLENDER_LAB/blob/main/models/vivienne_speedy_v03.blend)) dans une simulation de ski alpin en **3D Cartoon vue de derrière**.

## Points Clés (`v1.0.0`)

- **Identifiant Store** : `cloud.orbital8.vivi_au_ski` (`version: 1.0.0+1`, Portrait Android & iOS).
- **Contrôle Accéléromètre Natif 60 Hz** :
  - **Android** (`MainActivity.kt`) : `SensorManager` + `Sensor.TYPE_ACCELEROMETER` (`SENSOR_DELAY_GAME`) sur `EventChannel("cloud.orbital8.vivi_au_ski/accelerometer")` et `MethodChannel("cloud.orbital8.vivi_au_ski/device")`.
  - **iOS** (`AppDelegate.swift` + `Info.plist`) : `CMMotionManager` (`60 Hz`, `NSMotionUsageDescription`) normalisé sur la même convention physique.
  - Filtrage passe-bas exponentiel, zone morte (`deadzone`), bouton **CALIBRER** en temps réel et contrôles tactiles/clavier en fallback.
- **Moteur 3D Perspective Vue de Derrière (`Ski3DPainter`)** :
  - Projection perspective `Camera3D` (`zNear = 6.2 m` -> `zFar = 220 m`), roulis dynamique de carving, manteau neigeux trapézoïdal damé, poudreuse de bord de piste et **doubles traces de ski persistantes**.
  - Tri en profondeur strict (*Painter's Algorithm*) : sapins enneigés à 3–4 étages, bosses 3D (*moguls*), tremplins de saut LV à chevrons dorés, portes de slalom, fleurs Blossom 3D, arches de départ/arrivée et chalets alpins.
- **Vivienne 3D Vue de Dos & Rig Articulé (`vivienne_speedy_v03.blend`)** :
  - Combinaison des rendus Cycles détourés vue de dos (`180°` `vivienne_turntable_12.png` et angles de carving `135°..225°` `09..15.png`) et du rig 3D articulé (skis paraboliques Monogram & Or 24K, bâtons de ski dorés, bandeau de masque alpin, écharpe flottant au vent, bras articulés se levant en **V triomphal** pendant les sauts aériens, et mini sac Speedy LV oscillant).
- **3 Pistes de Ski Complètement Skiables** :
  1. **Vallée Blossom Ensoleillée** (*Piste Verte* • `1 200 m` • `14°` • 8 bosses • 4 tremplins • 10 portes de slalom)
  2. **Forêt des Sapins d'Asnières** (*Piste Bleue* • `1 800 m` • `22°` • 16 bosses • 7 tremplins • 14 portes de slalom)
  3. **Cimes Étoilées Vendôme** (*Piste Noire Or* • `2 500 m` • `32°` • Aurore boréale • 24 bosses • 10 méga-tremplins *Big Air* • 18 portes de slalom)
- **Menu d'Accueil Cartoon, Galerie 3D Turntable 360° & Tableau des Scores par Piste**.

## Commandes de Validation

```bash
/tmp/flutter-sdk/flutter/bin/flutter analyze
/tmp/flutter-sdk/flutter/bin/flutter test
/tmp/flutter-sdk/flutter/bin/flutter build apk --release
```
