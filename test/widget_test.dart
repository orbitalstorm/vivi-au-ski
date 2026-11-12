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
import 'package:vivi_au_ski/painters/vivienne_3d_volumetric_rig.dart';

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

Future<Map<VivienneSkiEdition, List<ui.Image?>>> _loadTestEditionPoseSprites({
  required bool isFront,
}) async {
  final Map<VivienneSkiEdition, List<ui.Image?>> result =
      <VivienneSkiEdition, List<ui.Image?>>{};
  for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
    final List<String> paths =
        isFront ? ed.frontPoseAssetPaths : ed.rearPoseAssetPaths;
    final List<ui.Image?> poses = <ui.Image?>[];
    for (final String path in paths) {
      poses.add(await _decodeImageFile(path));
    }
    result[ed] = poses;
  }
  return result;
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
    'v1.2.0 Strictly 3 BLENDER_LAB Vivienne 3D Cycles Models, Pose Asset Paths & Track Metrics',
    () {
      // Strictly 3 official playable Viviennes (`neoBlossom` removed)
      expect(VivienneSkiEdition.values.length, equals(3));
      expect(
        VivienneSkiEdition.values,
        equals(<VivienneSkiEdition>[
          VivienneSkiEdition.speedyV03,
          VivienneSkiEdition.wonderland,
          VivienneSkiEdition.giantDenim,
        ]),
      );

      for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
        expect(ed.rearPoseAssetPaths.length, equals(5));
        expect(ed.frontPoseAssetPaths.length, equals(5));
        for (int i = 0; i < 5; i++) {
          expect(
            File(ed.rearPoseAssetPaths[i]).existsSync(),
            isTrue,
            reason: 'Missing rear Cycles pose ${ed.rearPoseAssetPaths[i]}',
          );
          expect(
            File(ed.frontPoseAssetPaths[i]).existsSync(),
            isTrue,
            reason: 'Missing front Cycles pose ${ed.frontPoseAssetPaths[i]}',
          );
          final double rearSole =
              ed.soleCenterXFraction(isFront: false, poseIndex: i);
          final double frontSole =
              ed.soleCenterXFraction(isFront: true, poseIndex: i);
          expect(rearSole, inInclusiveRange(0.30, 0.70));
          expect(frontSole, inInclusiveRange(0.30, 0.70));
        }
      }

      // Bonus aerial tricks (`Saut 360°` +250, `Saut Périlleux` +300)
      expect(SkiAerialTrickKind.saut360.bonusPoints, equals(250));
      expect(SkiAerialTrickKind.sautPerilleux.bonusPoints, equals(300));

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
              .any((SkiWorldProp3D p) => p.kind == SkiPropKind.cableCarPylon),
          isTrue,
        );
      }
    },
  );

  test(
    'v1.2.0 Bonus Jumps (Saut 360° & Saut Périlleux), Accelerometer Carving, Pause & Snowball Crash',
    () {
      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      engine.selectEdition(VivienneSkiEdition.wonderland);
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      expect(engine.isInMenu, isFalse);

      // 1. Hardware accelerometer carving right & left + pose mapping
      engine.updateHardwareSensor(-4.6, 0.0, 8.6);
      for (int step = 0; step < 12; step++) {
        engine.update(1 / 60);
      }
      expect(engine.animState, equals(VivienneSkiAnimState.carvingRight));
      expect(engine.activeSkierPoseIndex, equals(1));

      engine.calibrateAccelerometer();
      expect(engine.effectiveTiltX, closeTo(0.0, 1e-4));

      // 2. Ramp #1 triggers Saut 360° (+250 pts, spin 0 -> 2π)
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      final SkiJumpRamp3D firstRamp = engine.jumpRamps.first;
      engine.playerZ = firstRamp.z + firstRamp.length * 0.30;
      engine.playerLateralOffset =
          firstRamp.x - engine.trackCenterOffsetX(engine.playerZ);
      engine.playerY = firstRamp.heightMeters * 0.80;
      engine.update(1 / 60);

      expect(engine.currentAerialTrick, equals(SkiAerialTrickKind.saut360));
      expect(engine.activeHudStatusLabel, equals('SAUT 360° +250'));
      expect(
        engine.callouts
            .any((SkiFloatingCallout c) => c.text == 'SAUT 360° +250'),
        isTrue,
      );

      double peakSpin = 0.0;
      for (int step = 0; step < 85 && engine.playerY > 0.05; step++) {
        engine.update(1 / 60);
        peakSpin = math.max(peakSpin, engine.trickSpinAngle);
      }
      expect(peakSpin, greaterThan(math.pi * 1.65));

      // 3. Ramp #2 alternates to Saut Périlleux (+300 pts, flip 0 -> 2π)
      final SkiJumpRamp3D secondRamp = engine.jumpRamps[1];
      engine.playerY = secondRamp.heightMeters * 0.80;
      engine.playerVy = 0.0;
      engine.playerZ = secondRamp.z + secondRamp.length * 0.30;
      engine.playerLateralOffset =
          secondRamp.x - engine.trackCenterOffsetX(engine.playerZ);
      engine.update(1 / 60);

      expect(
        engine.currentAerialTrick,
        equals(SkiAerialTrickKind.sautPerilleux),
      );
      expect(engine.activeHudStatusLabel, equals('SAUT PÉRILLEUX +300'));
      expect(
        engine.callouts
            .any((SkiFloatingCallout c) => c.text == 'SAUT PÉRILLEUX +300'),
        isTrue,
      );

      double peakFlip = 0.0;
      for (int step = 0; step < 90 && engine.playerY > 0.05; step++) {
        engine.update(1 / 60);
        peakFlip = math.max(peakFlip, engine.trickFlipAngle);
      }
      expect(peakFlip, greaterThan(math.pi * 1.65));

      // 4. Pause & Resume freezes simulation cleanly
      final double zBeforePause = engine.playerZ;
      engine.togglePause();
      expect(engine.isPaused, isTrue);
      engine.update(0.5);
      expect(engine.playerZ, equals(zBeforePause));
      engine.togglePause();
      expect(engine.isPaused, isFalse);

      // 5. Pine Tree Snowball Crash & Chalet Finish
      engine.triggerSnowballCrashForTest();
      expect(engine.isInSnowballCrash, isTrue);
      engine.forceFinishRunForTest();
      expect(engine.isTrackFinished, isTrue);
      expect(engine.lastRunBreakdown, isNotNull);
    },
  );

  test(
    'v1.3.0 22-Bone Skeletal Articulation & True 3D Volumetric Thickness at Profile (90°) and 3/4 (60°)',
    () {
      const List<String> requiredAnimatedBones = <String>[
        'Leg_L',
        'Leg_R',
        'Foot_L',
        'Foot_R',
        'Arm_Upper_L',
        'Arm_Upper_R',
        'Arm_Lower_L',
        'Arm_Lower_R',
        'Head',
        'Petal_Top',
        'Petal_Bottom',
        'Petal_Left',
        'Petal_Right',
        'Speedy_Bag_Bone',
      ];

      // 1. Verify every required bone exists and animates independently over time
      final VivienneSkeletonPose3D poseT0 = VivienneSkeletonPose3D.evaluate(
        edition: VivienneSkiEdition.speedyV03,
        timeSeconds: 0.15,
        mode: VivienneMotionMode.skiRun,
        animState: VivienneSkiAnimState.carvingRight,
        carveTilt: 0.55,
      );
      final VivienneSkeletonPose3D poseT1 = VivienneSkeletonPose3D.evaluate(
        edition: VivienneSkiEdition.speedyV03,
        timeSeconds: 0.58,
        mode: VivienneMotionMode.skiRun,
        animState: VivienneSkiAnimState.carvingRight,
        carveTilt: 0.55,
      );

      for (final String boneName in requiredAnimatedBones) {
        final VivienneBoneState3D? b0 = poseT0.boneByName(boneName);
        final VivienneBoneState3D? b1 = poseT1.boneByName(boneName);
        expect(b0, isNotNull, reason: 'Missing bone $boneName at t0');
        expect(b1, isNotNull, reason: 'Missing bone $boneName at t1');

        final double rotDelta = (b1!.localRx - b0!.localRx).abs() +
            (b1.localRy - b0.localRy).abs() +
            (b1.localRz - b0.localRz).abs();
        final double worldProbeDelta = b1.worldMatrix
            .transformPoint(b1.bone.restPivot + const Vec3(0.08, -0.14, 0.12))
            .distanceTo(
              b0.worldMatrix.transformPoint(
                b0.bone.restPivot + const Vec3(0.08, -0.14, 0.12),
              ),
            );
        expect(
          rotDelta + worldProbeDelta,
          greaterThan(0.015),
          reason: 'Bone $boneName should animate continuously between frames',
        );
      }

      // Left & Right legs and arms articulate independently (asymmetric / opposing!)
      expect(
        (poseT0.boneByName('Leg_L')!.localRx -
                poseT0.boneByName('Leg_R')!.localRx)
            .abs(),
        greaterThan(0.08),
      );
      expect(
        (poseT0.boneByName('Arm_Upper_L')!.localRx -
                poseT0.boneByName('Arm_Upper_R')!.localRx)
            .abs(),
        greaterThan(0.10),
      );

      // 2. Verify projected 3D mesh width NEVER collapses by `cos(yaw)` at 90° (profile) & 60° (3/4)!
      for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
        final VivienneSkeletonPose3D frontPose =
            VivienneSkeletonPose3D.evaluate(
          edition: ed,
          timeSeconds: 0.45,
          mode: VivienneMotionMode.skiRun,
          aerialTrick: SkiAerialTrickKind.saut360,
          isAirborne: true,
          yawDegrees: 0.0,
          trickProgress: 0.50,
        );
        final VivienneSkeletonPose3D threeQuarterPose =
            VivienneSkeletonPose3D.evaluate(
          edition: ed,
          timeSeconds: 0.45,
          mode: VivienneMotionMode.skiRun,
          aerialTrick: SkiAerialTrickKind.saut360,
          isAirborne: true,
          yawDegrees: 60.0,
          trickProgress: 0.50,
        );
        final VivienneSkeletonPose3D profilePose =
            VivienneSkeletonPose3D.evaluate(
          edition: ed,
          timeSeconds: 0.45,
          mode: VivienneMotionMode.skiRun,
          aerialTrick: SkiAerialTrickKind.saut360,
          isAirborne: true,
          yawDegrees: 90.0,
          trickProgress: 0.50,
        );

        // Check both without skis (pure figurine body + scissor legs + head 0.56m depth) AND with skis!
        final VivienneProjectedBounds frontBody =
            Vivienne3DVolumetricRig.computeProjectedBounds(
          edition: ed,
          pose: frontPose,
          soleAnchorScreen: const Offset(180, 400),
          pixelsPerMeter: 100.0,
          includeSkisAndPoles: false,
        );
        final VivienneProjectedBounds threeQuarterBody =
            Vivienne3DVolumetricRig.computeProjectedBounds(
          edition: ed,
          pose: threeQuarterPose,
          soleAnchorScreen: const Offset(180, 400),
          pixelsPerMeter: 100.0,
          includeSkisAndPoles: false,
        );
        final VivienneProjectedBounds profileBody =
            Vivienne3DVolumetricRig.computeProjectedBounds(
          edition: ed,
          pose: profilePose,
          soleAnchorScreen: const Offset(180, 400),
          pixelsPerMeter: 100.0,
          includeSkisAndPoles: false,
        );
        final VivienneProjectedBounds profileWithSkis =
            Vivienne3DVolumetricRig.computeProjectedBounds(
          edition: ed,
          pose: profilePose,
          soleAnchorScreen: const Offset(180, 400),
          pixelsPerMeter: 100.0,
          includeSkisAndPoles: true,
        );

        expect(frontBody.renderedTriangleCount, greaterThan(1200));
        // A flat sprite with `cos(90°)` collapses to 0 (or fake 0.28 clamp);
        // our true 3D ellipsoid head (0.56m Y-depth) + 3D scissor legs + V-arms spans > 0.72m (> 72px at 100px/m)!
        expect(
          profileBody.boundingBox.width,
          greaterThan(72.0),
          reason:
              'Profile (yaw=90°) 3D body width for $ed must preserve full volumetric depth',
        );
        expect(
          threeQuarterBody.boundingBox.width,
          greaterThan(frontBody.boundingBox.width * 0.62),
          reason:
              '3/4 view (yaw=60°) 3D width for $ed must exceed flat cos(60°)=0.50 foreshortening',
        );
        expect(
          profileWithSkis.boundingBox.width,
          greaterThan(135.0),
          reason:
              'Profile (yaw=90°) with 3D skis & scissor legs must span > 1.35m in depth',
        );
      }
    },
  );

  testWidgets(
    'v1.3.0 3 Viviennes 3D Volumetric Rig, Saut 360° & Périlleux 3D, Pause 3D Inspection & 6 Store Screenshots (1080x2400)',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final Map<VivienneSkiEdition, List<ui.Image?>> rearPoseSprites =
          (await tester.runAsync(
        () => _loadTestEditionPoseSprites(isFront: false),
      ))!;
      final Map<VivienneSkiEdition, List<ui.Image?>> frontPoseSprites =
          (await tester.runAsync(
        () => _loadTestEditionPoseSprites(isFront: true),
      ))!;
      final List<ui.Image?> turntableSprites =
          (await tester.runAsync(_loadTestTurntableSprites))!;
      final ui.Image? lvNeoBannerImage =
          await tester.runAsync<ui.Image?>(_loadTestLvNeoBannerImage);
      final Map<VivienneSkiEdition, ui.Image> editionHeroSprites =
          (await tester.runAsync(_loadTestEditionHeroSprites))!;

      expect(lvNeoBannerImage, isNotNull);
      expect(editionHeroSprites.length, equals(3));
      for (final VivienneSkiEdition ed in VivienneSkiEdition.values) {
        expect(rearPoseSprites[ed]!.whereType<ui.Image>().length, equals(5));
        expect(frontPoseSprites[ed]!.whereType<ui.Image>().length, equals(5));
      }

      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      final GlobalKey screenshotKey = GlobalKey();

      await tester.pumpWidget(
        ViviAuSkiApp(
          engine: engine,
          initialRearPoseSprites: rearPoseSprites,
          initialFrontPoseSprites: frontPoseSprites,
          initialTurntableSprites: turntableSprites,
          initialLvNeoBannerImage: lvNeoBannerImage,
          initialEditionHeroSprites: editionHeroSprites,
          autoStartTicker: false,
          screenshotBoundaryKey: screenshotKey,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify compact viewport (`360x740dp`) produces zero overflow on Menu
      await tester.binding.setSurfaceSize(const Size(360, 740));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pump(const Duration(milliseconds: 80));

      // 1. Screenshot 01: Title & 3D Models Selector (strictly 3 Viviennes, Wonderland selected)
      expect(find.byKey(const Key('main_menu_overlay')), findsOneWidget);
      expect(
        find.byKey(const Key('select_edition_neo_blossom')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('select_edition_wonderland')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(engine.selectedEdition, equals(VivienneSkiEdition.wonderland));

      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/01_title_and_3d_gallery_preview.png',
      );

      // Verify 3D Gallery also shows strictly 3 Viviennes and switches to 180° Rear view
      await tester.tap(find.byKey(const Key('open_turntable_gallery_button')));
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.byKey(const Key('vivienne_gallery_panel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('turntable_rear_180_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.turntableAngleDegrees, equals(180.0));
      await tester.tap(find.byKey(const Key('close_turntable_gallery_button')));
      await tester.pump(const Duration(milliseconds: 120));

      // 2. Screenshot 02: Downhill 3D Carving Action (`speedyV03` 3D yaw/roll, asymmetric leg flexion, poles & swinging Speedy bag)
      engine.selectEdition(VivienneSkiEdition.speedyV03);
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      final SkiWorldProp3D firstChairlift = engine.worldProps.firstWhere(
        (SkiWorldProp3D p) => p.kind == SkiPropKind.cableCarPylon,
      );
      engine.playerZ = firstChairlift.z - 48.0;
      engine.playerLateralOffset = -3.4;
      engine.setManualTilt(0.72);
      for (int i = 0; i < 22; i++) {
        engine.update(1 / 60);
      }
      expect(engine.animState, equals(VivienneSkiAnimState.carvingRight));
      await tester.pump(const Duration(milliseconds: 100));
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/02_downhill_carving_action.png',
      );
      engine.clearManualTilt();

      // 3. Screenshot 03: `Wonderland` Midair `SAUT 360° +250` at 3/4-Front (`yaw ≈ 38°` from front!)
      // Clearly revealing 3D wooden head volume, red Monogram petal edges, 3D bunny, 3D heart balloon, V-arms & 3D scissor legs!
      engine.selectEdition(VivienneSkiEdition.wonderland);
      engine.startRun(track: SkiTrackId.greenBlossomValley);
      final SkiSlalomGate3D targetGate = engine.slalomGates[2];
      engine.playerZ = targetGate.z - 22.0;
      engine.playerLateralOffset = 0.0;
      for (int i = 0; i < 8; i++) {
        engine.update(1 / 60);
      }
      engine.triggerBonusJumpForTest(
        trick: SkiAerialTrickKind.saut360,
        progress: 0.415,
        apexHeightMeters: 3.15,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('SAUT 360° +250'), findsOneWidget);
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/03_slalom_gates_and_hud.png',
      );

      // 4. Screenshot 04: `Giant Denim` Midair `SAUT PÉRILLEUX +300` in True 3D Pitch Backflip + Lateral Perspective!
      engine.selectEdition(VivienneSkiEdition.giantDenim);
      engine.startRun(track: SkiTrackId.blueAsnieresForest);
      final SkiJumpRamp3D targetRamp = engine.jumpRamps.first;
      engine.playerZ = targetRamp.z + 1.5;
      engine.playerLateralOffset =
          targetRamp.x - engine.trackCenterOffsetX(engine.playerZ);
      for (int i = 0; i < 6; i++) {
        engine.update(1 / 60);
      }
      engine.triggerBonusJumpForTest(
        trick: SkiAerialTrickKind.sautPerilleux,
        progress: 0.46,
        apexHeightMeters: 3.45,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('SAUT PÉRILLEUX +300'), findsOneWidget);
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/04_jump_ramp_squash_stretch.png',
      );

      // 5. Screenshot 05: Pause Menu Overlay over HUD & 3D Piste (`pause_modal_overlay`)
      engine.selectEdition(VivienneSkiEdition.speedyV03);
      engine.startRun(track: SkiTrackId.blueAsnieresForest);
      for (int i = 0; i < 55; i++) {
        engine.update(1 / 60);
      }
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byKey(const Key('hud_pause_button')));
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.byKey(const Key('pause_modal_overlay')), findsOneWidget);
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/05_pause_overlay_hud.png',
      );

      await tester.tap(find.byKey(const Key('resume_run_button')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const Key('pause_modal_overlay')), findsNothing);

      // 6. Screenshot 06: Finish Podium Modal (`track_finished_overlay`)
      engine.blossomsCollected = 24;
      engine.blossomPoints = 1200;
      engine.slalomPassed = 9;
      engine.slalomPoints = 1350;
      engine.jumpsCompleted = 4;
      engine.mogulsAbsorbed = 6;
      engine.jumpAndMogulPoints = 1610;
      engine.elapsedSeconds = 46.8;
      engine.forceFinishRunForTest();
      await tester.pump(const Duration(milliseconds: 280));
      expect(find.byKey(const Key('track_finished_overlay')), findsOneWidget);
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/06_finish_podium_modal.png',
      );

      for (final String shot in <String>[
        'screenshots/01_title_and_3d_gallery_preview.png',
        'screenshots/02_downhill_carving_action.png',
        'screenshots/03_slalom_gates_and_hud.png',
        'screenshots/04_jump_ramp_squash_stretch.png',
        'screenshots/05_pause_overlay_hud.png',
        'screenshots/06_finish_podium_modal.png',
      ]) {
        final bool exists =
            (await tester.runAsync(() async => File(shot).exists()))!;
        expect(exists, isTrue, reason: 'Expected Store screenshot $shot');
      }
    },
  );
}
