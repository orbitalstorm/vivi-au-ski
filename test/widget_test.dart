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
import 'package:vivi_au_ski/painters/ski_3d_painter.dart';
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
    'v1.2.0–v1.4.0 Strictly 3 BLENDER_LAB Vivienne 3D Models, Pose Asset Paths & Updated Track Metrics',
    () {
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

      expect(SkiAerialTrickKind.saut360.bonusPoints, equals(250));
      expect(SkiAerialTrickKind.sautPerilleux.bonusPoints, equals(300));

      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      expect(engine.isInMenu, isTrue);
      expect(engine.selectedGameMode, equals(SkiGameMode.descenteBosses));

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
    'v1.3.0–v1.4.0 22-Bone Skeletal Articulation, Zero Walk Cycle in Downhill & Spectators, and True 3D Volumetric Thickness',
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

      // 1. Verify every required bone exists and suspends/animates smoothly over time
      final VivienneSkeletonPose3D poseT0 = VivienneSkeletonPose3D.evaluate(
        edition: VivienneSkiEdition.speedyV03,
        timeSeconds: 0.05,
        mode: VivienneMotionMode.skiRun,
        animState: VivienneSkiAnimState.carvingRight,
        carveTilt: 0.55,
      );
      final VivienneSkeletonPose3D poseT1 = VivienneSkeletonPose3D.evaluate(
        edition: VivienneSkiEdition.speedyV03,
        timeSeconds: 0.27,
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
          greaterThan(0.012),
          reason: 'Bone $boneName should animate/suspend continuously',
        );
      }

      // 2. STRICT ZERO WALK CYCLE IN DOWNHILL SCHUSS & CARVING (`ORB-72` Req #1):
      //    - In neutral schuss (`carveTilt == 0`), `Leg_L.localRx == Leg_R.localRx`
      //      and `Arm_Upper_L.localRx == Arm_Upper_R.localRx` at ALL times `t`!
      //    - In carving (`carveTilt == ±0.6`), static edge angulation (`Leg_L.localRx - Leg_R.localRx`)
      //      is non-zero (> 0.08) for inside/outside ski flexion, AND stays strictly CONSTANT
      //      across `t` (zero alternating forward/backward walk cycle!).
      const List<double> sampleTimes = <double>[0.0, 0.19, 0.41, 0.68, 0.93];
      for (final double t in sampleTimes) {
        final VivienneSkeletonPose3D neutralPose =
            VivienneSkeletonPose3D.evaluate(
          edition: VivienneSkiEdition.speedyV03,
          timeSeconds: t,
          mode: VivienneMotionMode.skiRun,
          animState: VivienneSkiAnimState.glidingRearNeutral,
          carveTilt: 0.0,
        );
        expect(
          neutralPose.boneByName('Leg_L')!.localRx,
          closeTo(neutralPose.boneByName('Leg_R')!.localRx, 1e-9),
          reason: 'Neutral schuss must keep both legs strictly parallel at t=$t',
        );
        expect(
          neutralPose.boneByName('Arm_Upper_L')!.localRx,
          closeTo(neutralPose.boneByName('Arm_Upper_R')!.localRx, 1e-9),
          reason: 'Neutral schuss must never swing arms in a walk cycle at t=$t',
        );
      }

      double? refCarveLegDiff;
      double? refCarveArmDiff;
      for (final double t in sampleTimes) {
        final VivienneSkeletonPose3D carvePose =
            VivienneSkeletonPose3D.evaluate(
          edition: VivienneSkiEdition.wonderland,
          timeSeconds: t,
          mode: VivienneMotionMode.skiRun,
          animState: VivienneSkiAnimState.carvingRight,
          carveTilt: 0.60,
        );
        final double legDiff = carvePose.boneByName('Leg_L')!.localRx -
            carvePose.boneByName('Leg_R')!.localRx;
        final double armDiff = carvePose.boneByName('Arm_Upper_L')!.localRx -
            carvePose.boneByName('Arm_Upper_R')!.localRx;
        expect(legDiff.abs(), greaterThan(0.08));
        expect(armDiff.abs(), greaterThan(0.10));
        refCarveLegDiff ??= legDiff;
        refCarveArmDiff ??= armDiff;
        expect(
          legDiff,
          closeTo(refCarveLegDiff, 1e-9),
          reason:
              'Carving leg angulation must remain constant over time (zero alternating walk!)',
        );
        expect(
          armDiff,
          closeTo(refCarveArmDiff, 1e-9),
          reason:
              'Carving arm balance must remain constant over time (zero alternating walk!)',
        );
      }

      // 3. STRICT ZERO WALK CYCLE + JUMPING/WAVING FOR 3D SPECTATORS (`ORB-72` Req #5):
      for (final VivienneSpectatorCheerStyle style
          in VivienneSpectatorCheerStyle.values) {
        double minArmAbduction = 1e9;
        double maxArmAbduction = -1e9;
        double maxJumpZ = 0.0;

        for (int step = 0; step < 24; step++) {
          final double t = step * 0.08;
          final VivienneSkeletonPose3D specPose =
              VivienneSkeletonPose3D.evaluate(
            edition: VivienneSkiEdition.giantDenim,
            timeSeconds: t,
            mode: VivienneMotionMode.spectatorCheer,
            cheerStyle: style,
            yawDegrees: 44.0,
          );
          // Legs must NEVER alternate in a walk cycle (`Leg_L.localRx == Leg_R.localRx`)!
          expect(
            specPose.boneByName('Leg_L')!.localRx,
            closeTo(specPose.boneByName('Leg_R')!.localRx, 1e-9),
            reason:
                'Spectator cheer ($style) must keep both legs in-phase (zero walk cycle) at t=$t',
          );
          final double armAbduct =
              specPose.boneByName('Arm_Upper_R')!.localRy.abs();
          minArmAbduction = math.min(minArmAbduction, armAbduct);
          maxArmAbduction = math.max(maxArmAbduction, armAbduct);
          maxJumpZ = math.max(
            maxJumpZ,
            specPose.boneByName('Root')!.localOffset.z,
          );
        }

        expect(
          maxArmAbduction,
          greaterThan(1.75),
          reason: 'Spectator ($style) must raise arms high in cheer',
        );
        expect(
          maxArmAbduction - minArmAbduction,
          greaterThan(0.20),
          reason: 'Spectator ($style) must actively wave arms over time',
        );
        if (style != VivienneSpectatorCheerStyle.waveArms) {
          expect(
            maxJumpZ,
            greaterThan(0.10),
            reason: 'Jumping spectator ($style) must leap vertically off snow',
          );
        }
      }

      // 4. Verify projected 3D mesh width NEVER collapses by `cos(yaw)` at 90° (profile) & 60° (3/4)!
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
        expect(
          profileBody.boundingBox.width,
          greaterThan(58.0),
          reason:
              'Profile (yaw=90°) 3D body width for $ed must preserve full 3D head/body volume',
        );
        expect(
          threeQuarterBody.boundingBox.width,
          greaterThan(frontBody.boundingBox.width * 0.52),
          reason:
              '3/4 view (yaw=60°) 3D width for $ed must exceed flat cos(60°)=0.50 foreshortening',
        );
        expect(
          profileWithSkis.boundingBox.width,
          greaterThan(135.0),
          reason:
              'Profile (yaw=90°) with parallel 3D skis must span > 1.35m in depth',
        );
      }
    },
  );

  test(
    'v1.4.0 Dramatic Alpine Relief, Mesh-Integrated Moguls, 3 Ramp Size Tiers, Full Slalom Mode & 3D Vivienne Spectators',
    () {
      final SkiGameEngine engine = SkiGameEngine(seed: 2026);

      for (final SkiTrackId track in SkiTrackId.values) {
        engine.selectGameMode(SkiGameMode.descenteBosses);
        engine.selectTrack(track);

        // 1. Multi-section Alpine Relief (`ORB-72` Req #2):
        //    Verify substantial crest/trough relief (> 20m peak-to-trough) AND alternating
        //    flat/convex replat sections + steep plunging walls!
        double minRelief = 1e9;
        double maxRelief = -1e9;
        double minSlopeGrad = 1e9;
        double maxSlopeGrad = -1e9;
        for (double z = 20.0; z <= track.lengthMeters - 40.0; z += 8.0) {
          final double r = engine.relativeReliefAtZ(z);
          final double g = engine.localSlopeGradientAt(z);
          minRelief = math.min(minRelief, r);
          maxRelief = math.max(maxRelief, r);
          minSlopeGrad = math.min(minSlopeGrad, g);
          maxSlopeGrad = math.max(maxSlopeGrad, g);
        }
        expect(
          maxRelief - minRelief,
          greaterThan(22.0),
          reason: '$track must feature dramatic multi-section vertical relief',
        );
        expect(
          maxSlopeGrad - minSlopeGrad,
          greaterThan(0.55),
          reason:
              '$track must alternate flat/convex replats and steep plunging walls',
        );

        // 2. Mesh-integrated 3D Moguls (`ORB-72` Req #3):
        expect(engine.moguls.length, equals(track.mogulCount));
        for (final SkiMogul3D m in engine.moguls) {
          final double mogulLift = engine.mogulElevationAt(m.x, m.z);
          final double snowH = engine.snowSurfaceHeightAt(m.x, m.z);
          expect(mogulLift, greaterThanOrEqualTo(m.heightMeters * 0.99));
          expect(
            snowH,
            greaterThan(engine.relativeReliefAtZ(m.z) + m.heightMeters * 0.95),
          );
        }

        // 3. All 3 Ramp Size Tiers (`small`, `medium`, `large`) present (`ORB-72` Req #3):
        expect(engine.jumpRamps.length, equals(track.jumpRampCount));
        final Set<SkiRampSizeTier> tiers =
            engine.jumpRamps.map((SkiJumpRamp3D r) => r.sizeTier).toSet();
        expect(
          tiers,
          containsAll(SkiRampSizeTier.values),
          reason: '$track must include small, medium, and large jump ramps',
        );
        expect(
          SkiRampSizeTier.large.heightMeters,
          greaterThan(SkiRampSizeTier.medium.heightMeters),
        );
        expect(
          SkiRampSizeTier.medium.heightMeters,
          greaterThan(SkiRampSizeTier.small.heightMeters),
        );

        // 4. 3D Vivienne Spectators on BOTH borders from ALL 3 BLENDER_LAB models (`ORB-72` Req #5):
        final List<SkiWorldProp3D> specs = engine.spectatorProps;
        expect(specs.length, greaterThanOrEqualTo(24));
        bool hasLeftBorder = false;
        bool hasRightBorder = false;
        final Set<VivienneSkiEdition> specEditions = <VivienneSkiEdition>{};
        final Set<VivienneSpectatorCheerStyle> specStyles =
            <VivienneSpectatorCheerStyle>{};
        for (final SkiWorldProp3D sp in specs) {
          final double cx = engine.trackCenterOffsetX(sp.z);
          if (sp.x < cx - track.trackHalfWidthMeters) hasLeftBorder = true;
          if (sp.x > cx + track.trackHalfWidthMeters) hasRightBorder = true;
          if (sp.spectatorEdition != null) {
            specEditions.add(sp.spectatorEdition!);
          }
          if (sp.spectatorCheerStyle != null) {
            specStyles.add(sp.spectatorCheerStyle!);
          }
        }
        expect(hasLeftBorder, isTrue);
        expect(hasRightBorder, isTrue);
        expect(specEditions, containsAll(VivienneSkiEdition.values));
        expect(specStyles, containsAll(VivienneSpectatorCheerStyle.values));

        // 5. Full Slalom Mode (`SkiGameMode.slalomComplet`, `ORB-72` Req #4):
        //    Strict Left (`centerX < cx`) / Right (`centerX > cx`) alternation!
        engine.selectGameMode(SkiGameMode.slalomComplet);
        expect(engine.isSlalomMode, isTrue);
        expect(
          engine.slalomGates.length,
          equals(track.slalomModeGateCount),
        );
        for (int i = 0; i < engine.slalomGates.length; i++) {
          final SkiSlalomGate3D gate = engine.slalomGates[i];
          final bool expectedLeft = i.isEven;
          final double cx = engine.trackCenterOffsetX(gate.z);
          expect(gate.isLeftGate, equals(expectedLeft));
          expect(gate.gateNumber, equals(i + 1));
          if (expectedLeft) {
            expect(
              gate.centerX,
              lessThan(cx - track.trackHalfWidthMeters * 0.40),
              reason: 'Gate #${i + 1} must be offset cleanly on the Left side',
            );
          } else {
            expect(
              gate.centerX,
              greaterThan(cx + track.trackHalfWidthMeters * 0.40),
              reason: 'Gate #${i + 1} must be offset cleanly on the Right side',
            );
          }
        }
      }
    },
  );

  test(
    'v1.5.0 Vivienne Always Above Ramps (Z-Order & Deck Physics), Orange Safety Pads & Full 3D Pine Collisions (Pad/Branch/Treetop), 16-Building Finish Village & 2..5 Chairlifts',
    () {
      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      final Ski3DPainter painter = Ski3DPainter(engine: engine);

      for (final SkiTrackId track in SkiTrackId.values) {
        engine.startRun(
          track: track,
          mode: SkiGameMode.descenteBosses,
        );

        // 1. Chairlift count (`SkiPropKind.cableCarPylon`) strictly bounded between 2 and 5 (`ORB-74` Req #4)
        final List<SkiWorldProp3D> chairlifts = engine.worldProps
            .where((SkiWorldProp3D p) => p.kind == SkiPropKind.cableCarPylon)
            .toList();
        expect(
          chairlifts.length,
          inInclusiveRange(2, 5),
          reason: '$track must have between 2 and 5 chairlifts max',
        );
        expect(chairlifts.length, equals(track.cableCarCount));

        // 2. Expanded Finish Village (`16` buildings, 3 variants, flanking approach + amphitheater behind finish arch) (`ORB-74` Req #3)
        final List<SkiWorldProp3D> villageBuildings = engine.worldProps
            .where(
              (SkiWorldProp3D p) =>
                  p.kind == SkiPropKind.alpineChalet &&
                  p.z >= track.lengthMeters - 90.0,
            )
            .toList();
        expect(
          villageBuildings.length,
          greaterThanOrEqualTo(14),
          reason: '$track arrival village must feature >= 14 Alpine buildings',
        );
        final Set<int> archVariants =
            villageBuildings.map((SkiWorldProp3D p) => p.variant % 3).toSet();
        expect(archVariants, containsAll(<int>[0, 1, 2]));
        expect(
          villageBuildings.any((SkiWorldProp3D p) => p.z < track.lengthMeters),
          isTrue,
          reason: 'Village must flank the final approach before Finish Arch',
        );
        expect(
          villageBuildings.any((SkiWorldProp3D p) => p.z > track.lengthMeters),
          isTrue,
          reason: 'Village must form a resort backdrop behind Finish Arch',
        );

        // 3. Vivienne ALWAYS rendered above ALL ramps + continuous ramp deck elevation (`ORB-74` Req #1)
        for (final SkiJumpRamp3D ramp in engine.jumpRamps) {
          final double zStart = ramp.z - ramp.length * 0.5;
          final double zEnd = ramp.z + ramp.length * 0.5;
          for (final double sampleZ in <double>[
            zStart - 1.2,
            zStart + 0.4,
            ramp.z,
            zEnd - 0.3,
            zEnd + 1.4,
          ]) {
            engine.playerZ = sampleZ;
            engine.playerLateralOffset =
                ramp.x - engine.trackCenterOffsetX(sampleZ);
            engine.playerY = engine.groundSurfaceHeightAt(ramp.x, sampleZ);
            expect(
              painter.debugIsVivienneRenderedAboveAllRamps(),
              isTrue,
              reason:
                  'Vivienne must NEVER be painted underneath ramp #${ramp.id} at z=$sampleZ on $track',
            );
          }

          // Simulate riding right up the ramp deck from entrance to launch lip
          engine.playerZ = zStart + 0.05;
          engine.playerLateralOffset =
              ramp.x - engine.trackCenterOffsetX(engine.playerZ);
          engine.playerY = 0.0;
          engine.playerVy = 0.0;
          for (int tick = 0; tick < 18 && engine.playerZ <= zEnd; tick++) {
            engine.update(1 / 60);
            if (engine.playerZ >= zStart && engine.playerZ <= zEnd) {
              final double deckY = engine.rampDeckElevationAt(
                engine.playerWorldX,
                engine.playerZ,
              );
              expect(
                engine.playerY,
                greaterThanOrEqualTo(deckY - 1e-6),
                reason:
                    'Vivienne playerY must stay >= ramp deckY while climbing ramp #${ramp.id}',
              );
              expect(
                engine.playerGroundY,
                greaterThanOrEqualTo(deckY - 1e-6),
              );
              expect(painter.debugIsVivienneRenderedAboveAllRamps(), isTrue);
            }
          }
        }

        // 4. On-Piste Pine Trees with Orange Safety Pads & Full 3D Collisions (`ORB-74` Req #2):
        //    Verify crashes on (A) Orange Pad, (B) Foliage Branches, and (C) Treetop in Midair!
        final List<SkiWorldProp3D> onPistePines = engine.worldProps
            .where(
              (SkiWorldProp3D p) =>
                  (p.kind == SkiPropKind.alpinePineTree ||
                      p.kind == SkiPropKind.giantSnowPine) &&
                  p.isOnPiste,
            )
            .toList();
        expect(
          onPistePines.length,
          greaterThanOrEqualTo(6),
          reason: '$track must place on-piste pine trees with orange safety pads',
        );

        final SkiWorldProp3D testPine = onPistePines.first;
        final double treeFullH =
            (testPine.kind == SkiPropKind.giantSnowPine ? 7.4 : 5.8) *
                testPine.scale;

        // Case A: Hitting the Orange Safety Mattress in front of the pine tree (`z < tree.z`)
        engine.startRun(track: track);
        engine.playerZ = testPine.z - 1.15 * testPine.scale;
        engine.playerLateralOffset =
            testPine.x - engine.trackCenterOffsetX(engine.playerZ);
        engine.playerY = 0.15;
        engine.playerVy = 0.0;
        for (int step = 0; step < 6 && !engine.isInSnowballCrash; step++) {
          engine.playerLateralOffset =
              testPine.x - engine.trackCenterOffsetX(engine.playerZ);
          engine.update(1 / 60);
        }
        expect(
          engine.isInSnowballCrash,
          isTrue,
          reason: 'Touching the orange safety pad on $track must trigger crash',
        );
        expect(
          engine.lastPineCollisionZone,
          equals(PineCollisionZone.orangePad),
        );

        // Case B: Hitting a mid-height Conical Pine Branch (`0 .. 0.82 * treeFullH`)
        engine.startRun(track: track);
        engine.playerZ = testPine.z - 0.15;
        engine.playerY = treeFullH * 0.48;
        engine.playerVy = 0.0;
        final double branchOffset = 0.62 * testPine.scale;
        engine.playerLateralOffset = (testPine.x + branchOffset) -
            engine.trackCenterOffsetX(engine.playerZ);
        engine.update(1 / 60);
        expect(
          engine.isInSnowballCrash,
          isTrue,
          reason: 'Touching a conical pine branch on $track must trigger crash',
        );
        expect(engine.lastPineCollisionZone, equals(PineCollisionZone.branch));

        // Case C: Hitting the Treetop / Crown high in midair (`> 0.82 * treeFullH`, well above old 1.55m limit!)
        engine.startRun(track: track);
        engine.playerZ = testPine.z - 0.15;
        engine.playerY = treeFullH * 0.90;
        expect(engine.playerY, greaterThan(2.5));
        engine.playerVy = 0.0;
        engine.playerLateralOffset =
            (testPine.x + 0.12 * testPine.scale) -
                engine.trackCenterOffsetX(engine.playerZ);
        engine.update(1 / 60);
        expect(
          engine.isInSnowballCrash,
          isTrue,
          reason:
              'Touching the top/crown of a pine tree in midair on $track must trigger crash',
        );
        expect(engine.lastPineCollisionZone, equals(PineCollisionZone.treetop));
      }
    },
  );

  test(
    'v1.5.1 Zero Speed-Bump Micro-Moguls (_paintMogul3D Removed) & Exclusive Wide C2 Mesh-Integrated Alpine Bosses (8/12/16)',
    () {
      expect(SkiTrackId.greenBlossomValley.mogulCount, equals(8));
      expect(SkiTrackId.blueAsnieresForest.mogulCount, equals(12));
      expect(SkiTrackId.blackVendomePeaks.mogulCount, equals(16));

      final SkiGameEngine engine = SkiGameEngine(seed: 2026);
      final Ski3DPainter painter = Ski3DPainter(engine: engine);

      for (final SkiGameMode mode in SkiGameMode.values) {
        for (final SkiTrackId track in SkiTrackId.values) {
          engine.startRun(track: track, mode: mode);
          expect(engine.moguls.length, equals(track.mogulCount));

          // 1. Verify NO short micro-moguls exist (`radiusX >= 6.8` & `radiusZ >= 13.5`,
          //    specifically `7.2..10.5 m` wide and `14.0..20.0 m` long) and zero overlap with jump ramps!
          for (final SkiMogul3D m in engine.moguls) {
            expect(
              m.radiusX,
              greaterThanOrEqualTo(6.8),
              reason:
                  'Mogul #${m.id} on $track ($mode) must not be a narrow micro-bump',
            );
            expect(m.radiusX, inInclusiveRange(7.2, 10.5));
            expect(
              m.radiusZ,
              greaterThanOrEqualTo(13.5),
              reason:
                  'Mogul #${m.id} on $track ($mode) must span multiple longitudinal mesh slices (no dos-d\'ane!)',
            );
            expect(m.radiusZ, inInclusiveRange(14.0, 20.0));
            expect(m.heightMeters, inInclusiveRange(0.95, 1.45));

            // C² (`cos⁴`) feathering check: zero at outer rim, gentle near rim (`r = 0.92`), full at crown
            expect(
              engine.mogulElevationAt(m.x, m.z + m.radiusZ),
              closeTo(0.0, 1e-12),
            );
            expect(
              engine.mogulElevationAt(m.x, m.z + m.radiusZ * 0.92),
              lessThan(0.01),
            );
            expect(
              engine.mogulElevationAt(m.x, m.z),
              closeTo(m.heightMeters, 1e-6),
            );

            for (final SkiJumpRamp3D r in engine.jumpRamps) {
              expect(
                (m.z - r.z).abs(),
                greaterThanOrEqualTo(r.length * 0.5 + m.radiusZ),
                reason:
                    'Wide mogul #${m.id} must stay cleanly separated from jump ramp #${r.id} on $track',
              );
            }
          }

          // 2. Verify `Ski3DPainter` NEVER emits any separate `_paintMogul3D` / `mogul` overlay item
          //    at ANY camera position along the entire track!
          for (double z = 0.0; z <= track.lengthMeters; z += 95.0) {
            engine.playerZ = z;
            expect(
              painter.debugHasZeroMogulOverlayItems(),
              isTrue,
              reason:
                  'Ski3DPainter must never emit a separate mogul overlay item at z=$z on $track',
            );
            expect(
              painter.debugActiveRenderItemKinds(),
              isNot(contains('mogul')),
            );
          }
        }
      }
    },
  );

  testWidgets(
    'v1.5.1 Zero Speed-Bump Micro-Moguls, Wide Integrated Bosses, Vivienne Above Ramps & 6 Store Screenshots (1080x2400)',
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

      // Verify compact viewport (`360x740dp`) produces zero overflow on Menu with Mode Selector
      await tester.binding.setSurfaceSize(const Size(360, 740));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pump(const Duration(milliseconds: 80));

      // Verify Mode Selector toggles between `DESCENTE & BOSSES` and `SLALOM COMPLET`
      expect(find.byKey(const Key('main_menu_overlay')), findsOneWidget);
      expect(find.byKey(const Key('select_mode_descente')), findsOneWidget);
      expect(find.byKey(const Key('select_mode_slalom')), findsOneWidget);

      await tester.tap(find.byKey(const Key('select_mode_slalom')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedGameMode, equals(SkiGameMode.slalomComplet));

      await tester.tap(find.byKey(const Key('select_mode_descente')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.selectedGameMode, equals(SkiGameMode.descenteBosses));

      // 1. Screenshot 01: Title, Mode Selector (`DESCENTE & BOSSES` / `SLALOM COMPLET`) & 3 Viviennes
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

      // 2. Screenshot 02: Expanded 16-Building Alpine Finish Village + On-Piste Pine Orange Safety Pad + Seamless 3D Moguls + Parallel Carving!
      engine.selectEdition(VivienneSkiEdition.speedyV03);
      engine.startRun(
        track: SkiTrackId.greenBlossomValley,
        mode: SkiGameMode.descenteBosses,
      );
      engine.playerZ = 1142.0;
      engine.playerLateralOffset = 1.6;
      engine.setManualTilt(0.66);
      for (int i = 0; i < 12; i++) {
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

      // 3. Screenshot 03: Full Slalom Mode (`SkiGameMode.slalomComplet`) with Orange-Padded Piste Pines & Seamless Moguls!
      engine.selectEdition(VivienneSkiEdition.wonderland);
      engine.startRun(
        track: SkiTrackId.greenBlossomValley,
        mode: SkiGameMode.slalomComplet,
      );
      final SkiSlalomGate3D gate1 = engine.slalomGates.first;
      engine.playerZ = gate1.z - 1.5;
      engine.playerLateralOffset =
          gate1.centerX - engine.trackCenterOffsetX(gate1.z);
      for (int i = 0; i < 6; i++) {
        engine.update(1 / 60);
      }
      expect(engine.slalomPassed, greaterThanOrEqualTo(1));
      engine.playerZ = 62.0;
      engine.playerLateralOffset = -2.2;
      engine.setManualTilt(0.68);
      for (int i = 0; i < 10; i++) {
        engine.update(1 / 60);
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('hud_slalom_counter_badge')), findsOneWidget);
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/03_slalom_gates_and_hud.png',
      );
      engine.clearManualTilt();

      // 4. Screenshot 04: Vivienne Rendered ON TOP OF Ramp #0 (`small` sculpted snow kicker) + `medium` & `large` Ramps + Orange Pine Pads + Single Distant Chairlift!
      engine.selectEdition(VivienneSkiEdition.giantDenim);
      engine.startRun(
        track: SkiTrackId.blueAsnieresForest,
        mode: SkiGameMode.descenteBosses,
      );
      final SkiJumpRamp3D targetRamp = engine.jumpRamps.first;
      engine.playerZ = targetRamp.z - 1.2;
      engine.playerLateralOffset =
          targetRamp.x - engine.trackCenterOffsetX(engine.playerZ);
      for (int i = 0; i < 3; i++) {
        engine.update(1 / 60);
      }
      engine.triggerBonusJumpForTest(
        trick: SkiAerialTrickKind.saut360,
        progress: 0.28,
        apexHeightMeters: 2.25,
      );
      expect(
        Ski3DPainter(engine: engine).debugIsVivienneRenderedAboveAllRamps(),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('SAUT 360° +250'), findsOneWidget);
      await _capturePortraitScreenshot(
        tester,
        screenshotKey,
        'screenshots/04_jump_ramp_squash_stretch.png',
      );

      // 5. Screenshot 05: Pause Menu Overlay (`pause_modal_overlay`) with 3/4-Profile 3D Inspection & Slalom Stats
      engine.selectEdition(VivienneSkiEdition.speedyV03);
      engine.startRun(
        track: SkiTrackId.blueAsnieresForest,
        mode: SkiGameMode.slalomComplet,
      );
      engine.slalomPassed = 6;
      engine.slalomCombo = 5;
      engine.slalomPoints = 2250;
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
      engine.blossomsCollected = 28;
      engine.blossomPoints = 1400;
      engine.slalomPassed = 34;
      engine.slalomPoints = 8640;
      engine.jumpsCompleted = 5;
      engine.mogulsAbsorbed = 9;
      engine.jumpAndMogulPoints = 2180;
      engine.elapsedSeconds = 58.4;
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
