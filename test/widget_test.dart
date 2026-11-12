import 'dart:io';
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

Future<List<ui.Image?>> _loadTestTurntableSprites() async {
  final List<ui.Image?> list = List<ui.Image?>.filled(
    VivienneTurntableSpec.frameCount,
    null,
  );
  for (int i = 0; i < VivienneTurntableSpec.frameCount; i++) {
    final File f = File(VivienneTurntableSpec.assetPathForIndex(i));
    if (await f.exists()) {
      final Uint8List bytes = await f.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      list[i] = frame.image;
    }
  }
  return list;
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
    '3 Ski Tracks generate complete deterministic 3D scenery, moguls, jump ramps, slalom gates & blossoms',
    () {
      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      expect(engine.isInMenu, isTrue);

      for (final SkiTrackId track in SkiTrackId.values) {
        engine.selectTrack(track);
        expect(engine.selectedTrack, equals(track));
        expect(engine.moguls.length, equals(track.mogulCount));
        expect(engine.jumpRamps.length, equals(track.jumpRampCount));
        expect(engine.slalomGates.length, equals(track.slalomGateCount));
        expect(engine.blossoms.length, equals(track.blossomCount));
        expect(
          engine.worldProps
              .any((SkiWorldProp3D p) => p.kind == SkiPropKind.finishArch),
          isTrue,
        );
      }
    },
  );

  test(
    'Hardware accelerometer carving, mogul Squash absorption, Big Air Jump celebration & Chalet finish leaderboard',
    () {
      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      expect(engine.isInMenu, isFalse);

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

      // Calibrate resets neutral tilt
      engine.calibrateAccelerometer();
      expect(engine.effectiveTiltX, closeTo(0.0, 1e-4));

      // 2. Mogul absorption Squash (`mogulAbsorptionSquash`) at first centered mogul (`z = 52m`)
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      bool sawMogulSquash = false;
      bool sawAirborneJump = false;
      for (int step = 0; step < 720; step++) {
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

      // 3. Complete run & verify Highscores leaderboard insertion
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
    'Cartoon Main Menu, 3 Track Selectors, Highscores Modal, 360 Turntable Gallery & 1080x2400 Store Screenshots',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final List<ui.Image?> turntableSprites =
          (await tester.runAsync(_loadTestTurntableSprites))!;
      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      final GlobalKey screenshotKey = GlobalKey();

      await tester.pumpWidget(
        ViviAuSkiApp(
          engine: engine,
          initialTurntableSprites: turntableSprites,
          autoStartTicker: false,
          screenshotBoundaryKey: screenshotKey,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Starts on Cartoon Main Menu without Highscores modal open
      expect(find.byKey(const Key('main_menu_overlay')), findsOneWidget);
      expect(find.byKey(const Key('highscores_modal_overlay')), findsNothing);

      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/01_menu_accueil_cartoon_3_pistes.png',
      );

      // Select Blue Track and Black Gold Track
      await tester.tap(find.byKey(const Key('select_track_piste_bleue')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(engine.selectedTrack, equals(SkiTrackId.blueAsnieresForest));

      await tester.tap(find.byKey(const Key('select_track_piste_noire')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(engine.selectedTrack, equals(SkiTrackId.blackVendomePeaks));

      // Open Highscores Modal
      await tester.tap(find.byKey(const Key('open_highscores_button')));
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.byKey(const Key('highscores_modal_overlay')), findsOneWidget);

      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/02_tableau_des_scores_pistes.png',
      );

      await tester.tap(find.byKey(const Key('close_highscores_button')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const Key('highscores_modal_overlay')), findsNothing);

      // Open 360° Vivienne Turntable Gallery & tilt rotate
      await tester.tap(find.byKey(const Key('open_turntable_gallery_button')));
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.byKey(const Key('vivienne_gallery_panel')), findsOneWidget);
      engine.updateHardwareSensor(-4.0, 0.0, 8.8);
      engine.update(0.1);
      await tester.pump(const Duration(milliseconds: 80));

      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/03_galerie_vivienne_3d_turntable.png',
      );

      await tester.tap(find.byKey(const Key('close_turntable_gallery_button')));
      await tester.pump(const Duration(milliseconds: 120));

      // Select Green Track & Start 3D Ski Run
      await tester.tap(find.byKey(const Key('select_track_piste_verte')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('start_ski_run_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.isInMenu, isFalse);

      // Advance to Big Air Jump apex (`z ~ 102m`) and capture rear-view 3D jump screenshot!
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

      final bool exists = (await tester.runAsync(
        () async =>
            File('screenshots/04_ski_3d_vue_dos_grand_saut_vivienne.png')
                .exists(),
      ))!;
      expect(exists, isTrue);
    },
  );
}
