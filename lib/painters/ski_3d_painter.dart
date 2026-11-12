import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/ski_game_engine.dart';
import '../models/ski_models.dart';

enum _DepthActorKind {
  worldProp,
  mogul,
  jumpRamp,
  slalomGate,
  blossom,
  viviennePlayer,
  snowParticle,
}

class _DepthRenderItem {
  const _DepthRenderItem({
    required this.zWorld,
    required this.kind,
    this.index = 0,
  });

  final double zWorld;
  final _DepthActorKind kind;
  final int index;
}

class _ProjectedPoint3D {
  const _ProjectedPoint3D({
    required this.x,
    required this.y,
    required this.scale,
    required this.zRel,
  });

  final double x;
  final double y;
  final double scale;
  final double zRel;
}

/// High-Precision 60–120 FPS 3rd-Person Rear Perspective 3D Renderer (`Camera3D`)
/// for `VIVI AU SKI : Descente Royale 3D` (`v1.0.0`).
class Ski3DPainter extends CustomPainter {
  Ski3DPainter({
    required this.engine,
    this.turntableSprites = const <ui.Image?>[],
    this.poseSprites = const <VivienneBlenderPose, ui.Image>{},
  }) : super(repaint: engine);

  final SkiGameEngine engine;
  final List<ui.Image?> turntableSprites;
  final Map<VivienneBlenderPose, ui.Image> poseSprites;

  static const Color _kOutline = Color(0xFF2B1105);
  static const double _kZNear = 6.2;
  static const double _kZFar = 220.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final SkiTrackId track = engine.selectedTrack;
    final double speedNorm =
        ((engine.speedKmh - track.baseSpeedKmh) /
                math.max(1.0, track.maxSpeedKmh - track.baseSpeedKmh))
            .clamp(0.0, 1.2);

    // Camera3D Parameters (3rd-person rear perspective behind Vivienne)
    final double camDistBack =
        11.8 + speedNorm * 1.4 + (engine.playerY * 0.18).clamp(0.0, 1.6);
    final double camZ = engine.playerZ - camDistBack;
    final double camWorldX = engine.trackCenterOffsetX(engine.playerZ) +
        engine.playerLateralOffset * 0.70;
    final double camHeight = 14.6 + (engine.playerY * 0.30).clamp(0.0, 2.8);
    final double focal = size.width * 0.90;
    final double horizonY =
        size.height * (0.275 - speedNorm * 0.015 + engine.playerY * 0.004)
            .clamp(0.22, 0.33);
    final double playerReliefRef = engine.relativeReliefAtZ(engine.playerZ);

    // Subtle camera roll synchronized with carving lean
    final double camRoll = -engine.playerRollRadians * 0.15;

    _ProjectedPoint3D project(double worldX, double yAboveSnow, double worldZ) {
      final double zRel = math.max(_kZNear * 0.65, worldZ - camZ);
      final double s = focal / zRel;
      final double reliefDelta =
          engine.relativeReliefAtZ(worldZ) - playerReliefRef;
      final double sx = size.width * 0.5 + (worldX - camWorldX) * s;
      final double sy =
          horizonY + (camHeight - yAboveSnow - reliefDelta) * s;
      return _ProjectedPoint3D(x: sx, y: sy, scale: s, zRel: zRel);
    }

    // Apply subtle camera roll around screen center
    canvas.save();
    if (camRoll.abs() > 0.001) {
      canvas.translate(size.width * 0.5, horizonY);
      canvas.rotate(camRoll);
      canvas.translate(-size.width * 0.5, -horizonY);
    }

    // 1. Sky Dome, Sun / Aurora Borealis & Parallax 3D Alpine Peaks
    _paintAlpineSkyAndMountains(canvas, size, track, horizonY, camWorldX);

    // 2. Trapezoidal 3D Snow Slope Mesh (zFar -> zNear) & Dual Persistent Ski Marks
    _paintSnowSlopeMesh3D(canvas, size, track, camZ, horizonY, project);
    _paintPersistentSkiTracks3D(canvas, track, camZ, project);

    // 3. Strict Painter's Algorithm Z-Sort (zFar -> zNear) of all 3D World Entities
    final List<_DepthRenderItem> items = <_DepthRenderItem>[];
    final double zMinVisible = camZ + _kZNear * 0.85;
    final double zMaxVisible = camZ + _kZFar;

    for (int i = 0; i < engine.worldProps.length; i++) {
      final double z = engine.worldProps[i].z;
      if (z >= zMinVisible && z <= zMaxVisible) {
        items.add(
          _DepthRenderItem(
            zWorld: z,
            kind: _DepthActorKind.worldProp,
            index: i,
          ),
        );
      }
    }

    for (int i = 0; i < engine.moguls.length; i++) {
      final double z = engine.moguls[i].z;
      if (z >= zMinVisible && z <= zMaxVisible) {
        items.add(
          _DepthRenderItem(zWorld: z, kind: _DepthActorKind.mogul, index: i),
        );
      }
    }

    for (int i = 0; i < engine.jumpRamps.length; i++) {
      final double z = engine.jumpRamps[i].z;
      if (z >= zMinVisible && z <= zMaxVisible) {
        items.add(
          _DepthRenderItem(
            zWorld: z,
            kind: _DepthActorKind.jumpRamp,
            index: i,
          ),
        );
      }
    }

    for (int i = 0; i < engine.slalomGates.length; i++) {
      final double z = engine.slalomGates[i].z;
      if (z >= zMinVisible && z <= zMaxVisible) {
        items.add(
          _DepthRenderItem(
            zWorld: z,
            kind: _DepthActorKind.slalomGate,
            index: i,
          ),
        );
      }
    }

    for (int i = 0; i < engine.blossoms.length; i++) {
      final SkiBlossomCollectible3D b = engine.blossoms[i];
      if (!b.collected && b.z >= zMinVisible && b.z <= zMaxVisible) {
        items.add(
          _DepthRenderItem(zWorld: b.z, kind: _DepthActorKind.blossom, index: i),
        );
      }
    }

    for (int i = 0; i < engine.snowParticles.length; i++) {
      final SkiSnowParticle3D p = engine.snowParticles[i];
      if (p.z >= zMinVisible && p.z <= zMaxVisible) {
        items.add(
          _DepthRenderItem(
            zWorld: p.z,
            kind: _DepthActorKind.snowParticle,
            index: i,
          ),
        );
      }
    }

    // Insert Vivienne at her exact 3D depth `playerZ`
    items.add(
      _DepthRenderItem(
        zWorld: engine.playerZ,
        kind: _DepthActorKind.viviennePlayer,
      ),
    );

    items.sort(
      (_DepthRenderItem a, _DepthRenderItem b) =>
          b.zWorld.compareTo(a.zWorld),
    );

    for (final _DepthRenderItem item in items) {
      switch (item.kind) {
        case _DepthActorKind.worldProp:
          _paintWorldProp3D(
            canvas,
            track,
            engine.worldProps[item.index],
            project,
          );
        case _DepthActorKind.mogul:
          _paintMogul3D(canvas, track, engine.moguls[item.index], project);
        case _DepthActorKind.jumpRamp:
          _paintJumpRamp3D(canvas, engine.jumpRamps[item.index], project);
        case _DepthActorKind.slalomGate:
          _paintSlalomGate3D(canvas, engine.slalomGates[item.index], project);
        case _DepthActorKind.blossom:
          _paintBlossom3D(canvas, engine.blossoms[item.index], project);
        case _DepthActorKind.viviennePlayer:
          _paintVivienneSkier3D(canvas, size, track, project);
        case _DepthActorKind.snowParticle:
          _paintSnowParticle3D(canvas, engine.snowParticles[item.index], project);
      }
    }

    canvas.restore(); // End camera roll

    // 4. Screen-space floating score callouts
    _paintFloatingCallouts(canvas, size);

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // 1. Sky Dome, Sun / Aurora Borealis & Parallax Alpine Peaks
  // ---------------------------------------------------------------------------

  void _paintAlpineSkyAndMountains(
    Canvas canvas,
    Size size,
    SkiTrackId track,
    double horizonY,
    double camWorldX,
  ) {
    final Rect skyRect =
        Rect.fromLTRB(-size.width * 0.2, -40, size.width * 1.2, horizonY + 36);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, horizonY + 24),
          <Color>[
            track.skyTopColor,
            track.skyMidColor,
            track.skyHorizonColor,
          ],
          const <double>[0.0, 0.58, 1.0],
        ),
    );

    // Twinkling stars & emerald/gold Aurora Borealis on Black Gold track
    if (track.hasAuroraBorealis) {
      final Paint starPaint = Paint()..color = Colors.white.withValues(alpha: 0.78);
      for (int i = 0; i < 28; i++) {
        final double sx = ((i * 67.0 + 19.0) % size.width);
        final double sy = ((i * 41.0 + 14.0) % (horizonY * 0.78));
        final double twinkle =
            0.9 + 0.5 * math.sin(engine.ambientTime * 3.0 + i);
        canvas.drawCircle(Offset(sx, sy), 1.1 * twinkle, starPaint);
      }

      for (int band = 0; band < 2; band++) {
        final Path aurora = Path();
        final double baseY = horizonY * (0.34 + band * 0.16);
        aurora.moveTo(-20, baseY);
        for (double x = -20; x <= size.width + 40; x += 28) {
          final double wave = math.sin(
                  x * 0.016 + engine.ambientTime * 1.4 + band * 1.8) *
              16.0;
          aurora.lineTo(x, baseY + wave);
        }
        for (double x = size.width + 40; x >= -20; x -= 28) {
          final double wave = math.sin(
                  x * 0.016 + engine.ambientTime * 1.4 + band * 1.8) *
              16.0;
          aurora.lineTo(x, baseY + wave - 34.0);
        }
        aurora.close();
        canvas.drawPath(
          aurora,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, baseY - 40),
              Offset(0, baseY + 20),
              <Color>[
                const Color(0x0064DFDF),
                band == 0
                    ? const Color(0x6664DFDF)
                    : const Color(0x55FFD700),
                const Color(0x0064DFDF),
              ],
              const <double>[0.0, 0.5, 1.0],
            ),
        );
      }
    }

    // Radiant Alpine Sun / Golden Moon
    final Offset sunCenter = Offset(
      size.width * 0.74 - camWorldX * 1.3,
      horizonY * 0.44,
    );
    canvas.drawCircle(
      sunCenter,
      46.0,
      Paint()..color = track.sunOrMoonColor.withValues(alpha: 0.24),
    );
    canvas.drawCircle(
      sunCenter,
      26.0,
      Paint()..color = track.sunOrMoonColor,
    );

    // Far & Near 3D Snow-Capped Mountain Ranges in Parallax
    _paintMountainRange(
      canvas,
      size,
      horizonY: horizonY + 8,
      peakHeight: 82.0,
      parallaxOffset: -camWorldX * 2.4,
      mountainColor: track.mountainFarColor,
      snowCapColor: track.snowBrightColor.withValues(alpha: 0.88),
      seedShift: 1,
    );
    _paintMountainRange(
      canvas,
      size,
      horizonY: horizonY + 14,
      peakHeight: 54.0,
      parallaxOffset: -camWorldX * 4.2,
      mountainColor: track.mountainNearColor,
      snowCapColor: track.snowBrightColor,
      seedShift: 4,
    );
  }

  void _paintMountainRange(
    Canvas canvas,
    Size size, {
    required double horizonY,
    required double peakHeight,
    required double parallaxOffset,
    required Color mountainColor,
    required Color snowCapColor,
    required int seedShift,
  }) {
    final Path range = Path()..moveTo(-80, horizonY + 24);
    const double step = 68.0;
    final List<Offset> peaks = <Offset>[];
    for (double x = -80; x <= size.width + 120; x += step) {
      final int idx = ((x + 200) ~/ step) + seedShift;
      final double h = peakHeight *
          (0.55 + 0.45 * ((math.sin(idx * 2.3) + 1.0) * 0.5));
      final Offset p = Offset(x + (parallaxOffset % step), horizonY - h);
      peaks.add(p);
      range.lineTo(p.dx, p.dy);
      range.lineTo(p.dx + step * 0.5, horizonY - h * 0.36);
    }
    range
      ..lineTo(size.width + 140, horizonY + 24)
      ..close();
    canvas.drawPath(range, Paint()..color = mountainColor);

    // Crisp Cartoon Snow Caps on mountain peaks
    final Paint capPaint = Paint()..color = snowCapColor;
    for (final Offset pk in peaks) {
      final Path cap = Path()
        ..moveTo(pk.dx, pk.dy)
        ..lineTo(pk.dx - 16, pk.dy + 22)
        ..lineTo(pk.dx - 5, pk.dy + 17)
        ..lineTo(pk.dx + 4, pk.dy + 24)
        ..lineTo(pk.dx + 18, pk.dy + 20)
        ..close();
      canvas.drawPath(cap, capPaint);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Trapezoidal 3D Snow Slope Mesh & Persistent Dual Ski Marks
  // ---------------------------------------------------------------------------

  void _paintSnowSlopeMesh3D(
    Canvas canvas,
    Size size,
    SkiTrackId track,
    double camZ,
    double horizonY,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    // Base snow fill below horizon
    canvas.drawRect(
      Rect.fromLTRB(
        -size.width * 0.25,
        horizonY,
        size.width * 1.25,
        size.height + 60,
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonY),
          Offset(0, size.height),
          <Color>[track.snowShadowColor, track.snowMidColor, track.snowBrightColor],
          const <double>[0.0, 0.35, 1.0],
        ),
    );

    // Render 54 perspective trapezoidal snow bands from zFar -> zNear
    const int sliceCount = 54;
    final double halfW = track.trackHalfWidthMeters;

    double prevZ = camZ + _kZFar;
    double prevCx = engine.trackCenterOffsetX(prevZ);
    _ProjectedPoint3D prevLeft = project(prevCx - halfW, 0.0, prevZ);
    _ProjectedPoint3D prevRight = project(prevCx + halfW, 0.0, prevZ);
    _ProjectedPoint3D prevOuterL = project(prevCx - halfW * 3.2, 0.5, prevZ);
    _ProjectedPoint3D prevOuterR = project(prevCx + halfW * 3.2, 0.5, prevZ);

    for (int s = 1; s <= sliceCount; s++) {
      // Non-linear depth distribution giving ultra-smooth detail close to Vivienne
      final double t = s / sliceCount;
      final double zRel = _kZFar * math.pow(_kZNear / _kZFar, t);
      final double currZ = camZ + zRel;
      final double currCx = engine.trackCenterOffsetX(currZ);

      final _ProjectedPoint3D currLeft = project(currCx - halfW, 0.0, currZ);
      final _ProjectedPoint3D currRight = project(currCx + halfW, 0.0, currZ);
      final _ProjectedPoint3D currOuterL =
          project(currCx - halfW * 3.2, 0.5, currZ);
      final _ProjectedPoint3D currOuterR =
          project(currCx + halfW * 3.2, 0.5, currZ);

      final int worldBand = (currZ / 7.5).floor();
      final bool altBand = worldBand.isEven;

      // Off-piste powder banks (Left & Right shoulders with alpine blue shadows)
      final Color powderColor = altBand
          ? Color.lerp(track.snowMidColor, track.snowShadowColor, 0.38)!
          : Color.lerp(track.snowMidColor, track.snowShadowColor, 0.52)!;
      final Path leftBank = Path()
        ..moveTo(prevOuterL.x, prevOuterL.y)
        ..lineTo(prevLeft.x, prevLeft.y)
        ..lineTo(currLeft.x, currLeft.y)
        ..lineTo(currOuterL.x, currOuterL.y)
        ..close();
      canvas.drawPath(leftBank, Paint()..color = powderColor);

      final Path rightBank = Path()
        ..moveTo(prevRight.x, prevRight.y)
        ..lineTo(prevOuterR.x, prevOuterR.y)
        ..lineTo(currOuterR.x, currOuterR.y)
        ..lineTo(currRight.x, currRight.y)
        ..close();
      canvas.drawPath(rightBank, Paint()..color = powderColor);

      // Groomed corduroy ski piste corridor
      final Color pisteColor = altBand
          ? track.snowBrightColor
          : Color.lerp(track.snowBrightColor, track.snowShadowColor, 0.16)!;
      final Path pisteQuad = Path()
        ..moveTo(prevLeft.x, prevLeft.y)
        ..lineTo(prevRight.x, prevRight.y)
        ..lineTo(currRight.x, currRight.y)
        ..lineTo(currLeft.x, currLeft.y)
        ..close();
      canvas.drawPath(pisteQuad, Paint()..color = pisteColor);

      // Crisp piste border snow-cushion lines
      final Paint edgePaint = Paint()
        ..color = altBand
            ? track.badgeColor.withValues(alpha: 0.55)
            : track.snowShadowColor.withValues(alpha: 0.75)
        ..strokeWidth = math.max(1.2, currLeft.scale * 0.14)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(prevLeft.x, prevLeft.y),
        Offset(currLeft.x, currLeft.y),
        edgePaint,
      );
      canvas.drawLine(
        Offset(prevRight.x, prevRight.y),
        Offset(currRight.x, currRight.y),
        edgePaint,
      );

      prevZ = currZ;
      prevLeft = currLeft;
      prevRight = currRight;
      prevOuterL = currOuterL;
      prevOuterR = currOuterR;
    }
  }

  void _paintPersistentSkiTracks3D(
    Canvas canvas,
    SkiTrackId track,
    double camZ,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final List<SkiTrackRibbonPoint> trail = engine.skiTrailHistory;
    if (trail.length < 2) return;

    for (int i = 1; i < trail.length; i++) {
      final SkiTrackRibbonPoint p0 = trail[i - 1];
      final SkiTrackRibbonPoint p1 = trail[i];
      if (!p0.hasSkiMarks || !p1.hasSkiMarks) continue;
      if (p1.z <= camZ + _kZNear * 0.72) continue;

      final _ProjectedPoint3D l0 = project(p0.leftSkiX, 0.02, p0.z);
      final _ProjectedPoint3D l1 = project(p1.leftSkiX, 0.02, p1.z);
      final _ProjectedPoint3D r0 = project(p0.rightSkiX, 0.02, p0.z);
      final _ProjectedPoint3D r1 = project(p1.rightSkiX, 0.02, p1.z);

      final double alpha = (0.28 + p1.carveIntensity * 0.36).clamp(0.22, 0.65);
      final Paint groovePaint = Paint()
        ..color = track.snowShadowColor.withValues(alpha: alpha)
        ..strokeWidth = math.max(1.4, l1.scale * 0.12)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(l0.x, l0.y), Offset(l1.x, l1.y), groovePaint);
      canvas.drawLine(Offset(r0.x, r0.y), Offset(r1.x, r1.y), groovePaint);
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Depth-Sorted 3D Scenery & Gameplay Entities
  // ---------------------------------------------------------------------------

  void _paintWorldProp3D(
    Canvas canvas,
    SkiTrackId track,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    switch (prop.kind) {
      case SkiPropKind.alpinePineTree:
      case SkiPropKind.giantSnowPine:
        _paintSnowPineTree3D(
          canvas,
          track,
          prop,
          project,
          tiers: prop.kind == SkiPropKind.giantSnowPine ? 4 : 3,
        );
      case SkiPropKind.crystalIceRock:
        _paintCrystalIceRock3D(canvas, prop, project);
      case SkiPropKind.alpineChalet:
        _paintAlpineChalet3D(canvas, prop, project);
      case SkiPropKind.lvBannerPost:
        break;
      case SkiPropKind.startArch:
        _paintArch3D(canvas, prop, project, isFinish: false);
      case SkiPropKind.finishArch:
        _paintArch3D(canvas, prop, project, isFinish: true);
    }
  }

  void _paintSnowPineTree3D(
    Canvas canvas,
    SkiTrackId track,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project, {
    required int tiers,
  }) {
    final _ProjectedPoint3D base = project(prop.x, 0.0, prop.z);
    final double s = base.scale * prop.scale;
    if (s < 0.8) return;

    final double treeW = 3.2 * s;
    final double treeH = (tiers == 4 ? 7.4 : 5.8) * s;
    final double strokeW = (s * 0.11).clamp(1.0, 2.8);

    // Elliptical alpine shadow on snow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.x + treeW * 0.08, base.y + s * 0.08),
        width: treeW * 0.95,
        height: treeW * 0.26,
      ),
      Paint()..color = const Color(0xFF1A3B5C).withValues(alpha: 0.24),
    );

    // Warm wood trunk (#5D4037)
    final Rect trunkRect = Rect.fromCenter(
      center: Offset(base.x, base.y - treeH * 0.10),
      width: treeW * 0.22,
      height: treeH * 0.24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trunkRect, Radius.circular(s * 0.12)),
      Paint()..color = const Color(0xFF5D4037),
    );

    final Paint outlinePaint = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeJoin = StrokeJoin.round;

    // 3 to 4 Conical Foliage Tiers with Thick Festooned Snow Caps
    for (int t = 0; t < tiers; t++) {
      final double frac = t / tiers;
      final double bottomY = base.y - treeH * (0.18 + frac * 0.62);
      final double topY = base.y - treeH * (0.48 + frac * 0.54);
      final double tierHalfW = treeW * (0.54 - frac * 0.11);

      final Path cone = Path()
        ..moveTo(base.x, topY)
        ..lineTo(base.x + tierHalfW, bottomY)
        ..quadraticBezierTo(
          base.x,
          bottomY + (bottomY - topY) * 0.16,
          base.x - tierHalfW,
          bottomY,
        )
        ..close();

      canvas.drawPath(
        cone,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(base.x - tierHalfW, topY),
            Offset(base.x + tierHalfW, bottomY),
            <Color>[track.pineLightColor, track.pineDarkColor],
          ),
      );
      canvas.drawPath(cone, outlinePaint);

      // Thick Cartoon Snow Blanket on each pine tier
      final double snowBottomY = topY + (bottomY - topY) * 0.50;
      final double snowHalfW = tierHalfW * 0.54;
      final Path snowCap = Path()
        ..moveTo(base.x, topY)
        ..lineTo(base.x + snowHalfW, snowBottomY)
        ..quadraticBezierTo(
          base.x + snowHalfW * 0.35,
          snowBottomY + s * 0.18,
          base.x,
          snowBottomY - s * 0.06,
        )
        ..quadraticBezierTo(
          base.x - snowHalfW * 0.35,
          snowBottomY + s * 0.18,
          base.x - snowHalfW,
          snowBottomY,
        )
        ..close();
      canvas.drawPath(snowCap, Paint()..color = track.pineSnowColor);
    }
  }

  void _paintCrystalIceRock3D(
    Canvas canvas,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final _ProjectedPoint3D base = project(prop.x, 0.0, prop.z);
    final double s = base.scale * prop.scale;
    if (s < 1.0) return;

    final Path crystal = Path()
      ..moveTo(base.x, base.y - s * 3.8)
      ..lineTo(base.x + s * 1.4, base.y - s * 1.2)
      ..lineTo(base.x + s * 1.0, base.y)
      ..lineTo(base.x - s * 1.1, base.y)
      ..lineTo(base.x - s * 1.5, base.y - s * 1.6)
      ..close();
    canvas.drawPath(
      crystal,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(base.x - s, base.y - s * 3.8),
          Offset(base.x + s, base.y),
          const <Color>[Color(0xFFE0F7FA), Color(0xFF26C6DA), Color(0xFF006064)],
          const <double>[0.0, 0.5, 1.0],
        ),
    );
    canvas.drawPath(
      crystal,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.10).clamp(1.0, 2.4),
    );
  }

  void _paintMogul3D(
    Canvas canvas,
    SkiTrackId track,
    SkiMogul3D mogul,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final _ProjectedPoint3D c = project(mogul.x, 0.0, mogul.z);
    final double s = c.scale;
    if (s < 1.2) return;

    final double w = mogul.radiusX * 2.0 * s;
    final double h = mogul.heightMeters * 1.85 * s;

    // Downhill soft blue shadow crescent
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.x, c.y + h * 0.14),
        width: w * 1.04,
        height: h * 0.65,
      ),
      Paint()..color = track.snowShadowColor.withValues(alpha: 0.72),
    );

    // Sculpted 3D snow dome
    final Path dome = Path()
      ..moveTo(c.x - w * 0.5, c.y + h * 0.10)
      ..cubicTo(
        c.x - w * 0.38,
        c.y - h * 0.95,
        c.x + w * 0.38,
        c.y - h * 0.95,
        c.x + w * 0.5,
        c.y + h * 0.10,
      )
      ..quadraticBezierTo(c.x, c.y + h * 0.34, c.x - w * 0.5, c.y + h * 0.10)
      ..close();

    canvas.drawPath(
      dome,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.x, c.y - h),
          Offset(c.x, c.y + h * 0.3),
          <Color>[Colors.white, track.snowMidColor, track.snowShadowColor],
          const <double>[0.0, 0.65, 1.0],
        ),
    );
    canvas.drawPath(
      dome,
      Paint()
        ..color = const Color(0xFF546E7A).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.08).clamp(1.0, 2.2),
    );

    // Specular snow crest highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.x - w * 0.08, c.y - h * 0.42),
        width: w * 0.44,
        height: h * 0.22,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
  }

  void _paintJumpRamp3D(
    Canvas canvas,
    SkiJumpRamp3D ramp,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final double camZApprox = engine.playerZ - 11.8;
    final double zFarRamp = ramp.z + ramp.length * 0.5;
    if (zFarRamp <= camZApprox + _kZNear + 0.5) return;

    final double rawZNearRamp = ramp.z - ramp.length * 0.5;
    final double zNearRamp = math.max(rawZNearRamp, camZApprox + _kZNear + 0.2);
    final double nearClipFrac =
        ((zNearRamp - rawZNearRamp) / ramp.length).clamp(0.0, 0.95);
    final double nearClippedY = 0.05 + ramp.heightMeters * nearClipFrac;

    final double halfW = ramp.width * 0.5;
    final _ProjectedPoint3D nL =
        project(ramp.x - halfW, nearClippedY, zNearRamp);
    final _ProjectedPoint3D nR =
        project(ramp.x + halfW, nearClippedY, zNearRamp);
    final _ProjectedPoint3D fLTop =
        project(ramp.x - halfW, ramp.heightMeters, zFarRamp);
    final _ProjectedPoint3D fRTop =
        project(ramp.x + halfW, ramp.heightMeters, zFarRamp);
    final _ProjectedPoint3D fLBase = project(ramp.x - halfW, 0.0, zFarRamp);
    final _ProjectedPoint3D fRBase = project(ramp.x + halfW, 0.0, zFarRamp);

    if (fLTop.scale < 0.9) return;

    // LV Monogram Trunk front/side wall under the elevated lip
    final Path frontWall = Path()
      ..moveTo(fLTop.x, fLTop.y)
      ..lineTo(fRTop.x, fRTop.y)
      ..lineTo(fRBase.x, fRBase.y)
      ..lineTo(fLBase.x, fLBase.y)
      ..close();
    canvas.drawPath(frontWall, Paint()..color = const Color(0xFF3A2618));

    // Inclined snow & crimson-trimmed launch deck
    final Path deck = Path()
      ..moveTo(nL.x, nL.y)
      ..lineTo(nR.x, nR.y)
      ..lineTo(fRTop.x, fRTop.y)
      ..lineTo(fLTop.x, fLTop.y)
      ..close();
    canvas.drawPath(
      deck,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(nL.x, nL.y),
          Offset(fLTop.x, fLTop.y),
          const <Color>[Color(0xFFFFFFFF), Color(0xFFFFF3E0), Color(0xFFFFD54F)],
          const <double>[0.0, 0.72, 1.0],
        ),
    );
    canvas.drawPath(
      deck,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (nL.scale * 0.11).clamp(1.2, 2.8),
    );

    // Crimson & 24K Gold launch lip bar
    canvas.drawLine(
      Offset(fLTop.x, fLTop.y),
      Offset(fRTop.x, fRTop.y),
      Paint()
        ..color = const Color(0xFF8B1E24)
        ..strokeWidth = (fLTop.scale * 0.28).clamp(2.0, 6.5)
        ..strokeCap = StrokeCap.round,
    );

    // Animated golden boost chevrons along the ramp deck
    final double pulse = (engine.ambientTime * 3.2) % 1.0;
    for (int c = 0; c < 3; c++) {
      final double u = ((c / 3.0) + pulse * 0.33) % 1.0;
      final double cz = zNearRamp + (zFarRamp - zNearRamp) * u;
      final double cy = ramp.heightMeters * u + 0.06;
      final _ProjectedPoint3D mid = project(ramp.x, cy + 0.14, cz + 0.7);
      final _ProjectedPoint3D leftWing =
          project(ramp.x - halfW * 0.55, cy, cz);
      final _ProjectedPoint3D rightWing =
          project(ramp.x + halfW * 0.55, cy, cz);
      final Path chev = Path()
        ..moveTo(leftWing.x, leftWing.y)
        ..lineTo(mid.x, mid.y)
        ..lineTo(rightWing.x, rightWing.y);
      canvas.drawPath(
        chev,
        Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (mid.scale * 0.18).clamp(1.5, 4.2)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintSlalomGate3D(
    Canvas canvas,
    SkiSlalomGate3D gate,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final double lx = gate.centerX - gate.halfWidth;
    final double rx = gate.centerX + gate.halfWidth;
    final _ProjectedPoint3D lBase = project(lx, 0.0, gate.z);
    final _ProjectedPoint3D lTop = project(lx, 2.35, gate.z);
    final _ProjectedPoint3D rBase = project(rx, 0.0, gate.z);
    final _ProjectedPoint3D rTop = project(rx, 2.35, gate.z);

    if (lBase.scale < 1.0) return;

    final Color poleColor = gate.passed
        ? const Color(0xFF00E676)
        : (gate.isGoldRed ? const Color(0xFF8B1E24) : const Color(0xFF1565C0));
    final Color flagColor = gate.passed
        ? const Color(0xFF69F0AE)
        : (gate.isGoldRed ? const Color(0xFFFFD700) : const Color(0xFF29B6F6));

    final double pw = (lBase.scale * 0.14).clamp(1.6, 4.5);
    final Paint polePaint = Paint()
      ..color = poleColor
      ..strokeWidth = pw
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(lBase.x, lBase.y), Offset(lTop.x, lTop.y), polePaint);
    canvas.drawLine(Offset(rBase.x, rBase.y), Offset(rTop.x, rTop.y), polePaint);

    // Pennant flags on both poles
    for (final (_ProjectedPoint3D top, double dir) in <(_ProjectedPoint3D, double)>[
      (lTop, 1.0),
      (rTop, -1.0),
    ]) {
      final Rect flagRect = Rect.fromLTWH(
        dir > 0 ? top.x : top.x - top.scale * 0.85,
        top.y + top.scale * 0.12,
        top.scale * 0.85,
        top.scale * 0.56,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(flagRect, Radius.circular(top.scale * 0.08)),
        Paint()..color = flagColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(flagRect, Radius.circular(top.scale * 0.08)),
        Paint()
          ..color = _kOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = (top.scale * 0.06).clamp(0.8, 1.8),
      );
    }
  }

  void _paintBlossom3D(
    Canvas canvas,
    SkiBlossomCollectible3D b,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final double bob =
        math.sin(engine.ambientTime * 4.2 + b.phaseOffset) * 0.18;
    final _ProjectedPoint3D ground = project(b.x, 0.0, b.z);
    final _ProjectedPoint3D p = project(b.x, b.y + bob, b.z);
    if (p.scale < 1.1) return;

    final double r = (p.scale * 0.56).clamp(3.0, 18.0);

    // Ground shadow beneath floating Blossom
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ground.x, ground.y),
        width: r * 1.4,
        height: r * 0.45,
      ),
      Paint()..color = const Color(0xFF1A3B5C).withValues(alpha: 0.22),
    );

    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(engine.ambientTime * 2.2 + b.phaseOffset);

    final Color petalFill =
        b.isStarGold ? const Color(0xFFFFD700) : const Color(0xFFFF80AB);
    final Paint fillPaint = Paint()..color = petalFill;
    final Paint strokePaint = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.16).clamp(0.9, 2.2);

    for (int k = 0; k < 4; k++) {
      final double a = k * (math.pi * 0.5);
      final Offset pc = Offset(math.cos(a) * r * 0.52, math.sin(a) * r * 0.52);
      canvas.drawCircle(pc, r * 0.48, fillPaint);
      canvas.drawCircle(pc, r * 0.48, strokePaint);
    }
    canvas.drawCircle(Offset.zero, r * 0.28, Paint()..color = const Color(0xFFFFF9C4));
    canvas.restore();
  }

  void _paintAlpineChalet3D(
    Canvas canvas,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final _ProjectedPoint3D base = project(prop.x, 0.0, prop.z);
    final double s = base.scale * prop.scale;
    if (s < 0.9) return;

    final double w = 6.8 * s;
    final double h = 4.6 * s;
    final Rect walls =
        Rect.fromCenter(center: Offset(base.x, base.y - h * 0.42), width: w, height: h * 0.84);
    canvas.drawRRect(
      RRect.fromRectAndRadius(walls, Radius.circular(s * 0.2)),
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(walls, Radius.circular(s * 0.2)),
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.12).clamp(1.2, 2.8),
    );

    // Warm golden lit chalet windows
    for (final double wxOff in <double>[-0.24, 0.24]) {
      final Rect win = Rect.fromCenter(
        center: Offset(base.x + w * wxOff, base.y - h * 0.44),
        width: w * 0.20,
        height: h * 0.26,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(win, Radius.circular(s * 0.1)),
        Paint()..color = const Color(0xFFFFE082),
      );
    }

    // Thick snowy Alpine gable roof
    final Path roof = Path()
      ..moveTo(base.x, base.y - h * 1.18)
      ..lineTo(base.x + w * 0.64, base.y - h * 0.68)
      ..lineTo(base.x - w * 0.64, base.y - h * 0.68)
      ..close();
    canvas.drawPath(roof, Paint()..color = Colors.white);
    canvas.drawPath(
      roof,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.12).clamp(1.2, 2.8)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintArch3D(
    Canvas canvas,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project, {
    required bool isFinish,
  }) {
    final double spanHalfW = isFinish ? 9.5 : 8.5;
    final _ProjectedPoint3D lBase = project(prop.x - spanHalfW, 0.0, prop.z);
    final _ProjectedPoint3D rBase = project(prop.x + spanHalfW, 0.0, prop.z);
    final _ProjectedPoint3D lTop = project(prop.x - spanHalfW, 6.2, prop.z);
    final _ProjectedPoint3D rTop = project(prop.x + spanHalfW, 6.2, prop.z);
    if (lBase.scale < 0.8) return;

    final double postW = (lBase.scale * 0.65).clamp(2.5, 16.0);
    final Paint pillarPaint = Paint()
      ..color = const Color(0xFF3A2618)
      ..strokeWidth = postW
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(lBase.x, lBase.y), Offset(lTop.x, lTop.y), pillarPaint);
    canvas.drawLine(Offset(rBase.x, rBase.y), Offset(rTop.x, rTop.y), pillarPaint);

    final Rect bannerRect = Rect.fromLTRB(
      lTop.x - postW * 0.4,
      lTop.y - lTop.scale * 1.35,
      rTop.x + postW * 0.4,
      rTop.y + rTop.scale * 0.25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, Radius.circular(lTop.scale * 0.3)),
      Paint()
        ..color =
            isFinish ? const Color(0xFF8B1E24) : const Color(0xFF2B1D14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, Radius.circular(lTop.scale * 0.3)),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (lTop.scale * 0.16).clamp(1.5, 4.2),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Vivienne 3D Skier Seen From Behind (`180°` & `135°..225°` + Rig 3D)
  // ---------------------------------------------------------------------------

  void _paintVivienneSkier3D(
    Canvas canvas,
    Size size,
    SkiTrackId track,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final double wx = engine.playerWorldX;
    final _ProjectedPoint3D groundPt = project(wx, 0.0, engine.playerZ);
    final _ProjectedPoint3D skierPt =
        project(wx, engine.playerY, engine.playerZ);

    final double s = skierPt.scale;
    final VivienneSkiEdition edition = engine.selectedEdition;
    final bool isAirborne = engine.playerY > 0.35;

    // 4.1 Ground Shadow Ellipse (shrinks & fades realistically when jumping!)
    final double airAttenuation =
        (1.0 / (1.0 + engine.playerY * 0.32)).clamp(0.28, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(groundPt.x, groundPt.y + s * 0.10),
        width: s * 2.55 * airAttenuation,
        height: s * 0.72 * airAttenuation,
      ),
      Paint()
        ..color =
            const Color(0xFF14283C).withValues(alpha: 0.34 * airAttenuation),
    );

    canvas.save();
    canvas.translate(skierPt.x, skierPt.y);
    canvas.rotate(engine.playerRollRadians * 0.78);

    // 4.2 Pair of 3D Parabolic LV Monogram & 24K Gold Skis beneath her feet
    _paintParabolicSkis3D(canvas, s, edition, isAirborne);

    // 4.3 Squash & Stretch Transform anchored at ski bindings
    canvas.save();
    canvas.scale(engine.currentAnimScaleX, engine.currentAnimScaleY);

    final double heroHeight = s * 3.85;
    final double heroWidth = heroHeight * 0.88;
    final int frameIdx = engine.activeSkierTurntableFrameIndex;
    final ui.Image? cyclesRearSprite =
        (frameIdx >= 0 && frameIdx < turntableSprites.length)
            ? turntableSprites[frameIdx]
            : null;

    // Articulated Ski Poles & Raised V-Arms (drawn behind/around body for proper 3D layering)
    _paintArticulatedSkiPolesAndVArms(
      canvas,
      s,
      heroHeight,
      edition,
      isAirborne: isAirborne,
    );

    if (cyclesRearSprite != null) {
      // Hybrid Cycles 3D Render (`vivienne_turntable_12.png` = 180° Rear + `09..15` Carving)
      final Rect src = Rect.fromLTWH(
        0,
        0,
        cyclesRearSprite.width.toDouble(),
        cyclesRearSprite.height.toDouble(),
      );
      final Rect dst = Rect.fromCenter(
        center: Offset(0, -heroHeight * 0.49),
        width: heroWidth,
        height: heroHeight,
      );
      canvas.drawImageRect(
        cyclesRearSprite,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      // High-Precision Procedural 3D Rear-View Vivienne Rig (`vivienne_speedy_v03.blend` anatomy)
      _paintProceduralRearVivienneRig(canvas, s, heroHeight, edition);
    }

    // 4.4 Haute Couture Rear Ski Accessories: Goggles Strap on Back of Oak Head + Billowing Scarf
    _paintRearSkiGogglesAndScarf(canvas, s, heroHeight, edition);
    if (cyclesRearSprite == null) {
      _paintSwingingSpeedyBagOverlay(canvas, s, heroHeight, edition);
    }

    canvas.restore(); // End Squash & Stretch
    canvas.restore(); // End skier translation/roll
  }

  void _paintParabolicSkis3D(
    Canvas canvas,
    double s,
    VivienneSkiEdition edition,
    bool isAirborne,
  ) {
    final SkiAerialTrickKind trick = engine.currentAerialTrick;
    // Foreshortened 3rd-person perspective ski angles (converging slightly toward horizon)
    double leftSkiAngle = 0.08 + engine.playerRollRadians * 0.22;
    double rightSkiAngle = -0.08 + engine.playerRollRadians * 0.22;
    double stanceHalf = s * 0.29;

    if (isAirborne) {
      if (trick == SkiAerialTrickKind.crossSkiGrab) {
        leftSkiAngle = 0.56;
        rightSkiAngle = -0.56;
        stanceHalf = s * 0.14;
      } else if (trick == SkiAerialTrickKind.spreadEagle) {
        leftSkiAngle = -0.44;
        rightSkiAngle = 0.44;
        stanceHalf = s * 0.58;
      }
    }

    for (final (double xPos, double angle) in <(double, double)>[
      (-stanceHalf, leftSkiAngle),
      (stanceHalf, rightSkiAngle),
    ]) {
      canvas.save();
      canvas.translate(xPos, -s * 0.08);
      canvas.rotate(angle);

      final double skiW = s * 0.30;
      final double tailY = s * 0.54; // Ski tail extending toward camera behind heels
      final double tipY = -s * 0.68; // Foreshortened ski tip extending ahead of toes

      final Path skiPath = Path()
        ..moveTo(-skiW * 0.56, tailY)
        ..lineTo(skiW * 0.56, tailY)
        ..lineTo(skiW * 0.38, tipY * 0.74)
        ..quadraticBezierTo(0, tipY, -skiW * 0.38, tipY * 0.74)
        ..close();

      // Carmine leather/sidewall bevel (#8B1E24)
      canvas.drawPath(
        skiPath.shift(Offset(0, s * 0.06)),
        Paint()..color = edition.trimEdgeColor,
      );

      // Ebony Monogram deck + 24K Gold center racing stripe
      canvas.drawPath(skiPath, Paint()..color = edition.skiDeckColor);
      canvas.drawPath(
        skiPath,
        Paint()
          ..color = edition.skiAccentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s * 0.055).clamp(1.1, 2.4),
      );
      canvas.drawLine(
        Offset(0, tailY * 0.85),
        Offset(0, tipY * 0.78),
        Paint()
          ..color = edition.skiAccentColor.withValues(alpha: 0.85)
          ..strokeWidth = (s * 0.045).clamp(1.0, 1.9),
      );

      // Golden ski binding heelpiece right behind Vivienne's wooden heel
      final RRect binding = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, s * 0.14),
          width: skiW * 0.80,
          height: s * 0.18,
        ),
        Radius.circular(s * 0.04),
      );
      canvas.drawRRect(binding, Paint()..color = const Color(0xFFFFD700));
      canvas.restore();
    }
  }

  void _paintProceduralRearVivienneRig(
    Canvas canvas,
    double s,
    double heroHeight,
    VivienneSkiEdition edition,
  ) {
    final double carveShift =
        (engine.playerRollRadians / 0.45).clamp(-1.0, 1.0) * s * 0.18;
    final Paint stroke = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.085).clamp(1.4, 2.8)
      ..strokeJoin = StrokeJoin.round;

    // 4 Vachetta Leather Corolla Petals (`Petal_Top/Bottom/Left/Right`) with carmine edge & gold stitches
    final Offset headCenter = Offset(carveShift * 0.5, -heroHeight * 0.56);
    final double petalR = heroHeight * 0.23;
    final List<Offset> petalOffsets = <Offset>[
      Offset(0, -petalR * 1.18), // Top petal
      Offset(-petalR * 1.22, -petalR * 0.04), // Left petal
      Offset(petalR * 1.22, -petalR * 0.04), // Right petal
      Offset(0, petalR * 1.04), // Bottom petal
    ];

    for (final Offset po in petalOffsets) {
      final Offset pc = headCenter + po;
      // Carmine glazed edge (#8B1E24)
      canvas.drawCircle(
        pc + Offset(carveShift * 0.22, s * 0.05),
        petalR,
        Paint()..color = edition.trimEdgeColor,
      );
      // Vachetta leather back (#E3A17B)
      canvas.drawCircle(pc, petalR * 0.96, Paint()..color = edition.petalColor);
      canvas.drawCircle(pc, petalR * 0.96, stroke);
      // Yellow saddle stitch ring (#E5B842)
      canvas.drawCircle(
        pc,
        petalR * 0.80,
        Paint()
          ..color = edition.stitchGoldColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s * 0.045).clamp(0.9, 1.8),
      );
    }

    // Oak Wood Monogram Body (`Vivienne_Body` seen from behind)
    final Path bodyPath = Path()
      ..moveTo(-s * 0.56, -heroHeight * 0.36)
      ..lineTo(s * 0.56, -heroHeight * 0.36)
      ..quadraticBezierTo(s * 0.76, -heroHeight * 0.14, s * 0.62, -s * 0.06)
      ..lineTo(s * 0.10, -s * 0.06)
      ..lineTo(0, -s * 0.20)
      ..lineTo(-s * 0.10, -s * 0.06)
      ..lineTo(-s * 0.62, -s * 0.06)
      ..quadraticBezierTo(-s * 0.76, -heroHeight * 0.14, -s * 0.56, -heroHeight * 0.36)
      ..close();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-s * 0.6, -heroHeight * 0.36),
          Offset(s * 0.6, 0),
          const <Color>[Color(0xFFD7B391), Color(0xFFC89D7C), Color(0xFF9F7356)],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    canvas.drawPath(bodyPath, stroke);

    // Subtle Monogram diamond accents on back of oak wood body
    final Paint monoPaint = Paint()
      ..color = const Color(0xFF3A2618).withValues(alpha: 0.68);
    for (final Offset mp in <Offset>[
      Offset(-s * 0.26, -heroHeight * 0.24),
      Offset(s * 0.26, -heroHeight * 0.24),
      Offset(0, -heroHeight * 0.16),
    ]) {
      canvas.drawCircle(mp, s * 0.07, monoPaint);
    }

    // Spherical Light Oak Head (`Vivienne_Head` seen from behind)
    final double headR = heroHeight * 0.21;
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..shader = ui.Gradient.radial(
          headCenter + Offset(-headR * 0.25, -headR * 0.25),
          headR * 1.25,
          const <Color>[Color(0xFFE2C3A3), Color(0xFFC89D7C), Color(0xFF9C7254)],
          const <double>[0.0, 0.65, 1.0],
        ),
    );
    canvas.drawCircle(headCenter, headR, stroke);
  }

  void _paintArticulatedSkiPolesAndVArms(
    Canvas canvas,
    double s,
    double heroHeight,
    VivienneSkiEdition edition, {
    required bool isAirborne,
  }) {
    final double armRaise = engine.armRaiseProgress.clamp(0.0, 1.0);
    // Shoulder anchors
    final Offset leftShoulder = Offset(-s * 0.55, -heroHeight * 0.36);
    final Offset rightShoulder = Offset(s * 0.55, -heroHeight * 0.36);

    // Interpolate hands from tucked aerodynamic schuss (down/out) to triumphant V-Arms high above head!
    final Offset leftHandSchuss = Offset(-s * 1.18, -heroHeight * 0.20);
    final Offset leftHandVictoryV = Offset(-s * 1.26, -heroHeight * 0.82);
    final Offset rightHandSchuss = Offset(s * 1.18, -heroHeight * 0.20);
    final Offset rightHandVictoryV = Offset(s * 1.26, -heroHeight * 0.82);

    final Offset leftHand = Offset.lerp(leftHandSchuss, leftHandVictoryV, armRaise)!;
    final Offset rightHand =
        Offset.lerp(rightHandSchuss, rightHandVictoryV, armRaise)!;

    // When arms are raised (`armRaise > 0.35`) or no Cycles sprite is drawn, draw articulated LV leather strap arms!
    if (armRaise > 0.32 || turntableSprites.isEmpty) {
      final Paint armStrapPaint = Paint()
        ..color = const Color(0xFF2B1D14)
        ..strokeWidth = (s * 0.20).clamp(2.4, 7.0)
        ..strokeCap = StrokeCap.round;
      final Paint armEdgePaint = Paint()
        ..color = edition.trimEdgeColor
        ..strokeWidth = (s * 0.08).clamp(1.2, 3.0)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(leftShoulder, leftHand, armStrapPaint);
      canvas.drawLine(rightShoulder, rightHand, armStrapPaint);
      canvas.drawLine(leftShoulder, leftHand, armEdgePaint);
      canvas.drawLine(rightShoulder, rightHand, armEdgePaint);

      // 24K Gold Clasps at hands (`Vivienne_Clasp_L/R`)
      final Paint goldPaint = Paint()..color = const Color(0xFFFFD700);
      canvas.drawCircle(leftHand, s * 0.12, goldPaint);
      canvas.drawCircle(rightHand, s * 0.12, goldPaint);
    }

    // 24K Brushed Gold Ski Poles (`Ski_Pole_L`, `Ski_Pole_R`) + Star Blossom Snow Baskets
    final Offset leftPoleTip = isAirborne
        ? leftHand + Offset(-s * 0.58, -s * 0.75 * armRaise + s * 0.45)
        : leftHand + Offset(-s * 0.42, s * 0.88);
    final Offset rightPoleTip = isAirborne
        ? rightHand + Offset(s * 0.58, -s * 0.75 * armRaise + s * 0.45)
        : rightHand + Offset(s * 0.42, s * 0.88);

    final Paint poleOutline = Paint()
      ..color = _kOutline
      ..strokeWidth = (s * 0.12).clamp(1.8, 4.2)
      ..strokeCap = StrokeCap.round;
    final Paint goldShaft = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = (s * 0.075).clamp(1.2, 2.8)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(leftHand, leftPoleTip, poleOutline);
    canvas.drawLine(leftHand, leftPoleTip, goldShaft);
    canvas.drawLine(rightHand, rightPoleTip, poleOutline);
    canvas.drawLine(rightHand, rightPoleTip, goldShaft);

    // Star Blossom snow baskets near pole tips
    for (final (Offset hand, Offset tip) in <(Offset, Offset)>[
      (leftHand, leftPoleTip),
      (rightHand, rightPoleTip),
    ]) {
      final Offset basket = Offset.lerp(hand, tip, 0.82)!;
      canvas.drawCircle(
        basket,
        (s * 0.14).clamp(2.0, 5.5),
        Paint()..color = edition.trimEdgeColor,
      );
      canvas.drawCircle(
        basket,
        (s * 0.07).clamp(1.2, 3.0),
        Paint()..color = const Color(0xFFFFD700),
      );
    }
  }

  void _paintRearSkiGogglesAndScarf(
    Canvas canvas,
    double s,
    double heroHeight,
    VivienneSkiEdition edition,
  ) {
    // 1. Monogram Elastic Ski Goggles Strap wrapping the back of Vivienne's Oak Head
    final double strapY = -heroHeight * 0.51;
    final double headSpanW = heroHeight * 0.29;
    final RRect strap = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, strapY),
        width: headSpanW,
        height: s * 0.16,
      ),
      Radius.circular(s * 0.07),
    );
    canvas.drawRRect(strap, Paint()..color = const Color(0xFF2B1D14));
    canvas.drawRRect(
      strap,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.045).clamp(0.9, 1.8),
    );
    // Center brass buckle on back of goggles strap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, strapY),
          width: s * 0.24,
          height: s * 0.26,
        ),
        Radius.circular(s * 0.05),
      ),
      Paint()..color = const Color(0xFFFFD700),
    );

    // 2. Billowing Cashmere Scarf (`Vivienne_Scarf`) streaming in the Alpine wind!
    final Offset neck = Offset(0, -heroHeight * 0.36);
    final double wave1 = math.sin(engine.scarfWavePhase) * s * 0.28;
    final double wave2 = math.cos(engine.scarfWavePhase * 1.3) * s * 0.36;
    final double lateralWind = -engine.effectiveTiltX * s * 0.42;

    final Path scarfTail = Path()
      ..moveTo(neck.dx - s * 0.16, neck.dy)
      ..cubicTo(
        neck.dx + wave1 + lateralWind * 0.4,
        neck.dy + s * 0.35,
        neck.dx - wave2 + lateralWind * 0.8,
        neck.dy + s * 0.72,
        neck.dx + wave1 * 0.8 + lateralWind,
        neck.dy + s * 0.98,
      )
      ..lineTo(
        neck.dx + wave1 * 0.8 + lateralWind + s * 0.26,
        neck.dy + s * 0.92,
      )
      ..cubicTo(
        neck.dx - wave2 + lateralWind * 0.8 + s * 0.24,
        neck.dy + s * 0.66,
        neck.dx + wave1 + lateralWind * 0.4 + s * 0.20,
        neck.dy + s * 0.30,
        neck.dx + s * 0.18,
        neck.dy,
      )
      ..close();

    canvas.drawPath(scarfTail, Paint()..color = edition.scarfColor);
    canvas.drawPath(
      scarfTail,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.06).clamp(1.0, 2.2)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintSwingingSpeedyBagOverlay(
    Canvas canvas,
    double s,
    double heroHeight,
    VivienneSkiEdition edition,
  ) {
    final double armRaise = engine.armRaiseProgress.clamp(0.0, 1.0);
    final Offset anchor = Offset.lerp(
      Offset(-s * 0.95, -heroHeight * 0.14),
      Offset(-s * 1.24, -heroHeight * 0.76),
      armRaise,
    )!;

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(engine.speedyBagSwingRadians);

    final RRect bagBody = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, s * 0.26),
        width: s * 0.56,
        height: s * 0.40,
      ),
      Radius.circular(s * 0.12),
    );
    canvas.drawRRect(bagBody, Paint()..color = const Color(0xFF2B1D14));
    canvas.drawRRect(
      bagBody,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.05).clamp(1.0, 2.0),
    );

    // Vachetta leather top handles
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, s * 0.06),
        width: s * 0.30,
        height: s * 0.28,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFE3A17B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.06).clamp(1.1, 2.2),
    );
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // 5. 3D Falling Snowflakes, Powder Spray & Floating Score Callouts
  // ---------------------------------------------------------------------------

  void _paintSnowParticle3D(
    Canvas canvas,
    SkiSnowParticle3D p,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final _ProjectedPoint3D pt = project(p.x, p.y, p.z);
    final double r = p.isPowderSpray
        ? (pt.scale * 0.11 * p.size * 0.35).clamp(1.5, 9.5)
        : (pt.scale * 0.055 * p.size).clamp(1.2, 5.2);
    final double alpha =
        p.isPowderSpray ? (p.normalizedLife * 0.88) : 0.82;
    canvas.drawCircle(
      Offset(pt.x, pt.y),
      r,
      Paint()..color = p.color.withValues(alpha: alpha),
    );
  }

  void _paintFloatingCallouts(Canvas canvas, Size size) {
    for (int i = 0; i < engine.callouts.length; i++) {
      final SkiFloatingCallout c = engine.callouts[i];
      final double y = size.height * 0.44 - c.progress * 44.0 - i * 26.0;
      final double alpha = (1.0 - c.progress * 0.85).clamp(0.0, 1.0);

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: c.text,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: c.color.withValues(alpha: alpha),
            shadows: <Shadow>[
              Shadow(
                color: _kOutline.withValues(alpha: alpha),
                offset: const Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset((size.width - tp.width) * 0.5, y),
      );
    }
  }

  @override
  bool shouldRepaint(covariant Ski3DPainter oldDelegate) {
    return oldDelegate.engine != engine ||
        oldDelegate.turntableSprites.length != turntableSprites.length;
  }
}
