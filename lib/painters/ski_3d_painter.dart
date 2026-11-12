import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/ski_game_engine.dart';
import '../models/ski_models.dart';
import 'vivienne_3d_volumetric_rig.dart';

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
/// for `VIVI AU SKI : Descente Royale 3D` (`v1.2.0`).
class Ski3DPainter extends CustomPainter {
  Ski3DPainter({
    required this.engine,
    this.rearPoseSprites = const <VivienneSkiEdition, List<ui.Image?>>{},
    this.frontPoseSprites = const <VivienneSkiEdition, List<ui.Image?>>{},
    this.editionHeroSprites = const <VivienneSkiEdition, ui.Image>{},
    this.turntableSprites = const <ui.Image?>[],
    this.poseSprites = const <VivienneBlenderPose, ui.Image>{},
    this.lvNeoBannerImage,
  }) : super(repaint: engine);

  final SkiGameEngine engine;
  final Map<VivienneSkiEdition, List<ui.Image?>> rearPoseSprites;
  final Map<VivienneSkiEdition, List<ui.Image?>> frontPoseSprites;
  final Map<VivienneSkiEdition, ui.Image> editionHeroSprites;
  final List<ui.Image?> turntableSprites;
  final Map<VivienneBlenderPose, ui.Image> poseSprites;
  final ui.Image? lvNeoBannerImage;

  static const Color _kOutline = Color(0xFF2B1105);
  static const Color _kLvNeoCobalt = Color(0xFF1638E8);
  static const double _kZNear = 6.2;
  static const double _kZFar = 225.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final SkiTrackId track = engine.selectedTrack;
    final double speedNorm =
        ((engine.speedKmh - track.baseSpeedKmh) /
                math.max(1.0, track.maxSpeedKmh - track.baseSpeedKmh))
            .clamp(0.0, 1.3);

    // Steep Slope Geometry (`24°`, `34°`, `45°`) & High-Speed Dynamic FOV
    final double slopeRad = track.slopeDegrees * math.pi / 180.0;
    final double slopeTan = math.tan(slopeRad);
    final double steepFactor = ((slopeTan - 0.445) / 0.555).clamp(0.0, 1.0);

    final double camDistBack = 11.4 +
        speedNorm * 1.65 +
        steepFactor * 0.85 +
        (engine.playerY * 0.18).clamp(0.0, 1.6);
    final double camZ = engine.playerZ - camDistBack;
    final double camWorldX = engine.trackCenterOffsetX(engine.playerZ) +
        engine.playerLateralOffset * 0.70;
    final double camHeight = 14.8 +
        steepFactor * 2.4 +
        (engine.playerY * 0.30).clamp(0.0, 2.8);
    final double focal =
        size.width * (0.87 - speedNorm * 0.065 - steepFactor * 0.045);
    final double crestPitchShift =
        math.cos(engine.playerZ * 0.036) * 0.008 * (0.6 + steepFactor * 0.5);
    final double horizonY = size.height *
        (0.252 -
                steepFactor * 0.028 -
                speedNorm * 0.016 +
                crestPitchShift +
                engine.playerY * 0.004)
            .clamp(0.185, 0.30);
    final double playerReliefRef = engine.relativeReliefAtZ(engine.playerZ);

    // Subtle camera roll synchronized with carving lean
    final double camRoll = -engine.playerRollRadians * 0.16;

    _ProjectedPoint3D project(double worldX, double yAboveSnow, double worldZ) {
      final double zRel = math.max(_kZNear * 0.65, worldZ - camZ);
      final double s = focal / zRel;
      final double reliefDelta =
          engine.relativeReliefAtZ(worldZ) - playerReliefRef;
      // Plunging downhill drop scaled by real track `slopeDegrees` (`24°..45°`)
      final double slopeDrop = (worldZ - engine.playerZ) * slopeTan * 0.062;
      final double sx = size.width * 0.5 + (worldX - camWorldX) * s;
      final double sy =
          horizonY + (camHeight - yAboveSnow - reliefDelta + slopeDrop) * s;
      return _ProjectedPoint3D(x: sx, y: sy, scale: s, zRel: zRel);
    }

    // Apply subtle camera roll around screen center
    canvas.save();
    if (camRoll.abs() > 0.001) {
      canvas.translate(size.width * 0.5, horizonY);
      canvas.rotate(camRoll);
      canvas.translate(-size.width * 0.5, -horizonY);
    }

    // 1. Sky Dome, Sun / Aurora Borealis, LV Blossom Hot Air Balloons & Parallax Alpine Peaks
    _paintAlpineSkyAndMountains(canvas, size, track, horizonY, camWorldX);

    // 2. Trapezoidal 3D Snow Slope Mesh (`5.0 m` corduroy bands) & Dual Persistent Ski Marks
    _paintSnowSlopeMesh3D(canvas, size, track, camZ, horizonY, project);
    _paintPersistentSkiTracks3D(canvas, track, camZ, project);

    // 3. Strict Painter's Algorithm Z-Sort (zFar -> zNear) of all 3D World Entities
    final List<_DepthRenderItem> items = <_DepthRenderItem>[];
    final double zMinVisible = camZ + _kZNear * 0.75;
    final double zMaxVisible = camZ + _kZFar;

    for (int i = 0; i < engine.worldProps.length; i++) {
      final SkiWorldProp3D prop = engine.worldProps[i];
      final double margin = switch (prop.kind) {
        SkiPropKind.lvBannerPost => 4.5,
        SkiPropKind.cableCarPylon => 165.0,
        _ => 0.0,
      };
      if (prop.z + margin >= zMinVisible && prop.z - margin <= zMaxVisible) {
        items.add(
          _DepthRenderItem(
            zWorld: prop.z,
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
            camZ,
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

    // 4. Radial High-Speed Wind Lines ("filets de vent alpin") along screen edges
    _paintHighSpeedWindLines(canvas, size, track, horizonY, speedNorm);

    // 5. Screen-space floating score callouts
    _paintFloatingCallouts(canvas, size);

    canvas.restore();
  }

  void _paintHighSpeedWindLines(
    Canvas canvas,
    Size size,
    SkiTrackId track,
    double horizonY,
    double speedNorm,
  ) {
    if (engine.isInMenu || engine.speedKmh < 54.0) return;

    final double intensity =
        ((engine.speedKmh - 54.0) / 85.0).clamp(0.12, 1.0);
    final Offset vanish = Offset(size.width * 0.5, horizonY + 26.0);
    final double maxRadius = size.height * 0.78;
    const int rayCount = 18;

    for (int i = 0; i < rayCount; i++) {
      final bool leftSide = i.isEven;
      final int sideIdx = i ~/ 2;
      // Spread rays across the left and right outer fans so Vivienne stays clear in the center
      final double fanFrac = (sideIdx + 0.35) / (rayCount * 0.5);
      final double baseAngle = leftSide
          ? (math.pi * (0.64 + fanFrac * 0.56))
          : (math.pi * (0.36 - fanFrac * 0.56));
      final Offset dir = Offset(math.cos(baseAngle), math.sin(baseAngle));

      final double cycle =
          (engine.ambientTime * (2.6 + intensity * 3.4) + i * 0.37) % 1.0;
      final double rStart = maxRadius * (0.28 + cycle * 0.52);
      final double streakLen = (28.0 + intensity * 68.0) * (0.65 + cycle * 0.55);
      final Offset p0 = vanish + dir * rStart;
      final Offset p1 = vanish + dir * (rStart + streakLen);

      final double alpha =
          (math.sin(cycle * math.pi) * intensity * 0.52).clamp(0.0, 0.58);
      if (alpha <= 0.02) continue;

      final Color windColor = i % 3 == 0
          ? const Color(0xFFB3E5FC).withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha);

      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..shader = ui.Gradient.linear(
            p0,
            p1,
            <Color>[windColor.withValues(alpha: 0.0), windColor],
          )
          ..strokeWidth = 1.4 + intensity * 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
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

    // Radiant Alpine Sun / Golden Moon (realistic ultra-far horizon parallax)
    final Offset sunCenter = Offset(
      size.width * 0.74 - camWorldX * 0.06,
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

    // Far & Near 3D Snow-Capped Mountain Ranges in Smooth Continuous Parallax
    _paintMountainRange(
      canvas,
      size,
      horizonY: horizonY + 8,
      peakHeight: 82.0,
      parallaxOffset: -camWorldX * 0.14,
      mountainColor: track.mountainFarColor,
      snowCapColor: track.snowBrightColor.withValues(alpha: 0.88),
      seedShift: 1,
    );
    _paintMountainRange(
      canvas,
      size,
      horizonY: horizonY + 14,
      peakHeight: 54.0,
      parallaxOffset: -camWorldX * 0.26,
      mountainColor: track.mountainNearColor,
      snowCapColor: track.snowBrightColor,
      seedShift: 4,
    );

    // Floating LV Blossom Hot Air Balloons in Alpine Sky Parallax
    _paintParallaxHotAirBalloons(canvas, size, horizonY, camWorldX);
  }

  void _paintParallaxHotAirBalloons(
    Canvas canvas,
    Size size,
    double horizonY,
    double camWorldX,
  ) {
    final List<(double, double, double, Color, Color)> specs =
        <(double, double, double, Color, Color)>[
      (0.22, 0.56, 17.5, _kLvNeoCobalt, const Color(0xFFFFD700)),
      (0.82, 0.64, 13.5, const Color(0xFFE31C58), const Color(0xFFF3B7C3)),
    ];

    for (int i = 0; i < specs.length; i++) {
      final (
        double xFrac,
        double yFrac,
        double radius,
        Color primary,
        Color accent,
      ) = specs[i];
      final double bob =
          math.sin(engine.ambientTime * 1.45 + i * 2.1) * 4.5;
      final double drift =
          math.cos(engine.ambientTime * 0.65 + i * 1.4) * 5.0;
      final Offset c = Offset(
        size.width * xFrac - camWorldX * (0.06 + i * 0.03) + drift,
        horizonY * yFrac + bob,
      );

      // Gondola suspension cords & wicker basket
      final Rect basket = Rect.fromCenter(
        center: Offset(c.dx, c.dy + radius * 1.45),
        width: radius * 0.52,
        height: radius * 0.36,
      );
      final Paint cordPaint = Paint()
        ..color = _kOutline
        ..strokeWidth = 1.1;
      canvas.drawLine(
        Offset(c.dx - radius * 0.34, c.dy + radius * 0.88),
        Offset(basket.left + 1.5, basket.top),
        cordPaint,
      );
      canvas.drawLine(
        Offset(c.dx + radius * 0.34, c.dy + radius * 0.88),
        Offset(basket.right - 1.5, basket.top),
        cordPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(basket, const Radius.circular(2.5)),
        Paint()..color = const Color(0xFF8D6E63),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(basket, const Radius.circular(2.5)),
        Paint()
          ..color = _kOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Teardrop 3D Hot Air Balloon Envelope
      final Path env = Path()
        ..moveTo(c.dx, c.dy - radius)
        ..cubicTo(
          c.dx + radius * 1.18,
          c.dy - radius * 0.95,
          c.dx + radius * 1.05,
          c.dy + radius * 0.35,
          c.dx + radius * 0.36,
          c.dy + radius * 0.98,
        )
        ..lineTo(c.dx - radius * 0.36, c.dy + radius * 0.98)
        ..cubicTo(
          c.dx - radius * 1.05,
          c.dy + radius * 0.35,
          c.dx - radius * 1.18,
          c.dy - radius * 0.95,
          c.dx,
          c.dy - radius,
        )
        ..close();

      canvas.drawPath(
        env,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-radius * 0.28, -radius * 0.32),
            radius * 1.45,
            <Color>[Colors.white, accent, primary],
            const <double>[0.0, 0.32, 1.0],
          ),
      );
      // Center vertical Haute Couture stripe + 4-petal Blossom star
      canvas.save();
      canvas.clipPath(env);
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: radius * 0.85,
          height: radius * 2.1,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.88),
      );
      for (int p = 0; p < 4; p++) {
        final double a = p * math.pi * 0.5;
        canvas.drawCircle(
          c + Offset(math.cos(a) * radius * 0.18, math.sin(a) * radius * 0.18 - radius * 0.10),
          radius * 0.14,
          Paint()..color = primary,
        );
      }
      canvas.drawCircle(
        c + Offset(0, -radius * 0.10),
        radius * 0.08,
        Paint()..color = const Color(0xFFFFD700),
      );
      canvas.restore();

      canvas.drawPath(
        env,
        Paint()
          ..color = _kOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
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
    const double step = 68.0;
    const int kMin = -12;
    final int kMax = (size.width ~/ step) + 12;
    final double firstX = kMin * step + parallaxOffset;
    final double lastX = (kMax + 1) * step + parallaxOffset;
    final Path range = Path()..moveTo(firstX, horizonY + 24);
    final List<Offset> peaks = <Offset>[];
    for (int k = kMin; k <= kMax; k++) {
      final int idx = k + seedShift;
      final double h = peakHeight *
          (0.55 + 0.45 * ((math.sin(idx * 2.3) + 1.0) * 0.5));
      final double px = k * step + parallaxOffset;
      final Offset p = Offset(px, horizonY - h);
      peaks.add(p);
      range.lineTo(p.dx, p.dy);
      range.lineTo(px + step * 0.5, horizonY - h * 0.36);
    }
    range
      ..lineTo(lastX, horizonY + 24)
      ..close();
    canvas.drawPath(range, Paint()..color = mountainColor);

    // Crisp Cartoon Snow Caps on mountain peaks
    final Paint capPaint = Paint()..color = snowCapColor;
    for (final Offset pk in peaks) {
      if (pk.dx < -40.0 || pk.dx > size.width + 40.0) continue;
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
  // 2. Trapezoidal 3D Snow Slope Mesh (`5.0 m` Corduroy) & Dual Ski Marks
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

    // Render 68 perspective trapezoidal snow bands from zFar -> zNear (`5.0 m` grooming!)
    const int sliceCount = 68;
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

      // Tighter `5.0 m` groomed snow bands for high-velocity downhill rush!
      final int worldBand = (currZ / 5.0).floor();
      final bool altBand = worldBand.isEven;

      // Off-piste powder banks (Left & Right shoulders with alpine blue shadows)
      final Color powderColor = altBand
          ? Color.lerp(track.snowMidColor, track.snowShadowColor, 0.36)!
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
          : Color.lerp(track.snowBrightColor, track.snowShadowColor, 0.19)!;
      final Path pisteQuad = Path()
        ..moveTo(prevLeft.x, prevLeft.y)
        ..lineTo(prevRight.x, prevRight.y)
        ..lineTo(currRight.x, currRight.y)
        ..lineTo(currLeft.x, currLeft.y)
        ..close();
      canvas.drawPath(pisteQuad, Paint()..color = pisteColor);

      // Longitudinal corduroy grooming grooves rushing beneath skis
      if (altBand && currLeft.scale > 2.2) {
        final Paint cordPaint = Paint()
          ..color = track.snowShadowColor.withValues(alpha: 0.28)
          ..strokeWidth = (currLeft.scale * 0.05).clamp(0.8, 1.8);
        for (final double frac in const <double>[0.25, 0.50, 0.75]) {
          final double px0 =
              prevLeft.x + (prevRight.x - prevLeft.x) * frac;
          final double py0 =
              prevLeft.y + (prevRight.y - prevLeft.y) * frac;
          final double px1 =
              currLeft.x + (currRight.x - currLeft.x) * frac;
          final double py1 =
              currLeft.y + (currRight.y - currLeft.y) * frac;
          canvas.drawLine(Offset(px0, py0), Offset(px1, py1), cordPaint);
        }
      }

      // Crisp piste border snow-cushion lines (`LV_NEO` cobalt & track badge accents)
      final Paint edgePaint = Paint()
        ..color = altBand
            ? _kLvNeoCobalt.withValues(alpha: 0.65)
            : track.badgeColor.withValues(alpha: 0.72)
        ..strokeWidth = math.max(1.4, currLeft.scale * 0.16)
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
    double camZ,
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
        _paintLvNeoBanner3D(canvas, track, camZ, prop, project);
      case SkiPropKind.cableCarPylon:
        _paintCableCarSystem3D(canvas, track, camZ, prop, project);
      case SkiPropKind.cartoonSnowman:
        _paintCartoonSnowman3D(canvas, prop, project);
      case SkiPropKind.flutteringPennantPost:
        _paintFlutteringPennantAndSupporter3D(canvas, prop, project);
      case SkiPropKind.snowCannon:
        _paintSnowCannon3D(canvas, track, prop, project);
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
    if (s < 0.85) return;

    final double w = 6.8 * s;
    final double h = 4.6 * s;

    // Stone chimney + warm rising cartoon smoke rings
    final Rect chimney = Rect.fromCenter(
      center: Offset(base.x + w * 0.28, base.y - h * 1.02),
      width: w * 0.14,
      height: h * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chimney, Radius.circular(s * 0.08)),
      Paint()..color = const Color(0xFF5D4037),
    );
    for (int k = 0; k < 3; k++) {
      final double phase = (engine.ambientTime * 0.9 + k * 0.33 + prop.id * 0.2) % 1.0;
      final Offset puff = Offset(
        chimney.center.dx + math.sin(phase * 5.0 + k) * s * 0.35,
        chimney.top - phase * s * 1.65,
      );
      canvas.drawCircle(
        puff,
        (s * (0.20 + phase * 0.28)).clamp(1.2, 9.0),
        Paint()..color = Colors.white.withValues(alpha: (1.0 - phase) * 0.58),
      );
    }

    final Rect walls = Rect.fromCenter(
      center: Offset(base.x, base.y - h * 0.42),
      width: w,
      height: h * 0.84,
    );
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
        width: w * 0.22,
        height: h * 0.28,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(win, Radius.circular(s * 0.1)),
        Paint()..color = const Color(0xFFFFE082),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(win, Radius.circular(s * 0.1)),
        Paint()
          ..color = _kOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s * 0.06).clamp(0.8, 1.8),
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

  /// 3D Piste-Border `LV_NEO` Banner (`SkiPropKind.lvBannerPost`) stretched in perspective
  /// along the descent between two Cobalt Blue `#1638E8` & 24K Gold `#FFD700` masts.
  void _paintLvNeoBanner3D(
    Canvas canvas,
    SkiTrackId track,
    double camZ,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final bool isLeft = prop.variant == 0;
    final double sideSign = isLeft ? -1.0 : 1.0;
    final double borderOffset = sideSign * (track.trackHalfWidthMeters + 0.9);

    const double halfSpanZ = 3.8;
    final double rawZ0 = prop.z - halfSpanZ;
    final double rawZ1 = prop.z + halfSpanZ;
    final double clipZMin = camZ + _kZNear * 0.88;
    if (rawZ1 <= clipZMin + 0.4) return;

    final double z0 = math.max(rawZ0, clipZMin);
    final double z1 = rawZ1;
    final double uClip0 = ((z0 - rawZ0) / (rawZ1 - rawZ0)).clamp(0.0, 0.92);

    final double x0 = engine.trackCenterOffsetX(z0) + borderOffset;
    final double x1 = engine.trackCenterOffsetX(z1) + borderOffset;
    final _ProjectedPoint3D pTest = project(x1, 1.0, z1);
    if (pTest.scale < 0.85) return;

    const double yBannerBot = 0.42;
    const double yBannerTop = 1.98;
    const double yMastTop = 2.30;

    // Far mast (drawn first for Z-correctness)
    _paintLvNeoMastPost(canvas, project(x1, 0.0, z1), project(x1, yMastTop, z1));

    // Subdivide banner into 8 perspective vertical strips along `z0..z1`
    const int strips = 8;
    final List<_ProjectedPoint3D> topPts = <_ProjectedPoint3D>[];
    final List<_ProjectedPoint3D> botPts = <_ProjectedPoint3D>[];
    for (int k = 0; k <= strips; k++) {
      final double frac = k / strips;
      final double zk = z0 + (z1 - z0) * frac;
      final double xk = engine.trackCenterOffsetX(zk) + borderOffset;
      final double flutter =
          math.sin(engine.ambientTime * 4.8 + zk * 0.45) * 0.035 * math.sin(frac * math.pi);
      topPts.add(project(xk + flutter, yBannerTop, zk));
      botPts.add(project(xk + flutter, yBannerBot, zk));
    }

    final Path quadOutline = Path()..moveTo(topPts.first.x, topPts.first.y);
    for (int k = 1; k <= strips; k++) {
      quadOutline.lineTo(topPts[k].x, topPts[k].y);
    }
    for (int k = strips; k >= 0; k--) {
      quadOutline.lineTo(botPts[k].x, botPts[k].y);
    }
    quadOutline.close();

    // Crisp white luxury banner backing
    canvas.drawPath(quadOutline, Paint()..color = Colors.white);

    final ui.Image? img = lvNeoBannerImage;
    if (img != null && topPts.first.scale > 1.25) {
      final double imgW = img.width.toDouble();
      final double imgH = img.height.toDouble();
      final List<Offset> positions = <Offset>[];
      final List<Offset> texCoords = <Offset>[];

      for (int k = 0; k < strips; k++) {
        final double f0 = uClip0 + (1.0 - uClip0) * (k / strips);
        final double f1 = uClip0 + (1.0 - uClip0) * ((k + 1) / strips);
        // Orient U left-to-right on screen for BOTH left and right piste banners!
        final double u0 = (isLeft ? f0 : (1.0 - f0)) * imgW;
        final double u1 = (isLeft ? f1 : (1.0 - f1)) * imgW;

        final Offset tl = Offset(topPts[k].x, topPts[k].y);
        final Offset tr = Offset(topPts[k + 1].x, topPts[k + 1].y);
        final Offset br = Offset(botPts[k + 1].x, botPts[k + 1].y);
        final Offset bl = Offset(botPts[k].x, botPts[k].y);

        positions
          ..add(tl)
          ..add(tr)
          ..add(br)
          ..add(tl)
          ..add(br)
          ..add(bl);
        texCoords
          ..add(Offset(u0, 0))
          ..add(Offset(u1, 0))
          ..add(Offset(u1, imgH))
          ..add(Offset(u0, 0))
          ..add(Offset(u1, imgH))
          ..add(Offset(u0, imgH));
      }

      final ui.Vertices vertices = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texCoords,
      );
      canvas.drawVertices(
        vertices,
        BlendMode.srcOver,
        Paint()
          ..shader = ui.ImageShader(
            img,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
            filterQuality: FilterQuality.medium,
          ),
      );
    } else {
      // Vector fallback identical to `LV_NEO ✦ — Tech For Luxury Experiences`
      final Offset midLeft = Offset(
        (topPts.first.x + botPts.first.x) * 0.5,
        (topPts.first.y + botPts.first.y) * 0.5,
      );
      final Offset midRight = Offset(
        (topPts.last.x + botPts.last.x) * 0.5,
        (topPts.last.y + botPts.last.y) * 0.5,
      );
      canvas.drawLine(
        Offset.lerp(midLeft, midRight, 0.16)!,
        Offset.lerp(midLeft, midRight, 0.84)!,
        Paint()
          ..color = _kLvNeoCobalt
          ..strokeWidth = (pTest.scale * 0.26).clamp(1.6, 8.0)
          ..strokeCap = StrokeCap.round,
      );
      final Offset starPt = Offset.lerp(
        Offset(topPts[strips ~/ 2].x, topPts[strips ~/ 2].y),
        midRight,
        isLeft ? 0.65 : 0.35,
      )!;
      canvas.drawCircle(
        starPt,
        (pTest.scale * 0.18).clamp(1.2, 4.8),
        Paint()..color = _kLvNeoCobalt,
      );
    }

    // Cobalt Blue `#1638E8` & 24K Gold `#FFD700` luxury banner trim
    canvas.drawPath(
      quadOutline,
      Paint()
        ..color = _kLvNeoCobalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = (topPts.first.scale * 0.11).clamp(1.1, 3.2)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(topPts.first.x, topPts.first.y),
      Offset(topPts.last.x, topPts.last.y),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = (topPts.first.scale * 0.08).clamp(1.0, 2.5),
    );

    // Near mast (if unclipped) drawn in front!
    if (uClip0 <= 0.02) {
      _paintLvNeoMastPost(
        canvas,
        project(x0, 0.0, z0),
        project(x0, yMastTop, z0),
      );
    }
  }

  void _paintLvNeoMastPost(
    Canvas canvas,
    _ProjectedPoint3D base,
    _ProjectedPoint3D top,
  ) {
    final double postW = (base.scale * 0.16).clamp(1.4, 5.2);
    canvas.drawLine(
      Offset(base.x, base.y),
      Offset(top.x, top.y),
      Paint()
        ..color = _kOutline
        ..strokeWidth = postW + 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(base.x, base.y),
      Offset(top.x, top.y),
      Paint()
        ..color = _kLvNeoCobalt
        ..strokeWidth = postW
        ..strokeCap = StrokeCap.round,
    );
    // 24K Gold finial sphere on top of mast
    final double finialR = (top.scale * 0.20).clamp(1.8, 6.2);
    canvas.drawCircle(
      Offset(top.x, top.y),
      finialR,
      Paint()..color = const Color(0xFFFFD700),
    );
    canvas.drawCircle(
      Offset(top.x, top.y),
      finialR,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (top.scale * 0.06).clamp(0.8, 1.8),
    );
  }

  /// Infinite Oblique Alpine Chairlift & Gondola System (`SkiPropKind.cableCarPylon`)
  /// crossing diagonally across the mountain valley (`worldX` `-380m..+380m`) from edge to edge!
  void _paintCableCarSystem3D(
    Canvas canvas,
    SkiTrackId track,
    double camZ,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final double skewSlope =
        track == SkiTrackId.blueAsnieresForest ? -0.56 : 0.56;
    final double zClip = camZ + 6.5;
    final double actorZMin = camZ + 14.0;
    final double cableZFarMax = camZ + 420.0;
    final double actorZFarMax = camZ + 240.0;

    const List<double> pylonOffsets = <double>[
      -135.0,
      -78.0,
      -28.0,
      28.0,
      78.0,
      135.0,
    ];

    double pylonTopHeightAtDx(double dx) =>
        (19.0 - dx * (skewSlope > 0 ? 0.16 : -0.16)).clamp(7.8, 42.0);

    double cableHeightAtDx(double dx) {
      double sag = 0.0;
      if (dx <= pylonOffsets.first) {
        final double u = ((dx - (-380.0)) / (pylonOffsets.first - (-380.0)))
            .clamp(0.0, 1.0);
        sag = 4.0 * u * (1.0 - u) * 0.34;
      } else if (dx >= pylonOffsets.last) {
        final double u =
            ((dx - pylonOffsets.last) / (380.0 - pylonOffsets.last))
                .clamp(0.0, 1.0);
        sag = 4.0 * u * (1.0 - u) * 0.34;
      } else {
        for (int i = 0; i < pylonOffsets.length - 1; i++) {
          final double a = pylonOffsets[i];
          final double b = pylonOffsets[i + 1];
          if (dx >= a && dx <= b) {
            final double u = (dx - a) / (b - a);
            sag = 4.0 * u * (1.0 - u) * 0.50;
            break;
          }
        }
      }
      return pylonTopHeightAtDx(dx) - sag;
    }

    // 1. Continuous Infinite Uphill (`+1.8m` Z) & Downhill (`-1.8m` Z) Steel Haul Cables
    // spanning `-380m..+380m` with exact 3D near-plane clipping (`zClip = camZ + 1.65`)
    // so cables always exit cleanly past the left/right/top screen boundaries!
    for (final double laneZOffset in const <double>[1.8, -1.8]) {
      const double stepDx = 10.0;
      for (double dx0 = -380.0; dx0 < 380.0; dx0 += stepDx) {
        final double dx1 = math.min(380.0, dx0 + stepDx);
        double x0 = prop.x + dx0;
        double y0 = cableHeightAtDx(dx0);
        double z0 = prop.z + dx0 * skewSlope + laneZOffset;

        double x1 = prop.x + dx1;
        double y1 = cableHeightAtDx(dx1);
        double z1 = prop.z + dx1 * skewSlope + laneZOffset;

        if ((z0 < zClip && z1 < zClip) ||
            (z0 > cableZFarMax && z1 > cableZFarMax)) {
          continue;
        }
        if (z0 < zClip) {
          final double t = (zClip - z0) / (z1 - z0);
          x0 = x0 + (x1 - x0) * t;
          y0 = y0 + (y1 - y0) * t;
          z0 = zClip;
        } else if (z1 < zClip) {
          final double t = (zClip - z0) / (z1 - z0);
          x1 = x0 + (x1 - x0) * t;
          y1 = y0 + (y1 - y0) * t;
          z1 = zClip;
        }

        final _ProjectedPoint3D p0 = project(x0, y0, z0);
        final _ProjectedPoint3D p1 = project(x1, y1, z1);
        final double avgScale = (p0.scale + p1.scale) * 0.5;

        canvas.drawLine(
          Offset(p0.x, p0.y),
          Offset(p1.x, p1.y),
          Paint()
            ..color = laneZOffset > 0
                ? const Color(0xFF263238)
                : const Color(0xFF1C262B)
            ..strokeWidth = (avgScale * 0.095).clamp(1.1, 3.2)
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 2. Collect 6 Steel Lattice 3D Pylons + 20 Circulating Carriers (10 Uphill, 10 Downhill)
    // and sort them strictly back-to-front by world Z!
    final List<(double zSort, bool isPylon, double dx, int slotIndex)>
        liftActors = <(double, bool, double, int)>[];

    for (int i = 0; i < pylonOffsets.length; i++) {
      final double dx = pylonOffsets[i];
      final double pz = prop.z + dx * skewSlope;
      if (pz >= actorZMin && pz <= actorZFarMax) {
        liftActors.add((pz, true, dx, i));
      }
    }

    // 8 Uphill carriers (`+1.8m` Z) + 8 Downhill carriers (`-1.8m` Z) across `-160m..+160m`
    for (int i = 0; i < 16; i++) {
      final bool isUphill = i < 8;
      final int laneIdx = i % 8;
      final double phase = (engine.ambientTime * 0.042 +
              prop.variant * 0.17 +
              laneIdx * 0.125 +
              (isUphill ? 0.0 : 0.06)) %
          1.0;
      final double dx = isUphill
          ? (-160.0 + phase * 320.0)
          : (160.0 - phase * 320.0);
      final double laneZOffset = isUphill ? 1.8 : -1.8;
      final double cz = prop.z + dx * skewSlope + laneZOffset;
      if (cz >= actorZMin && cz <= actorZFarMax) {
        liftActors.add((cz, false, dx, i));
      }
    }

    liftActors.sort(
      ((double, bool, double, int) a, (double, bool, double, int) b) =>
          b.$1.compareTo(a.$1),
    );

    for (final (double zWorld, bool isPylon, double dx, int slotIdx)
        in liftActors) {
      if (isPylon) {
        final double px = prop.x + dx;
        final double topY = pylonTopHeightAtDx(dx);
        final _ProjectedPoint3D b = project(px, 0.0, zWorld);
        final _ProjectedPoint3D t = project(px, topY, zWorld);
        if (b.scale < 0.45) continue;

        // Snow concrete pedestal shadow
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(b.x, b.y + b.scale * 0.06),
            width: (b.scale * 2.1).clamp(3.0, 26.0),
            height: (b.scale * 0.65).clamp(1.5, 9.0),
          ),
          Paint()..color = const Color(0xFF1A3B5C).withValues(alpha: 0.22),
        );

        final double baseSpread = (b.scale * 0.72).clamp(1.6, 13.0);
        final double topSpread = (t.scale * 0.26).clamp(1.0, 5.5);
        final Paint legPaint = Paint()
          ..color = const Color(0xFF37474F)
          ..strokeWidth = (b.scale * 0.13).clamp(1.1, 3.8)
          ..strokeCap = StrokeCap.round;

        final Offset bl = Offset(b.x - baseSpread, b.y);
        final Offset br = Offset(b.x + baseSpread, b.y);
        final Offset tl = Offset(t.x - topSpread, t.y);
        final Offset tr = Offset(t.x + topSpread, t.y);
        canvas.drawLine(bl, tl, legPaint);
        canvas.drawLine(br, tr, legPaint);

        // Steel X-lattice cross-bracing along pylon height
        final Paint bracePaint = Paint()
          ..color = const Color(0xFF546E7A)
          ..strokeWidth = (b.scale * 0.065).clamp(0.8, 2.0);
        for (int seg = 0; seg < 3; seg++) {
          final double f0 = seg / 3.0;
          final double f1 = (seg + 1) / 3.0;
          canvas.drawLine(
            Offset.lerp(bl, tl, f0)!,
            Offset.lerp(br, tr, f1)!,
            bracePaint,
          );
          canvas.drawLine(
            Offset.lerp(br, tr, f0)!,
            Offset.lerp(bl, tl, f1)!,
            bracePaint,
          );
        }

        // Oblique 3D Crosshead Beam & Golden Pulley Sheaves supporting both `+1.6m` and `-1.6m` cables
        final _ProjectedPoint3D armUp =
            project(px, topY, math.max(zClip, zWorld + 1.75));
        final _ProjectedPoint3D armDown =
            project(px, topY, math.max(zClip, zWorld - 1.75));
        final Offset crossA = Offset(armUp.x - topSpread * 1.4, armUp.y);
        final Offset crossB = Offset(armDown.x + topSpread * 1.4, armDown.y);
        canvas.drawLine(
          crossA,
          crossB,
          Paint()
            ..color = const Color(0xFF263238)
            ..strokeWidth = (t.scale * 0.20).clamp(1.6, 4.8)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          crossA,
          crossB,
          Paint()
            ..color = const Color(0xFFFFD700)
            ..strokeWidth = (t.scale * 0.11).clamp(1.0, 2.8)
            ..strokeCap = StrokeCap.round,
        );
        for (final _ProjectedPoint3D sheave in <_ProjectedPoint3D>[
          project(px, topY, math.max(zClip, zWorld + 1.6)),
          project(px, topY, math.max(zClip, zWorld - 1.6)),
        ]) {
          canvas.drawCircle(
            Offset(sheave.x, sheave.y),
            (sheave.scale * 0.18).clamp(1.2, 4.4),
            Paint()..color = const Color(0xFFD32F2F),
          );
        }
      } else {
        // Circulating Chairlift / Gondola Cabin (`slotIdx` 0..7 uphill, 8..15 downhill)
        final bool isUphill = slotIdx < 8;
        final double cx = prop.x + dx;
        final double cableY = cableHeightAtDx(dx);
        final _ProjectedPoint3D hangerTop = project(cx, cableY, zWorld);
        final _ProjectedPoint3D cabCenter =
            project(cx, cableY - 1.65, zWorld);
        final double cs = cabCenter.scale * 1.25;
        if (cs < 0.55) continue;

        final double sway =
            math.sin(engine.ambientTime * 2.5 + slotIdx * 1.35) * 0.065;
        canvas.save();
        canvas.translate(hangerTop.x, hangerTop.y);
        canvas.rotate(sway);

        final double drop = (cabCenter.y - hangerTop.y).clamp(3.2, 48.0);
        // Cable grip clamp & curved suspension arm
        canvas.drawCircle(
          Offset.zero,
          (cs * 0.12).clamp(1.0, 3.0),
          Paint()..color = const Color(0xFFFFD700),
        );
        canvas.drawLine(
          Offset.zero,
          Offset(0, drop * 0.72),
          Paint()
            ..color = _kOutline
            ..strokeWidth = (cs * 0.095).clamp(1.0, 2.6),
        );

        final bool isChairStyle = prop.id.isOdd;
        if (isChairStyle) {
          // Open 4-Seater Panoramic Chairlift with Bubble Hood & Seated Skiers!
          final Rect benchRect = Rect.fromCenter(
            center: Offset(0, drop),
            width: cs * 2.15,
            height: cs * 1.15,
          );
          // Tinted wind-bubble canopy
          canvas.drawArc(
            benchRect.inflate(cs * 0.12),
            math.pi,
            math.pi,
            true,
            Paint()
              ..color = (isUphill ? _kLvNeoCobalt : const Color(0xFFD32F2F))
                  .withValues(alpha: 0.85),
          );
          // Bench seat + safety bar
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, drop + cs * 0.28),
                width: cs * 2.15,
                height: cs * 0.36,
              ),
              Radius.circular(cs * 0.12),
            ),
            Paint()..color = const Color(0xFF263238),
          );
          if (isUphill) {
            // Two cheerful uphill passenger silhouettes with mini skis!
            for (final double sxOff in const <double>[-0.45, 0.45]) {
              canvas.drawCircle(
                Offset(cs * sxOff, drop - cs * 0.05),
                (cs * 0.22).clamp(1.0, 4.8),
                Paint()
                  ..color = sxOff < 0
                      ? const Color(0xFFFFD700)
                      : const Color(0xFFFF4081),
              );
              canvas.drawLine(
                Offset(cs * (sxOff - 0.24), drop + cs * 0.62),
                Offset(cs * (sxOff + 0.24), drop + cs * 0.56),
                Paint()
                  ..color = Colors.white
                  ..strokeWidth = (cs * 0.08).clamp(0.9, 2.0),
              );
            }
          }
          // 24K Gold safety bar
          canvas.drawLine(
            Offset(-cs * 1.02, drop + cs * 0.10),
            Offset(cs * 1.02, drop + cs * 0.10),
            Paint()
              ..color = const Color(0xFFFFD700)
              ..strokeWidth = (cs * 0.09).clamp(0.9, 2.2),
          );
        } else {
          // Luxury Alpine Red / LV Cobalt Gondola Cabin with 24K Gold belt
          final Rect cabinRect = Rect.fromCenter(
            center: Offset(0, drop),
            width: cs * 2.15,
            height: cs * 1.58,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(cabinRect, Radius.circular(cs * 0.34)),
            Paint()
              ..color = isUphill ? const Color(0xFFD32F2F) : _kLvNeoCobalt,
          );
          canvas.drawLine(
            Offset(
              cabinRect.left + 1,
              cabinRect.center.dy + cabinRect.height * 0.14,
            ),
            Offset(
              cabinRect.right - 1,
              cabinRect.center.dy + cabinRect.height * 0.14,
            ),
            Paint()
              ..color = const Color(0xFFFFD700)
              ..strokeWidth = (cs * 0.13).clamp(1.0, 2.8),
          );
          final Rect glass = Rect.fromCenter(
            center: Offset(0, drop - cabinRect.height * 0.12),
            width: cabinRect.width * 0.74,
            height: cabinRect.height * 0.44,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(glass, Radius.circular(cs * 0.16)),
            Paint()..color = const Color(0xFFB3E5FC),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(cabinRect, Radius.circular(cs * 0.34)),
            Paint()
              ..color = _kOutline
              ..style = PaintingStyle.stroke
              ..strokeWidth = (cs * 0.095).clamp(0.9, 2.4),
          );
        }
        canvas.restore();
      }
    }
  }

  /// Cheerful Waving Cartoon Snowman (`SkiPropKind.cartoonSnowman`) with LV Scarf, Carrot & Top Hat
  void _paintCartoonSnowman3D(
    Canvas canvas,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final _ProjectedPoint3D base = project(prop.x, 0.0, prop.z);
    final double s = base.scale * prop.scale;
    if (s < 1.0) return;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.x, base.y + s * 0.08),
        width: s * 1.9,
        height: s * 0.52,
      ),
      Paint()..color = const Color(0xFF1A3B5C).withValues(alpha: 0.24),
    );

    final Paint outline = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.09).clamp(1.0, 2.4);

    final Offset bottomC = Offset(base.x, base.y - s * 0.68);
    final Offset midC = Offset(base.x, base.y - s * 1.56);
    final Offset headC = Offset(base.x, base.y - s * 2.28);

    // Animated waving twig arms!
    final double wave = math.sin(engine.ambientTime * 6.2 + prop.id) * 0.42;
    final Paint twigPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = (s * 0.10).clamp(1.2, 2.8)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      midC + Offset(-s * 0.48, -s * 0.05),
      midC + Offset(-s * 1.08, -s * (0.55 + wave * 0.55)),
      twigPaint,
    );
    canvas.drawLine(
      midC + Offset(s * 0.48, -s * 0.05),
      midC + Offset(s * 1.08, -s * (0.55 - wave * 0.55)),
      twigPaint,
    );

    // 3 plump snow spheres
    for (final (Offset c, double r) in <(Offset, double)>[
      (bottomC, s * 0.72),
      (midC, s * 0.54),
      (headC, s * 0.42),
    ]) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-r * 0.25, -r * 0.25),
            r * 1.3,
            const <Color>[Colors.white, Color(0xFFE1F5FE)],
          ),
      );
      canvas.drawCircle(c, r, outline);
    }

    // Golden buttons on tummy
    for (final double by in <double>[-0.14, 0.14]) {
      canvas.drawCircle(
        midC + Offset(0, s * by),
        (s * 0.08).clamp(1.0, 2.6),
        Paint()..color = const Color(0xFFFFD700),
      );
    }

    // Warm fluttering LV Scarf (alternating Cobalt `LV_NEO` and Crimson)
    final Color scarfCol =
        prop.variant.isEven ? _kLvNeoCobalt : const Color(0xFFD91E48);
    final Rect scarfNeck = Rect.fromCenter(
      center: Offset(headC.dx, headC.dy + s * 0.38),
      width: s * 0.76,
      height: s * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scarfNeck, Radius.circular(s * 0.08)),
      Paint()..color = scarfCol,
    );
    canvas.drawLine(
      Offset(headC.dx + s * 0.20, headC.dy + s * 0.42),
      Offset(
        headC.dx + s * (0.55 + wave * 0.35),
        headC.dy + s * 0.88,
      ),
      Paint()
        ..color = scarfCol
        ..strokeWidth = (s * 0.18).clamp(1.4, 4.2)
        ..strokeCap = StrokeCap.round,
    );

    // Eyes & Orange 3D Carrot Nose
    canvas.drawCircle(
      headC + Offset(-s * 0.14, -s * 0.08),
      (s * 0.06).clamp(0.9, 2.2),
      Paint()..color = _kOutline,
    );
    canvas.drawCircle(
      headC + Offset(s * 0.14, -s * 0.08),
      (s * 0.06).clamp(0.9, 2.2),
      Paint()..color = _kOutline,
    );
    final Path carrot = Path()
      ..moveTo(headC.dx, headC.dy + s * 0.02)
      ..lineTo(headC.dx + s * 0.44, headC.dy + s * 0.08)
      ..lineTo(headC.dx, headC.dy + s * 0.14)
      ..close();
    canvas.drawPath(carrot, Paint()..color = const Color(0xFFFF6D00));

    // Top Hat with 24K Gold Ribbon
    canvas.drawLine(
      Offset(headC.dx - s * 0.46, headC.dy - s * 0.36),
      Offset(headC.dx + s * 0.46, headC.dy - s * 0.36),
      Paint()
        ..color = _kOutline
        ..strokeWidth = (s * 0.12).clamp(1.4, 3.4)
        ..strokeCap = StrokeCap.round,
    );
    final Rect hatCrown = Rect.fromCenter(
      center: Offset(headC.dx, headC.dy - s * 0.64),
      width: s * 0.56,
      height: s * 0.52,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hatCrown, Radius.circular(s * 0.06)),
      Paint()..color = const Color(0xFF2B1D14),
    );
    canvas.drawLine(
      Offset(hatCrown.left, hatCrown.bottom - s * 0.08),
      Offset(hatCrown.right, hatCrown.bottom - s * 0.08),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = (s * 0.10).clamp(1.0, 2.6),
    );
  }

  /// Festive Fluttering Multi-Color Pennant Mast & Cheering Supporter (`SkiPropKind.flutteringPennantPost`)
  void _paintFlutteringPennantAndSupporter3D(
    Canvas canvas,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final _ProjectedPoint3D base = project(prop.x, 0.0, prop.z);
    final _ProjectedPoint3D top = project(prop.x, 4.4, prop.z);
    final double s = base.scale;
    if (s < 0.95) return;

    final double dir = prop.x < engine.trackCenterOffsetX(prop.z) ? -1.0 : 1.0;

    // Tall white/gold mast
    canvas.drawLine(
      Offset(base.x, base.y),
      Offset(top.x, top.y),
      Paint()
        ..color = _kOutline
        ..strokeWidth = (s * 0.15).clamp(1.5, 4.2)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(base.x, base.y),
      Offset(top.x, top.y),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = (s * 0.09).clamp(1.0, 2.6)
        ..strokeCap = StrokeCap.round,
    );

    // 3 Large Rippling Festive Pennants
    const List<Color> colors = <Color>[
      _kLvNeoCobalt,
      Color(0xFFFF4081),
      Color(0xFF00E676),
    ];
    for (int f = 0; f < 3; f++) {
      final double yAnchor = top.y + (base.y - top.y) * (0.06 + f * 0.22);
      final double wave =
          math.sin(engine.ambientTime * 6.5 + prop.id + f * 1.4) * s * 0.22;
      final Path flag = Path()
        ..moveTo(top.x, yAnchor)
        ..quadraticBezierTo(
          top.x + dir * s * 0.95,
          yAnchor + s * 0.12 + wave,
          top.x + dir * s * 1.85,
          yAnchor + s * 0.24 - wave * 0.6,
        )
        ..lineTo(top.x, yAnchor + s * 0.56)
        ..close();
      canvas.drawPath(flag, Paint()..color = colors[(prop.variant + f) % colors.length]);
      canvas.drawPath(
        flag,
        Paint()
          ..color = _kOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s * 0.06).clamp(0.8, 1.8),
      );
    }

    // Bouncing Cartoon Alpine Supporter cheering next to the mast!
    final double hop =
        math.sin(engine.ambientTime * 5.8 + prop.id).abs() * s * 0.35;
    final Offset supBase = Offset(base.x + dir * s * 0.95, base.y - hop);
    final Color jacketColor = prop.variant.isEven
        ? const Color(0xFFFF6D00)
        : const Color(0xFF00B0FF);

    // Puffer jacket body
    final RRect torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: supBase + Offset(0, -s * 0.68),
        width: s * 0.72,
        height: s * 0.88,
      ),
      Radius.circular(s * 0.24),
    );
    canvas.drawRRect(torso, Paint()..color = jacketColor);
    canvas.drawRRect(
      torso,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.07).clamp(0.9, 2.0),
    );
    // Raised cheering arms
    final Paint armP = Paint()
      ..color = jacketColor
      ..strokeWidth = (s * 0.16).clamp(1.2, 3.6)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      supBase + Offset(-s * 0.28, -s * 0.85),
      supBase + Offset(-s * 0.62, -s * 1.45),
      armP,
    );
    canvas.drawLine(
      supBase + Offset(s * 0.28, -s * 0.85),
      supBase + Offset(s * 0.62, -s * 1.45),
      armP,
    );
    // Head & pom-pom beanie
    final Offset supHead = supBase + Offset(0, -s * 1.30);
    canvas.drawCircle(supHead, s * 0.26, Paint()..color = const Color(0xFFFFCCBC));
    canvas.drawArc(
      Rect.fromCircle(center: supHead, radius: s * 0.28),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFD50000),
    );
    canvas.drawCircle(
      supHead + Offset(0, -s * 0.34),
      s * 0.11,
      Paint()..color = Colors.white,
    );
  }

  /// Active Yellow & Cobalt Snow Cannon (`SkiPropKind.snowCannon`) spraying snow crystals!
  void _paintSnowCannon3D(
    Canvas canvas,
    SkiTrackId track,
    SkiWorldProp3D prop,
    _ProjectedPoint3D Function(double x, double y, double z) project,
  ) {
    final _ProjectedPoint3D base = project(prop.x, 0.0, prop.z);
    final double s = base.scale;
    if (s < 0.95) return;

    // Aim inward/upward toward the piste shoulder
    final double aimDir = prop.x > engine.trackCenterOffsetX(prop.z) ? -1.0 : 1.0;

    // Tripod legs on snow mound
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.x, base.y),
        width: s * 2.1,
        height: s * 0.58,
      ),
      Paint()..color = Colors.white,
    );
    final Paint legPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = (s * 0.13).clamp(1.2, 3.4)
      ..strokeCap = StrokeCap.round;
    final Offset pivot = Offset(base.x, base.y - s * 0.78);
    canvas.drawLine(pivot, Offset(base.x - s * 0.68, base.y), legPaint);
    canvas.drawLine(pivot, Offset(base.x + s * 0.68, base.y), legPaint);

    // Cannon barrel (Yellow `#FFB300` & Cobalt `#1565C0`)
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(aimDir * -0.48);

    final RRect barrel = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(aimDir * s * 0.22, -s * 0.18),
        width: s * 1.48,
        height: s * 0.82,
      ),
      Radius.circular(s * 0.28),
    );
    canvas.drawRRect(barrel, Paint()..color = const Color(0xFFFFB300));
    canvas.drawRRect(
      barrel,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.09).clamp(1.0, 2.4),
    );
    // Cobalt nozzle ring
    final Offset nozzle = Offset(aimDir * s * 0.92, -s * 0.18);
    canvas.drawOval(
      Rect.fromCenter(center: nozzle, width: s * 0.34, height: s * 0.78),
      Paint()..color = const Color(0xFF1565C0),
    );
    canvas.restore();

    // Continuous Animated Jet Plume of Sparkling Snow Crystals!
    final Offset jetOrigin = pivot + Offset(aimDir * s * 0.95, -s * 0.62);
    for (int p = 0; p < 10; p++) {
      final double u = ((engine.ambientTime * 2.4 + p * 0.10 + prop.id * 0.17) % 1.0);
      final double spread = math.sin(p * 2.3 + engine.ambientTime * 5.0) * s * 0.55 * u;
      final Offset crystalPt = jetOrigin +
          Offset(
            aimDir * u * s * 3.8,
            -u * s * 2.35 + u * u * s * 0.85 + spread,
          );
      final double r = (s * (0.14 + u * 0.26)).clamp(1.2, 7.5);
      canvas.drawCircle(
        crystalPt,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: (1.0 - u * 0.78) * 0.82),
      );
    }
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
      ..color = isFinish ? const Color(0xFF8B1E24) : _kLvNeoCobalt
      ..strokeWidth = postW
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(lBase.x, lBase.y), Offset(lTop.x, lTop.y), pillarPaint);
    canvas.drawLine(Offset(rBase.x, rBase.y), Offset(rTop.x, rTop.y), pillarPaint);

    final Rect bannerRect = Rect.fromLTRB(
      lTop.x - postW * 0.4,
      lTop.y - lTop.scale * 1.45,
      rTop.x + postW * 0.4,
      rTop.y + rTop.scale * 0.25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, Radius.circular(lTop.scale * 0.3)),
      Paint()..color = isFinish ? const Color(0xFF8B1E24) : Colors.white,
    );
    if (!isFinish && lvNeoBannerImage != null && bannerRect.width > 24) {
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(bannerRect, Radius.circular(lTop.scale * 0.3)),
      );
      canvas.drawImageRect(
        lvNeoBannerImage!,
        Rect.fromLTWH(
          0,
          0,
          lvNeoBannerImage!.width.toDouble(),
          lvNeoBannerImage!.height.toDouble(),
        ),
        bannerRect.deflate(bannerRect.height * 0.08),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, Radius.circular(lTop.scale * 0.3)),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (lTop.scale * 0.16).clamp(1.5, 4.2),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Vivienne 3D Cycles Skier (`BLENDER_LAB` 3 Editions + Bonus 360°/Flip + Snowball Crash!)
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

    // Special Cartoon 3D Snowball Crash State (`VivienneSkiAnimState.snowballCrash`)!
    if (engine.isInSnowballCrash) {
      _paintSnowballCrash3D(canvas, s, groundPt, skierPt, edition);
      return;
    }

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

    final SkiAerialTrickKind trick =
        isAirborne ? engine.currentAerialTrick : SkiAerialTrickKind.none;

    // 4.2 Real-Time 3D Volumetric & 22-Bone Skeletal Vivienne Renderer (v1.3.0)
    // Zero 2D flat sprite squishing (`horizSpinScale` removed) and zero 2D canvas flip!
    canvas.save();
    canvas.translate(skierPt.x, skierPt.y);

    if (trick == SkiAerialTrickKind.sautPerilleux) {
      final Offset pivot = Offset(0, -s * 1.78);
      _paintSomersaultFlipTrail(
        canvas,
        s,
        pivot,
        engine.trickFlipAngle,
        engine.trickProgress,
      );
      Vivienne3DVolumetricRig.paintSkierOnSlope(
        canvas: canvas,
        engine: engine,
        soleAnchorScreen: Offset.zero,
        unitScalePx: s,
      );
    } else if (trick == SkiAerialTrickKind.saut360) {
      final double yaw = engine.trickSpinAngle;
      _paintSpin360Halo(canvas, s, yaw, isFrontHalf: false);
      Vivienne3DVolumetricRig.paintSkierOnSlope(
        canvas: canvas,
        engine: engine,
        soleAnchorScreen: Offset.zero,
        unitScalePx: s,
      );
      _paintSpin360Halo(canvas, s, yaw, isFrontHalf: true);
    } else {
      Vivienne3DVolumetricRig.paintSkierOnSlope(
        canvas: canvas,
        engine: engine,
        soleAnchorScreen: Offset.zero,
        unitScalePx: s,
      );
    }

    canvas.restore();
  }

  void _paintSpin360Halo(
    Canvas canvas,
    double s,
    double yaw, {
    required bool isFrontHalf,
  }) {
    final double edgeGlow = 1.0 - math.cos(yaw).abs();
    final Rect orbit = Rect.fromCenter(
      center: Offset(0, -s * 1.85),
      width: s * 3.55,
      height: s * 0.92,
    );
    final double startAngle = isFrontHalf ? 0.0 : math.pi;
    canvas.drawArc(
      orbit,
      startAngle,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFFFD700)
            .withValues(alpha: (0.42 + edgeGlow * 0.45).clamp(0.0, 0.92))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * (0.11 + edgeGlow * 0.10)).clamp(1.4, 5.2)
        ..strokeCap = StrokeCap.round,
    );

    if (isFrontHalf) {
      for (int i = 0; i < 3; i++) {
        final double ang = yaw + i * (2.0 * math.pi / 3.0);
        if (math.sin(ang) < 0) continue;
        final Offset starCenter = Offset(
          orbit.center.dx + math.cos(ang) * orbit.width * 0.5,
          orbit.center.dy + math.sin(ang) * orbit.height * 0.5,
        );
        _paintSparkleStar4(
          canvas,
          starCenter,
          (s * (0.24 + edgeGlow * 0.10)).clamp(2.5, 9.5),
          i.isEven ? const Color(0xFFFFD700) : const Color(0xFF80D8FF),
        );
      }
    }
  }

  void _paintSomersaultFlipTrail(
    Canvas canvas,
    double s,
    Offset pivot,
    double flipAngle,
    double flipProgress,
  ) {
    final double radius = s * 2.05;
    final Rect arcRect = Rect.fromCircle(center: pivot, radius: radius);
    final double sweep = math.min(math.pi * 1.35, flipAngle + 0.35);

    canvas.drawArc(
      arcRect,
      -flipAngle - math.pi * 0.5,
      sweep,
      false,
      Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.14).clamp(1.8, 5.4)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      arcRect.deflate(s * 0.22),
      -flipAngle - math.pi * 0.5,
      sweep * 0.82,
      false,
      Paint()
        ..color = const Color(0xFFFF4081).withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.08).clamp(1.2, 3.2)
        ..strokeCap = StrokeCap.round,
    );

    for (int i = 0; i < 4; i++) {
      final double a = -flipAngle - math.pi * 0.5 + sweep * (i / 3.0);
      final Offset sc = pivot + Offset(math.cos(a) * radius, math.sin(a) * radius);
      _paintSparkleStar4(
        canvas,
        sc,
        (s * (0.28 - i * 0.04)).clamp(2.4, 9.5),
        i.isEven ? const Color(0xFFFFD700) : Colors.white,
      );
    }
  }

  void _paintSparkleStar4(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
  ) {
    final Path star = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.20, c.dy - r * 0.20, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.20, c.dy + r * 0.20, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.20, c.dy + r * 0.20, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.20, c.dy - r * 0.20, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(star, Paint()..color = color);
  }

  /// Cartoon 3D Rolling Snowball Crash (`rayon 1.1x -> 1.55x`, `360° × 3` tumble)
  /// with Vivienne's skis, sneakers/feet, corolla petals & accessories sticking out!
  void _paintSnowballCrash3D(
    Canvas canvas,
    double s,
    _ProjectedPoint3D groundPt,
    _ProjectedPoint3D skierPt,
    VivienneSkiEdition edition,
  ) {
    final double growth = 1.10 + 0.45 * engine.snowballCrashProgress;
    final double ballR = s * 1.48 * growth;

    // Expanding ground shadow beneath the giant rolling snowball
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(groundPt.x, groundPt.y + s * 0.14),
        width: ballR * 2.15,
        height: ballR * 0.62,
      ),
      Paint()..color = const Color(0xFF14283C).withValues(alpha: 0.38),
    );

    canvas.save();
    canvas.translate(skierPt.x, skierPt.y - ballR * 0.88);

    // 1. Spinning 360° background limbs, skis, poles & petals protruding out of the snowball!
    canvas.save();
    canvas.rotate(engine.snowballRotationRadians);

    final Paint stroke = Paint()
      ..color = _kOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.09).clamp(1.3, 2.8)
      ..strokeJoin = StrokeJoin.round;

    // Protruding Parabolic Skis at comical asymmetric angles
    for (final double skiAng in const <double>[0.62, -2.35]) {
      canvas.save();
      canvas.rotate(skiAng);
      final RRect skiBlade = RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * 0.19, ballR * 0.64, s * 0.38, ballR * 1.06),
        Radius.circular(s * 0.15),
      );
      canvas.drawRRect(skiBlade, Paint()..color = edition.skiDeckColor);
      canvas.drawRRect(
        skiBlade,
        Paint()
          ..color = edition.skiAccentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s * 0.065).clamp(1.2, 2.5),
      );
      canvas.drawRRect(skiBlade, stroke);
      canvas.restore();
    }

    // Protruding 24K Gold Ski Poles with Star Blossom baskets
    for (final double poleAng in const <double>[1.95, -0.92]) {
      canvas.save();
      canvas.rotate(poleAng);
      canvas.drawLine(
        Offset(0, ballR * 0.65),
        Offset(0, ballR * 1.56),
        Paint()
          ..color = const Color(0xFFFFD700)
          ..strokeWidth = (s * 0.095).clamp(1.5, 3.2)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(0, ballR * 1.38),
        (s * 0.18).clamp(2.2, 6.0),
        Paint()..color = edition.trimEdgeColor,
      );
      canvas.restore();
    }

    // Protruding Corolla Petals (`edition.petalColor`) with Monogram star motifs
    for (final double petAng in const <double>[-0.22, 2.72]) {
      final Offset pCenter = Offset(
        math.cos(petAng) * ballR * 1.12,
        math.sin(petAng) * ballR * 1.12,
      );
      canvas.drawCircle(
        pCenter,
        s * 0.68,
        Paint()..color = edition.petalColor,
      );
      canvas.drawCircle(pCenter, s * 0.68, stroke);
      canvas.drawCircle(
        pCenter,
        s * 0.52,
        Paint()
          ..color = edition.stitchGoldColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s * 0.05).clamp(1.0, 2.0),
      );
      final double mr = s * 0.24;
      final Path star = Path()
        ..moveTo(pCenter.dx, pCenter.dy - mr)
        ..quadraticBezierTo(
          pCenter.dx + mr * 0.22,
          pCenter.dy - mr * 0.22,
          pCenter.dx + mr,
          pCenter.dy,
        )
        ..quadraticBezierTo(
          pCenter.dx + mr * 0.22,
          pCenter.dy + mr * 0.22,
          pCenter.dx,
          pCenter.dy + mr,
        )
        ..quadraticBezierTo(
          pCenter.dx - mr * 0.22,
          pCenter.dy + mr * 0.22,
          pCenter.dx - mr,
          pCenter.dy,
        )
        ..quadraticBezierTo(
          pCenter.dx - mr * 0.22,
          pCenter.dy - mr * 0.22,
          pCenter.dx,
          pCenter.dy - mr,
        )
        ..close();
      canvas.drawPath(
        star,
        Paint()..color = edition.motifColor.withValues(alpha: 0.90),
      );
    }

    // Protruding Feet (Fuchsia Sneakers for Giant Denim, Oak Wood boots otherwise)
    for (final double footAng in const <double>[1.25, -1.65]) {
      canvas.save();
      canvas.rotate(footAng);
      final RRect footRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, ballR * 1.24),
          width: s * 0.48,
          height: s * 0.56,
        ),
        Radius.circular(s * 0.15),
      );
      canvas.drawRRect(
        footRect,
        Paint()
          ..color = edition == VivienneSkiEdition.giantDenim
              ? const Color(0xFFE31C58)
              : const Color(0xFFC89D7C),
      );
      if (edition == VivienneSkiEdition.giantDenim) {
        canvas.drawLine(
          Offset(-s * 0.22, ballR * 1.44),
          Offset(s * 0.22, ballR * 1.44),
          Paint()
            ..color = Colors.white
            ..strokeWidth = (s * 0.11).clamp(1.4, 3.0),
        );
      }
      canvas.drawRRect(footRect, stroke);
      canvas.restore();
    }

    // Edition-specific accessory poking out of the tumbling snowball!
    if (edition == VivienneSkiEdition.wonderland) {
      // Red Lacquered Heart Balloon + White Bunny Ears poking out!
      for (final double earDx in const <double>[-0.14, 0.14]) {
        final RRect ear = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-ballR * 0.72 + earDx * s, -ballR * 1.18),
            width: s * 0.20,
            height: s * 0.56,
          ),
          Radius.circular(s * 0.10),
        );
        canvas.drawRRect(ear, Paint()..color = Colors.white);
        canvas.drawRRect(ear, stroke);
      }
      canvas.drawLine(
        Offset(ballR * 0.58, -ballR * 0.58),
        Offset(ballR * 1.38, -ballR * 1.38),
        Paint()
          ..color = const Color(0xFFFFD700)
          ..strokeWidth = (s * 0.085).clamp(1.3, 2.6),
      );
      _paintHeartShape(
        canvas,
        Offset(ballR * 1.46, -ballR * 1.46),
        s * 0.50,
        const Color(0xFFD91E48),
      );
    } else if (edition == VivienneSkiEdition.giantDenim) {
      // Skateboard end with 2 white wheels sticking out!
      final RRect deckTip = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(ballR * 1.05, ballR * 0.20),
          width: s * 0.78,
          height: s * 0.34,
        ),
        Radius.circular(s * 0.15),
      );
      canvas.drawRRect(deckTip, Paint()..color = const Color(0xFF1C2026));
      canvas.drawCircle(
        Offset(ballR * 1.08, ballR * 0.40),
        s * 0.15,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(ballR * 1.08, 0.0),
        s * 0.15,
        Paint()..color = Colors.white,
      );
    } else {
      // Mini Speedy LV bag tumbling on the rim!
      final RRect bag = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-ballR * 1.08, -ballR * 0.28),
          width: s * 0.54,
          height: s * 0.38,
        ),
        Radius.circular(s * 0.10),
      );
      canvas.drawRRect(bag, Paint()..color = const Color(0xFF2B1D14));
      canvas.drawRRect(
        bag,
        Paint()
          ..color = const Color(0xFFFFD700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (s * 0.05).clamp(1.0, 2.0),
      );
    }

    // 2. Giant Lumpy Cartoon 3D Snowball Core (`bosselée & texturée`)
    for (int k = 0; k < 8; k++) {
      final double a = k * (math.pi * 0.25) + 0.2;
      final Offset lumpC = Offset(
        math.cos(a) * ballR * 0.66,
        math.sin(a) * ballR * 0.66,
      );
      final double lumpR = ballR * (k.isEven ? 0.46 : 0.40);
      canvas.drawCircle(lumpC, lumpR, Paint()..color = const Color(0xFFE3F2FD));
      canvas.drawCircle(lumpC, lumpR, stroke);
    }

    canvas.drawCircle(
      Offset.zero,
      ballR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-ballR * 0.28, -ballR * 0.32),
          ballR * 1.32,
          const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFEDF7FF),
            Color(0xFFB3E5FC),
            Color(0xFF81D4FA),
          ],
          const <double>[0.0, 0.48, 0.84, 1.0],
        ),
    );
    canvas.drawCircle(Offset.zero, ballR, stroke);

    // Embedded green pine needles & cartoon spiral tumble arcs on the snowball!
    final Paint spiralPaint = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.08).clamp(1.2, 2.6)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: ballR * 0.62),
      0.3,
      math.pi * 1.15,
      false,
      spiralPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: ballR * 0.34),
      2.1,
      math.pi * 1.1,
      false,
      spiralPaint,
    );

    final Paint needlePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = (s * 0.075).clamp(1.1, 2.4)
      ..strokeCap = StrokeCap.round;
    for (int n = 0; n < 5; n++) {
      final double na = n * 1.25;
      final Offset np = Offset(
        math.cos(na) * ballR * 0.52,
        math.sin(na) * ballR * 0.52,
      );
      canvas.drawLine(np, np + Offset(s * 0.24, -s * 0.14), needlePaint);
      canvas.drawLine(np, np + Offset(s * 0.14, s * 0.22), needlePaint);
    }

    canvas.restore(); // End 360° rotation

    // Orbiting snow puffs flying off tangentially around the snowball
    for (int f = 0; f < 6; f++) {
      final double fa = -engine.snowballRotationRadians * 1.3 + f * (math.pi / 3.0);
      final Offset puff = Offset(
        math.cos(fa) * ballR * 1.22,
        math.sin(fa) * ballR * 1.15,
      );
      canvas.drawCircle(
        puff,
        (s * (0.16 + (f % 2) * 0.09)).clamp(1.8, 6.5),
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
    }

    canvas.restore();
  }

  void _paintHeartShape(
    Canvas canvas,
    Offset center,
    double sizeR,
    Color color, {
    bool withGoldStar = false,
  }) {
    final Path heart = Path()
      ..moveTo(center.dx, center.dy + sizeR * 0.78)
      ..cubicTo(
        center.dx - sizeR * 1.15,
        center.dy + sizeR * 0.12,
        center.dx - sizeR * 0.92,
        center.dy - sizeR * 0.85,
        center.dx,
        center.dy - sizeR * 0.30,
      )
      ..cubicTo(
        center.dx + sizeR * 0.92,
        center.dy - sizeR * 0.85,
        center.dx + sizeR * 1.15,
        center.dy + sizeR * 0.12,
        center.dx,
        center.dy + sizeR * 0.78,
      )
      ..close();

    canvas.drawPath(
      heart,
      Paint()
        ..shader = ui.Gradient.radial(
          center + Offset(-sizeR * 0.25, -sizeR * 0.28),
          sizeR * 1.25,
          <Color>[
            const Color(0xFFFF8A80),
            color,
            const Color(0xFF880E4F),
          ],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    // Glossy lacquer highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(sizeR * 0.34, -sizeR * 0.22),
        width: sizeR * 0.28,
        height: sizeR * 0.18,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    if (withGoldStar) {
      final double sr = sizeR * 0.30;
      final Path star = Path()
        ..moveTo(center.dx, center.dy - sr)
        ..lineTo(center.dx + sr * 0.28, center.dy - sr * 0.28)
        ..lineTo(center.dx + sr, center.dy)
        ..lineTo(center.dx + sr * 0.28, center.dy + sr * 0.28)
        ..lineTo(center.dx, center.dy + sr)
        ..lineTo(center.dx - sr * 0.28, center.dy + sr * 0.28)
        ..lineTo(center.dx - sr, center.dy)
        ..lineTo(center.dx - sr * 0.28, center.dy - sr * 0.28)
        ..close();
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFD700));
    }
    canvas.drawPath(
      heart,
      Paint()
        ..color = _kOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (sizeR * 0.13).clamp(1.0, 2.3),
    );
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
      final double y = size.height * 0.27 - c.progress * 32.0 - i * 30.0;
      final double alpha = (1.0 - c.progress * 0.85).clamp(0.0, 1.0);

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: c.text,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: c.color.withValues(alpha: alpha),
            shadows: <Shadow>[
              Shadow(
                color: _kOutline.withValues(alpha: alpha),
                offset: const Offset(0, 1.5),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final Rect pillRect = Rect.fromCenter(
        center: Offset(size.width * 0.5, y + tp.height * 0.5),
        width: tp.width + 24.0,
        height: tp.height + 10.0,
      );
      final RRect pillRRect = RRect.fromRectAndRadius(
        pillRect,
        const Radius.circular(16),
      );
      canvas.drawRRect(
        pillRRect,
        Paint()..color = const Color(0xFF0A1628).withValues(alpha: 0.82 * alpha),
      );
      canvas.drawRRect(
        pillRRect,
        Paint()
          ..color = c.color.withValues(alpha: 0.72 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      tp.paint(
        canvas,
        Offset((size.width - tp.width) * 0.5, y),
      );
    }
  }

  @override
  bool shouldRepaint(covariant Ski3DPainter oldDelegate) {
    return oldDelegate.engine != engine ||
        oldDelegate.rearPoseSprites != rearPoseSprites ||
        oldDelegate.frontPoseSprites != frontPoseSprites ||
        oldDelegate.editionHeroSprites != editionHeroSprites ||
        oldDelegate.lvNeoBannerImage != lvNeoBannerImage ||
        oldDelegate.turntableSprites.length != turntableSprites.length;
  }
}
