import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivi_au_ski/engine/ski_game_engine.dart';
import 'package:vivi_au_ski/main.dart';
import 'package:vivi_au_ski/models/ski_models.dart';

Future<void> _loadRealFlutterFonts() async {
  final String flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter-sdk/flutter';
  final String fontDir = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final Directory dir = Directory(fontDir);
  if (!dir.existsSync()) return;

  final FontLoader robotoLoader = FontLoader('Roboto');
  for (final String file in <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    final File f = File('$fontDir/$file');
    if (f.existsSync()) {
      final Uint8List bytes = f.readAsBytesSync();
      robotoLoader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
  }
  await robotoLoader.load();

  final File materialIconsFile = File('$fontDir/MaterialIcons-Regular.otf');
  if (materialIconsFile.existsSync()) {
    final FontLoader iconsLoader = FontLoader('MaterialIcons');
    final Uint8List bytes = materialIconsFile.readAsBytesSync();
    iconsLoader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await iconsLoader.load();
  }
}

Future<ui.Image?> _decodeImageFile(String path) async {
  final File f = File(path);
  if (!await f.exists()) return null;
  final Uint8List bytes = await f.readAsBytes();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

Future<List<ui.Image?>> _loadTestTurntableSprites() async {
  final List<ui.Image?> list = List<ui.Image?>.filled(
    VivienneTurntableSpec.frameCount,
    null,
  );
  for (int i = 0; i < VivienneTurntableSpec.frameCount; i++) {
    list[i] = await _decodeImageFile(
      VivienneTurntableSpec.assetPathForIndex(i),
    );
  }
  return list;
}

Future<ui.Image?> _loadTestLvNeoBannerImage() async {
  return _decodeImageFile('assets/sprites/lv_neo_banner.png');
}

Future<Map<VivienneSkiEdition, ui.Image>> _loadTestEditionHeroSprites() async {
  final Map<VivienneSkiEdition, ui.Image> map =
      <VivienneSkiEdition, ui.Image>{};
  for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
    final ui.Image? img = await _decodeImageFile(ed.heroAssetPath);
    if (img != null) {
      map[ed] = img;
    }
  }
  return map;
}

Future<void> _capturePortraitScreenshot(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String outputPath,
) async {
  await tester.pump(const Duration(milliseconds: 220));
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = boundaryKey.currentContext!
        .findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final File outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await _loadRealFlutterFonts();
  });

  test(
    'v1.1.0 Steeper Slopes, Higher Speeds, LV_NEO Lateral Banners & Lively Alpine Scenery across all 3 Ski Tracks',
    () {
      // Verify steepened slope metrics & higher velocities
      expect(SkiTrackId.greenBlossomValley.slopeDegrees, equals(24.0));
      expect(SkiTrackId.greenBlossomValley.verticalDropMeters, equals(535.0));
      expect(SkiTrackId.greenBlossomValley.baseSpeedKmh, equals(62.0));
      expect(SkiTrackId.greenBlossomValley.maxSpeedKmh, equals(108.0));
      expect(
        SkiTrackId.greenBlossomValley.summaryMetrics,
        equals('1 200 m • Dénivelé -535 m (24°) • 4 Tremplins'),
      );

      expect(SkiTrackId.blueAsnieresForest.slopeDegrees, equals(34.0));
      expect(SkiTrackId.blueAsnieresForest.verticalDropMeters, equals(980.0));
      expect(SkiTrackId.blueAsnieresForest.baseSpeedKmh, equals(84.0));
      expect(SkiTrackId.blueAsnieresForest.maxSpeedKmh, equals(142.0));
      expect(
        SkiTrackId.blueAsnieresForest.summaryMetrics,
        equals('1 800 m • Dénivelé -980 m (34°) • 7 Tremplins'),
      );

      expect(SkiTrackId.blackVendomePeaks.slopeDegrees, equals(45.0));
      expect(SkiTrackId.blackVendomePeaks.verticalDropMeters, equals(1650.0));
      expect(SkiTrackId.blackVendomePeaks.baseSpeedKmh, equals(108.0));
      expect(SkiTrackId.blackVendomePeaks.maxSpeedKmh, equals(185.0));
      expect(
        SkiTrackId.blackVendomePeaks.summaryMetrics,
        equals('2 500 m • Dénivelé -1 650 m (45°) • 10 Méga-Sauts'),
      );

      // Verify 4 BLENDER_LAB Vivienne Models
      expect(
        VivienneSkiEdition.values,
        equals(<VivienneSkiEdition>[
          VivienneSkiEdition.speedyV03,
          VivienneSkiEdition.wonderland,
          VivienneSkiEdition.giantDenim,
          VivienneSkiEdition.neoBlossom,
        ]),
      );
      expect(
        VivienneSkiEdition.wonderland.blendPath,
        equals('models/vivienne_wonderland.blend'),
      );
      expect(
        VivienneSkiEdition.giantDenim.blendPath,
        equals('models/vivienne_giant_denim.blend'),
      );

      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      expect(engine.isInMenu, isTrue);

      for (final SkiTrackId track in SkiTrackId.values) {
        engine.selectTrack(track);
        expect(engine.selectedTrack, equals(track));
        expect(engine.moguls.length, equals(track.mogulCount));
        expect(engine.jumpRamps.length, equals(track.jumpRampCount));
        expect(engine.slalomGates.length, equals(track.slalomGateCount));
        expect(engine.blossoms.length, equals(track.blossomCount));

        // Bilateral LV_NEO banners (`lvBannerPost`) on both left & right sides
        final List<SkiWorldProp3D> lvBanners = engine.worldProps
            .where((SkiWorldProp3D p) => p.kind == SkiPropKind.lvBannerPost)
            .toList();
        expect(lvBanners.length, greaterThanOrEqualTo(40));
        expect(
          lvBanners.any(
            (SkiWorldProp3D p) => p.x < engine.trackCenterOffsetX(p.z),
          ),
          isTrue,
        );
        expect(
          lvBanners.any(
            (SkiWorldProp3D p) => p.x > engine.trackCenterOffsetX(p.z),
          ),
          isTrue,
        );

        // Lively animated scenery props present on every track
        expect(
          engine.worldProps
              .any((SkiWorldProp3D p) => p.kind == SkiPropKind.cableCarPylon),
          isTrue,
        );
        expect(
          engine.worldProps
              .any((SkiWorldProp3D p) => p.kind == SkiPropKind.cartoonSnowman),
          isTrue,
        );
        expect(
          engine.worldProps.any(
            (SkiWorldProp3D p) => p.kind == SkiPropKind.flutteringPennantPost,
          ),
          isTrue,
        );
        expect(
          engine.worldProps
              .any((SkiWorldProp3D p) => p.kind == SkiPropKind.snowCannon),
          isTrue,
        );
        expect(
          engine.worldProps
              .any((SkiWorldProp3D p) => p.kind == SkiPropKind.alpineChalet),
          isTrue,
        );
        expect(
          engine.worldProps
              .any((SkiWorldProp3D p) => p.kind == SkiPropKind.finishArch),
          isTrue,
        );

        // Steep elevation drop check
        final double dropTotal =
            engine.trackElevationY(0.0) -
            engine.trackElevationY(track.lengthMeters);
        expect(dropTotal, greaterThan(450.0));
      }
    },
  );

  test(
    'Hardware accelerometer carving, Mogul Squash, Big Air Jump, Pine Tree Snowball Crash & Chalet finish',
    () {
      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      engine.selectEdition(VivienneSkiEdition.giantDenim);
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      expect(engine.isInMenu, isFalse);
      expect(engine.speedKmh, greaterThanOrEqualTo(62.0));

      // 1. Hardware accelerometer steering right (ax < 0 in portrait) & left (ax > 0)
      engine.updateHardwareSensor(-4.6, 0.0, 8.6);
      expect(engine.effectiveTiltX, greaterThan(0.20));
      for (int step = 0; step < 12; step++) {
        engine.update(1 / 60);
      }
      expect(engine.animState, equals(VivienneSkiAnimState.carvingRight));
      expect(engine.activeSkierTurntableFrameIndex, greaterThan(12));

      engine.updateHardwareSensor(4.6, 0.0, 8.6);
      for (int step = 0; step < 16; step++) {
        engine.update(1 / 60);
      }
      expect(engine.animState, equals(VivienneSkiAnimState.carvingLeft));
      expect(engine.activeSkierTurntableFrameIndex, lessThan(12));

      engine.calibrateAccelerometer();
      expect(engine.effectiveTiltX, closeTo(0.0, 1e-4));

      // 2. Mogul absorption Squash & Big Air Jump celebration
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      bool sawMogulSquash = false;
      bool sawAirborneJump = false;
      for (int step = 0; step < 680; step++) {
        engine.update(1 / 60);
        if (engine.animState == VivienneSkiAnimState.mogulAbsorptionSquash) {
          sawMogulSquash = true;
        }
        if (engine.animState == VivienneSkiAnimState.airborneCelebration &&
            engine.playerY > 1.0) {
          sawAirborneJump = true;
        }
      }
      expect(sawMogulSquash, isTrue);
      expect(engine.mogulsAbsorbed, greaterThanOrEqualTo(1));
      expect(sawAirborneJump, isTrue);
      expect(engine.jumpsCompleted, greaterThanOrEqualTo(1));
      expect(engine.maxJumpHeightMeters, greaterThan(1.5));

      // 3. Pine Tree Collision (On-Piste & Border) triggers Cartoon Snowball Crash (`VivienneSkiAnimState.snowballCrash`)
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      final SkiWorldProp3D onPistePine = engine.worldProps.firstWhere(
        (SkiWorldProp3D p) =>
            p.isOnPiste &&
            (p.kind == SkiPropKind.alpinePineTree ||
                p.kind == SkiPropKind.giantSnowPine),
      );
      engine.playerZ = onPistePine.z - 0.3;
      engine.playerLateralOffset =
          onPistePine.x - engine.trackCenterOffsetX(onPistePine.z);
      engine.playerY = 0.0;
      engine.update(1 / 60);

      expect(engine.isInSnowballCrash, isTrue);
      expect(engine.animState, equals(VivienneSkiAnimState.snowballCrash));
      expect(engine.animState.label, equals('CHUTE BOULE DE NEIGE !'));
      expect(engine.snowballCrashTimer, greaterThan(1.0));
      expect(
        engine.callouts.any(
          (SkiFloatingCallout c) => c.text.contains('BOULE DE NEIGE'),
        ),
        isTrue,
      );

      // Advance during snowball crash to verify 3 full rotations (`~6π`)
      for (int step = 0; step < 45; step++) {
        engine.update(1 / 60);
      }
      expect(engine.snowballRotationRadians, greaterThan(math.pi * 2.5));

      // Complete snowball crash recovery
      for (int step = 0; step < 40; step++) {
        engine.update(1 / 60);
      }
      expect(engine.isInSnowballCrash, isFalse);

      // Also verify off-piste border pine tree collision triggers Snowball Crash
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      final double maxReach =
          engine.selectedTrack.trackHalfWidthMeters * 1.34;
      final SkiWorldProp3D borderPine = engine.worldProps.firstWhere(
        (SkiWorldProp3D p) =>
            !p.isOnPiste &&
            (p.kind == SkiPropKind.alpinePineTree ||
                p.kind == SkiPropKind.giantSnowPine) &&
            (p.x - engine.trackCenterOffsetX(p.z)).abs() <= maxReach,
      );
      engine.playerZ = borderPine.z - 0.3;
      engine.playerLateralOffset =
          borderPine.x - engine.trackCenterOffsetX(borderPine.z);
      engine.playerY = 0.0;
      engine.update(1 / 60);
      expect(engine.isInSnowballCrash, isTrue);
      expect(engine.animState, equals(VivienneSkiAnimState.snowballCrash));

      // Verify `triggerSnowballCrashForTest()` helper
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      engine.triggerSnowballCrashForTest();
      expect(engine.isInSnowballCrash, isTrue);
      expect(engine.animState, equals(VivienneSkiAnimState.snowballCrash));

      // 4. Complete run & verify Highscores leaderboard insertion
      final int initialCount =
          engine.highscoresForTrack(SkiTrackId.greenBlossomValley).length;
      engine.forceFinishRunForTest();
      expect(engine.isTrackFinished, isTrue);
      expect(engine.lastRunBreakdown, isNotNull);
      expect(
        engine.highscoresForTrack(SkiTrackId.greenBlossomValley).length,
        equals(initialCount + 1),
      );
    },
  );

  testWidgets(
    'Cartoon Main Menu, 4 BLENDER_LAB Vivienne Models, LV_NEO Banners, Lively Scenery, Snowball Crash & 1080x2400 Store Screenshots',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final List<ui.Image?> turntableSprites =
          (await tester.runAsync(_loadTestTurntableSprites))!;
      final ui.Image? lvNeoBannerImage =
          await tester.runAsync<ui.Image?>(_loadTestLvNeoBannerImage);
      final Map<VivienneSkiEdition, ui.Image> editionHeroSprites =
          (await tester.runAsync(_loadTestEditionHeroSprites))!;

      expect(lvNeoBannerImage, isNotNull);
      expect(editionHeroSprites.length, equals(4));

      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      final GlobalKey screenshotKey = GlobalKey();

      await tester.pumpWidget(
        ViviAuSkiApp(
          engine: engine,
          initialTurntableSprites: turntableSprites,
          initialLvNeoBannerImage: lvNeoBannerImage,
          initialEditionHeroSprites: editionHeroSprites,
          autoStartTicker: false,
          screenshotBoundaryKey: screenshotKey,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Starts on Cartoon Main Menu showing all 4 BLENDER_LAB models & steeper track metrics
      expect(find.byKey(const Key('main_menu_overlay')), findsOneWidget);
      expect(find.byKey(const Key('highscores_modal_overlay')), findsNothing);
      expect(
        find.text('1 200 m • Dénivelé -535 m (24°) • 4 Tremplins'),
        findsOneWidget,
      );
      expect(
        find.text('1 800 m • Dénivelé -980 m (34°) • 7 Tremplins'),
        findsOneWidget,
      );
      expect(
        find.text('2 500 m • Dénivelé -1 650 m (45°) • 10 Méga-Sauts'),
        findsOneWidget,
      );

      // Select all 4 BLENDER_LAB Vivienne Editions on Main Menu
      await tester.tap(find.byKey(const Key('select_edition_wonderland')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedEdition, equals(VivienneSkiEdition.wonderland));

      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/01_menu_accueil_cartoon_3_pistes.png',
      );

      await tester.tap(find.byKey(const Key('select_edition_giant_denim')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedEdition, equals(VivienneSkiEdition.giantDenim));

      await tester.tap(find.byKey(const Key('select_edition_neo_blossom')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedEdition, equals(VivienneSkiEdition.neoBlossom));

      await tester.tap(find.byKey(const Key('select_edition_speedy_v03')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedEdition, equals(VivienneSkiEdition.speedyV03));

      // Select Blue & Black Gold Ski Tracks
      await tester.tap(find.byKey(const Key('select_track_piste_bleue')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(engine.selectedTrack, equals(SkiTrackId.blueAsnieresForest));

      await tester.tap(find.byKey(const Key('select_track_piste_noire')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(engine.selectedTrack, equals(SkiTrackId.blackVendomePeaks));

      // 2. Open Highscores Modal & filter by track
      await tester.tap(find.byKey(const Key('open_highscores_button')));
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byKey(const Key('highscores_modal_overlay')), findsOneWidget);

      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/02_tableau_des_scores_pistes.png',
      );

      await tester.tap(find.byKey(const Key('filter_highscores_piste_verte')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        engine.highscoresFilterTrack,
        equals(SkiTrackId.greenBlossomValley),
      );

      await tester.tap(find.byKey(const Key('close_highscores_button')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const Key('highscores_modal_overlay')), findsNothing);

      // 3. Open 3D BLENDER_LAB Gallery & inspect Giant Denim / Wonderland / Speedy v03
      await tester.tap(find.byKey(const Key('open_turntable_gallery_button')));
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.byKey(const Key('vivienne_gallery_panel')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('gallery_select_edition_giant_denim')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedEdition, equals(VivienneSkiEdition.giantDenim));
      engine.rotateTurntableBy(20.0);
      await tester.pump(const Duration(milliseconds: 80));

      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/03_galerie_vivienne_3d_turntable.png',
      );

      await tester.tap(
        find.byKey(const Key('gallery_select_edition_wonderland')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedEdition, equals(VivienneSkiEdition.wonderland));

      await tester.tap(find.byKey(const Key('close_turntable_gallery_button')));
      await tester.pump(const Duration(milliseconds: 120));

      // 4. Start Green Track Run with Vivienne Wonderland & capture Big Air Jump + LV_NEO Banners + Lively Scenery
      await tester.tap(find.byKey(const Key('select_track_piste_verte')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('start_ski_run_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.isInMenu, isFalse);

      engine.calibrateAccelerometer();
      for (int i = 0; i < 470; i++) {
        engine.update(1 / 60);
        if (engine.animState == VivienneSkiAnimState.airborneCelebration &&
            engine.playerY > 2.4) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/04_ski_3d_vue_dos_grand_saut_vivienne.png',
      );

      // 5. Switch to Vivienne Giant Denim on Blue Track (34° slope) & capture high-speed carving with LV Skateboard + LV_NEO banners
      engine.selectEdition(VivienneSkiEdition.giantDenim);
      engine.startRun(track: SkiTrackId.blueAsnieresForest);
      engine.setManualTilt(0.32);
      for (int i = 0; i < 34; i++) {
        engine.update(1 / 60);
      }
      expect(engine.isInSnowballCrash, isFalse);
      expect(engine.animState, equals(VivienneSkiAnimState.carvingRight));
      await tester.pump(const Duration(milliseconds: 100));
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/05_ski_3d_giant_denim_lv_neo_decors.png',
      );
      engine.clearManualTilt();

      // 6. Trigger Cartoon Snowball Crash on Green Track (`triggerSnowballCrashForTest`) & capture 1080x2400 screenshot
      engine.selectEdition(VivienneSkiEdition.wonderland);
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      for (int i = 0; i < 95; i++) {
        engine.update(1 / 60);
      }
      engine.triggerSnowballCrashForTest();
      for (int i = 0; i < 18; i++) {
        engine.update(1 / 60);
      }
      expect(engine.isInSnowballCrash, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('CHUTE BOULE DE NEIGE !'), findsOneWidget);
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/06_ski_3d_chute_boule_de_neige_sapin.png',
      );

      // 7. Verify Chalet Finish Overlay (`track_finished_overlay`)
      engine.forceFinishRunForTest();
      await tester.pump(const Duration(milliseconds: 280));
      expect(find.byKey(const Key('track_finished_overlay')), findsOneWidget);
      await tester.tap(find.byKey(const Key('finish_return_menu_button')));
      await tester.pump(const Duration(milliseconds: 140));
      expect(find.byKey(const Key('main_menu_overlay')), findsOneWidget);

      for (final String shot in <String>[
        'screenshots/01_menu_accueil_cartoon_3_pistes.png',
        'screenshots/02_tableau_des_scores_pistes.png',
        'screenshots/03_galerie_vivienne_3d_turntable.png',
        'screenshots/04_ski_3d_vue_dos_grand_saut_vivienne.png',
        'screenshots/05_ski_3d_giant_denim_lv_neo_decors.png',
        'screenshots/06_ski_3d_chute_boule_de_neige_sapin.png',
      ]) {
        final bool exists =
            (await tester.runAsync(() async => File(shot).exists()))!;
        expect(exists, isTrue, reason: 'Expected Store screenshot $shot');
      }
    },
  );
}
